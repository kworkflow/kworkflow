# This file is the core of the explore feature. The idea behind the explore
# command it unifies the way that we search for things in the project, by
# things, you can understand from files to messages in git log.

include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"

# Hash containing user options
declare -gA options_values

# The main entry point for the explore feature, if you want to add another
# search mechanism, you probably wish to start by this function
function explore_main()
{
  local flag
  local search
  local path
  local ret

  if [[ "$1" =~ -h|--help ]]; then
    explore_help "$1"
    exit 0
  fi

  parse_explore_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  flag="${options_values['TEST_MODE']:-'SILENT'}"
  search="${options_values['SEARCH']}"
  path="${options_values['PATH']:-'.'}"

  if [[ "${options_values['SCOPE']}" == "HEADER" ]]; then
    path="${path}/*.h"
  elif [[ "${options_values['SCOPE']}" == "SOURCE" ]]; then
    path="${path}/*.c"
  fi

  if [[ "${options_values['TYPE']}" -eq 1 ]]; then
    # LOG
    explore_git_log "$search" "$path" "$flag"
    return
  fi

  if [[ "${options_values['TYPE']}" -eq 2 ]]; then
    # Use GNU GREP
    explore_files_gnu_grep "$search" "$path" "$flag"
    return
  fi

  if [[ "${options_values['TYPE']}" -eq 3 ]]; then
    # Search in directories controlled or not by git
    explore_all_files_git "$search" "$path" "$flag"
    return
  fi

  if [[ -z "${options_values['TYPE']}" ]]; then
    # Search in files under git control
    explore_files_under_git "$search" "$path" "$flag"
    return
  fi
}

# Tiny parameter parser, we try to keep this function isolate for making easy
# to expand the explore options.
#
# Returns:
# This function returns the following values:
#   0 if options are parsed successfully
#   22 for invalid operation
# This function also set options_values
function parse_explore_options()
{
  local long_options='log,grep,all,only-header,only-source,exactly'
  local short_options='l,g,a,H,c'
  local options

  if [[ "$#" -eq 0 ]]; then
    options_values['ERROR']="Expected string or parameter. See man for detail."
    return 22 # EINVAL
  fi

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw explore' \
      "$short_options" "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['TEST_MODE']='SILENT'
  options_values['SEARCH']=''
  options_values['PATH']=''
  options_values['TYPE']=''
  options_values['SCOPE']=''
  options_values['EXACTLY']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --log | -l)
        if [[ -n "${options_values['TYPE']}" && "${options_values['TYPE']}" -ne 1 ]]; then
          options_values['ERROR']="Invalid arguments: Multiple search type!"
          return 22 # EINVAL
        fi

        options_values['TYPE']=1
        shift
        ;;
      --grep | -g)
        if [[ -n "${options_values['TYPE']}" && "${options_values['TYPE']}" -ne 2 ]]; then
          options_values['ERROR']="Invalid arguments: Multiple search type!"
          return 22 # EINVAL
        fi

        options_values['TYPE']=2
        shift
        ;;
      --all | -a)
        if [[ -n "${options_values['TYPE']}" && "${options_values['TYPE']}" -ne 3 ]]; then
          options_values['ERROR']="Invalid arguments: Multiple search type!"
          return 22 # EINVAL
        fi

        options_values['TYPE']=3
        shift
        ;;
      --only-header | -H)
        if [[ -n "${options_values['SCOPE']}" ]]; then
          if [[ "${options_values['SCOPE']}" != "HEADER" ]]; then
            options_values['ERROR']="Invalid arguments: Multiple search scope!"
            return 22 # EINVAL
          fi
        fi

        options_values['SCOPE']="HEADER"
        shift
        ;;
      --only-source | -c)
        if [[ -n "${options_values['SCOPE']}" ]]; then
          if [[ "${options_values['SCOPE']}" != "SOURCE" ]]; then
            options_values['ERROR']="Invalid arguments: Multiple search scope!"
            return 22 # EINVAL
          fi
        fi

        options_values['SCOPE']="SOURCE"
        shift
        ;;
      --exactly)
        options_values['EXACTLY']=1
        shift
        ;;
      --) # End of options, beginning of arguments
        shift
        ;;
      TEST_MODE)
        options_values['TEST_MODE']='TEST_MODE'
        shift
        ;;
      *)
        if [[ -z "${options_values['SEARCH']}" ]]; then
          options_values['SEARCH']="$1"
        elif [[ -z "${options_values['PATH']}" ]]; then
          options_values['PATH']="$1"
        else
          options_values['ERROR']="Too many parameters"
          return 22 # EINVAL
        fi
        shift
        ;;
    esac
  done
}

# This function is responsible for handling the search in the log history.
#
# @search_string A string that we want to find a match in the git log
# @path This is an optional parameter for narrow down git log search
# @flag How to display a command, the default value is "SILENT". For more
#       options see `src/kwlib.sh` function `cmd_manager`
function explore_git_log()
{
  local search_string="$1"
  local path="$2"
  local flag="$3"

  cmd_manager "$flag" "git log --grep='$search_string' $path"
}

# This function searches string in files under git control.
#
# @regex Specifies the regex that we want to search in the files
# @path Narrow down the search
# @flag How to display a command, the default value is 'SILENT'. For more
#       options see `src/kwlib.sh` function `cmd_manager`
function explore_files_under_git()
{
  local regex="$1"
  local path="$2"
  local flag="$3"

  cmd_manager "$flag" "git grep -e '$regex' -nI $path"
}

# This function uses git grep tool to search string in files under or not git
# control. This only covers files into .git if the user runs the command
# inside the directory
#
# @regex Specifies the regex that we want to search in the files
# @path Narrow down the search
# @flag How to display a command, the default value is 'SILENT'. For more
#       options see `src/kwlib.sh` function `cmd_manager`
function explore_all_files_git()
{
  local regex="$1"
  local path="$2"
  local flag="$3"

  cmd_manager "$flag" "git grep --no-index -e '$regex' -nI $path"
}

# This function allows the use of gnu grep utility to manages the search for
# regex regardless if the files is or not under git control.
#
# @regex Specifies the regex that we want to search in the files
# @path Narrow down the search
# @flag How to display a command, the default value is 'SILENT'. For more
#       options see `src/kwlib.sh` function `cmd_manager`
function explore_files_gnu_grep()
{
  local regex="$1"
  local path="$2"
  local flag="$3"

  cmd_manager "$flag" "grep --color -nrI $path -e '$regex'"
}

function explore_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'explore'
    return
  fi
  printf '%s\n' 'kw explore:' \
    '  explore,e <string> [<path>] - Search for <string> based in <path> (./ by default)' \
    '  explore,e --log,-l <string> - Search for <string> on git log' \
    '  explore,e --grep,-g <string> - Search for <string> using the GNU grep tool' \
    '  explore,e --all,-a <string> - Search for all <string> match under or not of git management' \
    '  explore,e --only-source,-c <string> - Search for all <string> in source files' \
    '  explore,e --only-header,-H <string> - Search for all <string> in header files'
}
