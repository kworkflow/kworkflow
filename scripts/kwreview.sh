#!/bin/bash

declare -gA opt
declare -ga analysed_files

# Get kw's current list of excluded warnings for shellcheck
function get_shellcheck_exclude()
{
  local travis_file='.github/workflows/shellcheck_reviewdog.yml'
  if [[ ! -f "$travis_file" ]]; then
    travis_file="../$travis_file"
    if [[ ! -f "$travis_file" ]]; then
      echo "Please call kwreview from kw's root folder"
      exit 125 # ECANCELED
    fi
  fi

  grep 'shellcheck_flags:' "$travis_file" |
    sed -E 's/.*--exclude=((SC[0-9]{4},?)*).*/\1/'
}

# Initialize the global variable opt with default options
function init_options()
{
  opt['branch']='unstable'
  opt['path']='.'
  opt['exclude']=''
  opt['shellcheck_exclude_default']="$(get_shellcheck_exclude)"
  opt['shellcheck_exclude']="${opt['shellcheck_exclude_default']}"
  opt['shfmt_inplace']='FALSE'
  opt['shfmt_only']='FALSE'
  opt['shellcheck_only']='FALSE'
  opt['list']='FALSE'
  opt['working_tree']='FALSE'
  opt['staging_area']='FALSE'
  opt['ignore_vcs']=''
  opt['filter_mode']='added'
}

# Parse arguments and store them in the global variable opt
#
# @raw_options All supplied arguments
#
function parse_args()
{
  local -a raw_options=("$@")
  local prog_name="$0"
  local short_options
  local long_options
  local options

  short_options='b:p:e:s:awhltg'
  long_options='branch:,path:,exclude:,shellcheck-exclude:,'
  long_options+='all,shfmt-inplace,list,help,'
  long_options+='shfmt-only,shellcheck-only,'
  long_options+='working-tree,staging-area,filter_mode:'

  options="$(getopt --name "$(basename "$prog_name")" \
    --options "$short_options" \
    --longoptions "$long_options" \
    -- "${raw_options[@]}")"

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --branch | -b)
        opt['branch']="$2"
        shift 2
        ;;
      --staging-area | -g)
        opt['staging_area']='TRUE'
        shift 1
        ;;
      --working-tree | -t)
        opt['working_tree']='TRUE'
        shift 1
        ;;
      --path | -p)
        opt['path']="$2"
        shift 2
        ;;
      --exclude | -e)
        opt['exclude']="$2"
        shift 2
        ;;
      --shellcheck-exclude | -s)
        opt['shellcheck_exclude']="$2"
        shift 2
        ;;
      --all | -a)
        opt['shellcheck_exclude']=''
        shift 1
        ;;
      --shfmt-inplace | -w)
        opt['shfmt_inplace']='TRUE'
        shift 1
        ;;
      --shellcheck-only)
        opt['shellcheck_only']='TRUE'
        shift 1
        ;;
      --shfmt-only)
        opt['shfmt_only']='TRUE'
        shift 1
        ;;
      --list | -l)
        opt['list']='TRUE'
        shift 1
        ;;
      --help | -h)
        print_help
        exit 0
        ;;
      --filter-mode)
        opt['filter_mode']="$2"
        shift 2
        ;;
      --) # End of options, beginning of arguments
        shift
        ;;
      *)
        if [ -z "${opt['ignore_vcs']}" ]; then
          opt['ignore_vcs']=1
          opt['filter-mode']='nofilter'
          analysed_files=()
        fi
        analysed_files+=("$1")
        shift
        ;;
    esac
  done
}

function print_help()
{
  echo "Usage: kwreview [OPTIONS] [FILES]"
  echo "Print formatting diff and linter revision for kw's bash files."
  echo "If FILES are supplied, analyse them. If not, analyse all shell files"
  echo "which differ from branch unstable."
  echo
  echo "-h, --help               display this help message"
  echo "-b, --branch=BRANCH      compare to git revision BRANCH instead of"
  echo "                         unstable (ignored if -t or -g are supplied)"
  echo "-t, --working-tree       compare against working tree"
  echo "-g, --staging-area       compare against staging area"
  echo "-p, --path=PATH          consider files in PATH"
  echo "-e, --exclude=PATH       exclude files in PATH"
  echo "                         examine files provided as arguments disregarding"
  echo "                         the VCS"
  echo "-s, --shellcheck-exclude=EXCLUDE"
  echo "                         ignore the comma separated list of"
  echo "                         shellcheck warnings and suggestions EXCLUDE"
  echo "                         (default: ${opt['shellcheck_exclude_default']})"
  echo "-a, --all                don't exclude any shellcheck codes"
  echo "-w, --shfmt-inplace      change formatting in files"
  echo "    --shfmt-only         run formatter only"
  echo "    --shellcheck-only    run linter only"
  echo "    --filter-mode        choose reviewdog's filter mode (added,"
  echo "                         diff_context, file or nofilter"
  echo "-l, --list               list files subject to analysis and exit"
}

