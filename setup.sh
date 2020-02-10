#!/bin/bash

# Brief description of the installation dirs:
#
# For all installations:
# - $prefix/bin/kw: kw binary
# - $prefix/lib/kw/: code files not to be invoked externally (i.e. src)
# - $prefix/share/kw/: static data such as sounds, etc files and documentation
# - $HOME/.kw/: user data, such as the configm storage and user-global config
#   file
#
# Only if $prefix == /usr (system-wide installation):
# - /usr/share/man/man1/kw.1.gz: man page
# - /usr/share/bash-completion/completions/kw: bash autocompletion
# - /usr/share/fish/completions/kw.fish: fish completions
# - /usr/etc/kw/kworkflow.config: config file

set -e

. src/kwio.sh --source-only

declare prefix
declare system_wide

## Following are the install paths
#  Note: we use "dir"-ended variables for paths to directories that only contain
#  kw files and "path"-ended variables for paths to specific kw files.

# Used in all installations
declare -r binpath="$prefix/bin/kw"
declare -r libdir="$prefix/lib/kw/"
declare -r sharedir="$prefix/share/kw/"
declare -r datadir="$HOME/.kw/"
declare -r cachedir="$HOME/.cache/kw/"

# Used only in system-wide installations
declare -r manpath="/usr/share/man/man1/kw.1.gz"
declare -r bashcompletionpath="/usr/share/bash-completion/completions/kw"
declare -r fishcompletionpath="/usr/share/fish/completions/kw.fish"
declare -r globalconfigdir="/usr/etc/kw/"

# For output messages
declare -r APPLICATIONNAME="kw"

function echo_n_run()
{
  echo "$@"
  eval "$@ >/dev/null"
}

function report_completed()
{
  success "$SEPARATOR"
  success "$@"
  success "$SEPARATOR"
}

function usage()
{
  say "usage: ./setup.sh option"
  say ""
  say "Where option may be one of the following:"
  say "--help      | -h     Display this usage message"
  say "--install   | -i     Install $APPLICATIONNAME"
  say "--uninstall | -u     Uninstall $APPLICATIONNAME"
  say "--completely-remove  Remove $APPLICATIONNAME and all files under its responsibility"
  say "--docs               Build $APPLICATIONNAME's documentation as HTML pages into ./build"
}

function confirm_complete_removal()
{
  warning "This operation will completely remove ALL files related to kw,"
  warning "including user data such as the kernel '.config' files under"
  warning "its controls."
  if [[ $(ask_yN "Do you want to proceed?") =~ "0" ]]; then
    exit 0
  fi
}

function clean_legacy()
{
  say "Removing ..."
  local trash=$(mktemp -d)
  local completely_remove=$1

  mkdir -p "$trash/bin" "$trash/share" "$trash/lib" "$trash/cache/"
  echo_n_run mv "$binpath" "$trash/bin/"
  echo_n_run mv "$libdir" "$trash/lib/"
  echo_n_run mv "$sharedir" "$trash/share/"
  echo_n_run mv "$cachedir" "$trash/cache/"

  if [[ "$system_wide" == true ]]; then
    echo_n_run mv "$manpath" "$trash/man"
    echo_n_run mv "$bashcompletionpath" "$trash/bash-completion"
    echo_n_run mv "$fishcompletionpath" "$trash/fish-completion"
  fi

  if [[ $completely_remove =~ "-d" ]]; then
    mkdir -p "$trash/data" "$trash/etc/config"
    echo_n_run mv "$datadir" "$trash/data"
    if [[ "$system_wide" == true ]]; then
      echo_n_run mv "$globalconfigdir" "$trash/etc/config"
    fi
  fi
}

# Copy the default config file to a directory and set it up
# Args:
# $1: the path to a directory where the config file will be copied to
function copy_config_file_to()
{
  local -r to="$1"
  local -r config_file_name="kworkflow.config"
  local -r config_file_template="etc/kworkflow_template.config"

  mkdir -p "$to"
  echo_n_run cp "$config_file_template" "$to/$config_file_name"
  sed -i -e "s/USERKW/$USER/g" -e "s,KW_SOUNDS_DIR,$sharedir/sounds/,g" \
         -e "/^#?.*/d" "$to/$config_file_name"
}

