#!/bin/bash

set -e

declare -r APPLICATIONNAME="kw"
declare -r SRCDIR="src"
declare -r CONFIG_DIR="etc"
declare -r INSTALLTO="$HOME/.config/$APPLICATIONNAME"
declare -r KW_DIR="$HOME/$APPLICATIONNAME"

declare -r SOUNDS="sounds"
declare -r BASH_AUTOCOMPLETE="bash_autocomplete"
declare -r DOCUMENTATION="documentation"

declare -r FISH_CONFIG_PATH="$HOME/.config/fish"
declare -r FISH_COMPLETION_PATH="$FISH_CONFIG_PATH/completions"

declare -r CONFIGS_PATH="configs"

. src/kwio.sh --source-only

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
  warning "This operation will completely remove all files related to kw,"
  warning "including the kernel '.config' files under its controls."
  if [[ $(ask_yN "Do you want to proceed?") =~ "0" ]]; then
    exit 0
  fi
}

function clean_legacy()
{
  say "Removing ..."
  local trash=$(mktemp -d)
  local completely_remove=$1

  local toDelete="$APPLICATIONNAME"
  echo_n_run eval "sed -i '/$toDelete/d' $HOME/.bashrc"
  if [[ $completely_remove =~ "-d" ]]; then
    echo_n_run mv "$INSTALLTO" "$trash"
    return 0
  fi

  # Remove files
  if [ -d "$INSTALLTO" ]; then
    # If we have configs, we should keep it
    if [ -d "$INSTALLTO/$CONFIGS_PATH" ]; then
        for content in "$INSTALLTO"/*; do
          if [[ $content =~ "configs" ]]; then
            continue
          fi
          echo_n_run mv "$content" "$trash"
        done
    else
      echo_n_run mv "$INSTALLTO" "$trash"
    fi
  fi
}

function setup_config_file()
{
  say "Setting up global configuration file"
  local config_files_path="$INSTALLTO/$CONFIG_DIR"
  local config_file_template="$config_files_path/kworkflow_template.config"
  local global_config_name="kworkflow.config"

  if [[ -f "$config_file_template" ]]; then
    cp "$config_file_template" "$config_files_path/$global_config_name"
    sed -i -e "s/USERKW/$USER/g" -e "s,INSTALLPATH,$INSTALLTO,g" \
           -e "/^#?.*/d" "$config_files_path/$global_config_name"
  else
    warning "setup could not find $config_file_template"
  fi
}

function synchronize_fish()
{
    local kw_fish_path="set -gx PATH $PATH:$HOME/.config/kw"

    say "Fish detected. Setting up fish support."
    echo_n_run mkdir -p "$FISH_COMPLETION_PATH"
    echo_n_run rsync -vr $SRCDIR/kw.fish "$FISH_COMPLETION_PATH"/kw.fish

    if ! grep -F "$kw_fish_path" "$FISH_CONFIG_PATH"/config.fish; then
       echo "$kw_fish_path" >> "$FISH_CONFIG_PATH"/config.fish
    fi
}

# Synchronize .vim and .vimrc with repository.
function synchronize_files()
{
  say "Installing ..."

  echo_n_run mkdir -p "$INSTALLTO"

  # Copy the script
  echo_n_run cp "$APPLICATIONNAME" "$INSTALLTO"
  echo_n_run rsync -vr "$SRCDIR" "$INSTALLTO"
  echo_n_run rsync -vr "$SOUNDS" "$INSTALLTO"
  echo_n_run rsync -vr "$DOCUMENTATION" "$INSTALLTO"

  # Configuration
  echo_n_run rsync -vr "$CONFIG_DIR" "$INSTALLTO"
  setup_config_file

  if [ -f "$HOME/.bashrc" ]; then
      # Add to bashrc
      echo "# $APPLICATIONNAME" >> "$HOME/.bashrc"
      echo "PATH=\$PATH:$INSTALLTO" >> "$HOME/.bashrc"
      echo "source $INSTALLTO/$SRCDIR/$BASH_AUTOCOMPLETE.sh" >> "$HOME/.bashrc"
  else
      warning "Unable to find a shell."
  fi

  if command -v fish &> /dev/null; then
      synchronize_fish
  fi

  # Create ~/kw for support some of the operations
  mkdir -p "$KW_DIR"
}

function install_home()
{
  # First clean old installation
  clean_legacy
  # Synchronize of vimfiles
  synchronize_files
}

# Options
case $1 in
  --install | -i)
    install_home
    report_completed "$APPLICATIONNAME installed into $INSTALLTO"
    ;;
  --uninstall | -u)
    clean_legacy
    report_completed "Removal completed"
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
    complain "Invalid number of arguments"
    usage
    exit 1
    ;;
esac