# List all files changed since opt['branch'] (unstable by default)
function get_git_files()
{
  local pathspec
  local branch
  local exclude
  local working_tree
  local staging_area
  local revision

  pathspec="${opt['path']}"
  branch="${opt['branch']}"
  exclude="${opt['exclude']}"
  working_tree="${opt['working_tree']}"
  staging_area="${opt['staging_area']}"
  revision="@..$branch"

  if [[ -n "$exclude" ]]; then
    pathspec+=" :^$exclude"
  fi

  if [[ "$working_tree" == 'TRUE' ]]; then
    git diff --name-only --cached | sort
  elif [[ "$staging_area" == 'TRUE' ]]; then
    git diff --name-only | sort
  else
    git diff-tree --no-commit-id --name-only -r \
      "$revision" -- \
      "$pathspec" |
      sort
  fi
}

# List all shell script files
function get_sh_files()
{
  shfmt -f . | sort
}

# Read the intersection of get_git_files and get_sh_files into
# analysed_files
function get_analysed_files()
{
  if [[ -z "${opt['ignore_vcs']}" ]]; then
    mapfile -t analysed_files < <(comm -12 <(get_git_files) <(get_sh_files))
  fi
}

# If -l or --list was passed, print all files subject to analysis and
# exit
function list()
{
  if [[ "${opt['list']}" = 'TRUE' ]]; then
    for file in "${analysed_files[@]}"; do
      echo "$file"
    done
    exit 0
  fi
}

function check_dependencies()
{
  if ! type shfmt > /dev/null 2>&1; then
    echo 'shfmt not found!'
    exit 125 # ECANCELED
  elif ! type shellcheck > /dev/null 2>&1; then
    echo 'shellcheck not found!'
    exit 125 # ECANCELED
  elif ! type reviewdog > /dev/null 2>&1; then
    echo 'reviewdog not found!'
    exit 125 # ECANCELED
  fi
}

function run_shfmt()
{
  local shellcheck_only="${opt['shellcheck_only']}"
  local shfmt_inplace="${opt['shfmt_inplace']}"
  local branch="${opt['branch']}"
  local filter_mode="${opt['filter_mode']}"

  if [[ "$shellcheck_only" = 'FALSE' ]]; then
    if [[ "$shfmt_inplace" = 'FALSE' ]]; then
      shfmt -d -i 2 -fn -ci -sr -ln bash "${analysed_files[@]}" |
        reviewdog -f=diff -diff="git diff $branch" -f.diff.strip 0 \
          -filter-mode "$filter_mode"
    else
      shfmt -w -i 2 -fn -ci -sr -ln bash "${analysed_files[@]}"
    fi
  fi
}

function run_shellcheck()
{
  local shellcheck_exclude="${opt['shellcheck_exclude']}"
  local branch="${opt['branch']}"
  local shfmt_only="${opt['shfmt_only']}"
  local filter_mode="${opt['filter_mode']}"

  if [[ "$shfmt_only" = 'FALSE' ]]; then
    shellcheck -f checkstyle "${analysed_files[@]}" \
      --external-sources --shell=bash --exclude="$shellcheck_exclude" |
      reviewdog -f=checkstyle -diff="git diff $branch" -filter-mode "$filter_mode"
  fi
}

function kwreview()
{
  init_options
  parse_args "$@"
  get_analysed_files

  if [[ ${#analysed_files[@]} -eq 0 ]]; then
    echo "No files to evaluate. Exiting..."
    exit 1
  fi

  list

  shopt -u expand_aliases
  check_dependencies

  run_shfmt
  run_shellcheck
}

kwreview "$@"