# Set up both user-global and system-global config files
function setup_config_file()
{
  local -r config_file_template="etc/kworkflow_template.config"

  say "Setting up configuration files"

  if [[ -f "$config_file_template" ]]; then
    copy_config_file_to "$data"
    if [[ "$system_wide" == true ]]; then
      copy_config_file_to "$globalconfigdir"
    fi
  else
    warning "setup could not find $config_file_template"
  fi
}

function synchronize_completion_files()
{
  # TODO: allow completion for local installation
  if [[ "$system_wide" == true ]]; then

    echo_n_run rsync -v "completion/bash_autocomplete.sh" "$bashcompletionpath"

    if command -v fish &> /dev/null; then
      say "Fish detected. Setting up fish support."
      mkdir -p "$(dirname "$fishcompletionpath")"
      echo_n_run rsync -r "completion/kw.fish" "$fishcompletionpath"
    fi
  fi
}

function synchronize_files()
{
  say "Installing ..."

  mkdir -p "$libdir" "$sharedir" "$datadir" "$cachedir"
  mkdir -p "$(dirname "$binpath")"

  echo_n_run cp "kw" "$binpath"
  sed -i -e "s,##KW_INSTALL_PREFIX_TOKEN##,$prefix/,g" "$binpath"
  echo_n_run rsync -r "src/" "$libdir"

  echo_n_run rsync -r "sounds" "$sharedir"
  echo_n_run rsync -r "etc/" "$sharedir"
  echo_n_run rsync -r "documentation" "$sharedir"

  if [[ "$system_wide" == true ]]; then
    mkdir -p "$(dirname "$manpath")"
    echo_n_run rst2man "documentation/man/kw.rst" "$manpath"
  fi

  setup_config_file
  synchronize_completion_files
}

function reinstall()
{
  clean_legacy
  synchronize_files
}

function wrong_usage()
{
  complain "Invalid number of arguments"
  usage
  exit 1
}

function set_prefix()
{
  prefix="$@"
  if [[ "$prefix" == "/usr" ]] || [[ "$prefix" == "/usr/" ]]; then
    system_wide="true"
  else
    system_wide="false"
  fi
}

# This function receives all arguments of the script and check if the second
# argument is "--prefix=<VALUE>". If so, set $prefix to <VALUE>. If the number
# of arguments exceeds 2 or the second arg is not as expected, exit with an
# error.
function maybe_parse_prefix()
{
  local -r prefix_opt="--prefix="
  case $# in
    1)
    ;; # Do nothing: $1 should have been already parsed
    2)
      if [[ "$2" =~ "$prefix_opt"* ]]; then
        set_prefix "${2#"$prefix_opt"}"
      else
        wrong_usage
      fi
    ;;
    *)
      wrong_usage
    ;;
  esac
}

set_prefix "$HOME"

# Options
case $1 in
  --install | -i)
    maybe_parse_prefix "$@"
    reinstall
    report_completed "$APPLICATIONNAME installed into \"$prefix/bin/kw\""
    ;;
  --uninstall | -u)
    maybe_parse_prefix "$@"
    clean_legacy
    report_completed "Removal completed from \"$prefix\""
    ;;
    # ATTENTION: This option is dangerous because it completely removes all files
    # related to kw, e.g., '.config' file under kw controls. For this reason, we do
    # not want to add a short version, and the user has to be sure about this
    # operation.
  --completely-remove)
    confirm_complete_removal
    clean_legacy "-d"
    report_completed "Removal completed"
    ;;
  --help | -h)
    usage
    ;;
  --docs)
    say "Building HTML docs..."
    echo_n_run sphinx-build -b html documentation/ build
    report_completed "HTML docs generated at ./build"
    ;;
  *)
    wrong_usage
    ;;
esac
