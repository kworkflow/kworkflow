#!/bin/bash

set -e

declare -r APPLICATIONNAME="kw"
declare -r SRCDIR="src"
declare -r DEPLOY_DIR="deploy_rules"
declare -r CONFIG_DIR="etc"
declare -r INSTALLTO="$HOME/.config/$APPLICATIONNAME"

declare -r SOUNDS="sounds"
declare -r BASH_AUTOCOMPLETE="bash_autocomplete"
declare -r DOCUMENTATION="documentation"

declare -r FISH_CONFIG_PATH="$HOME/.config/fish"
declare -r FISH_COMPLETION_PATH="$FISH_CONFIG_PATH/completions"

declare -r CONFIGS_PATH="configs"

. src/kwio.sh --source-only

function usage()
{
  say "usage: ./setup.sh option"
  say ""
  say "Where option may be one of the following:"
  say "--help      | -h     Display this usage message"
  say "--install   | -i     Install $APPLICATIONNAME"
  say "--uninstall | -u     Uninstall $APPLICATIONNAME"
  say "--completely-remove  Remove $APPLICATIONNAME and all files under its responsibility"
  say "--html               Build $APPLICATIONNAME's documentation as HTML pages into ./build"
}

function clean_legacy()
{
  say "Removing ..."
  local trash=$(mktemp -d)
  local completely_remove=$1

  local toDelete="$APPLICATIONNAME"
  eval "sed -i '/$toDelete/d' $HOME/.bashrc"
  if [[ $completely_remove =~ "-d" ]]; then
    mv "$INSTALLTO" "$trash"
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
          mv "$content" "$trash"
        done
    else
      mv "$INSTALLTO" "$trash"
    fi
  fi
}

function setup_config_file()
{
  say "Setting up global configuration file"
  local config_files="$INSTALLTO/$CONFIG_DIR/*.config"
  sed -i "s/USERKW/$USER/g" "$config_files"
  # FIXME: The following sed command assumes users won't
  # have files containing ",".
  sed -i "s,INSTALLPATH,$INSTALLTO,g" "$config_files"
  sed -i "/^#?.*/d" "$config_files"

}

function synchronize_fish()
{
    local kw_fish_path="set -gx PATH $PATH:/home/lso/.config/kw"

    say "Fish detected. Setting up fish support."
    mkdir -p "$FISH_COMPLETION_PATH"
    rsync -vr $SRCDIR/kw.fish "$FISH_COMPLETION_PATH"/kw.fish

    if ! grep -F "$kw_fish_path" "$FISH_CONFIG_PATH"/config.fish; then
       echo "$kw_fish_path" >> "$FISH_CONFIG_PATH"/config.fish
    fi
}

# Synchronize .vim and .vimrc with repository.
function synchronize_files()
{
  say "Installing ..."

  mkdir -p "$INSTALLTO"

  # Copy the script
  cp $APPLICATIONNAME "$INSTALLTO"
  rsync -vr $SRCDIR "$INSTALLTO"
  rsync -vr $DEPLOY_DIR "$INSTALLTO"
  rsync -vr $SOUNDS "$INSTALLTO"
  rsync -vr $DOCUMENTATION "$INSTALLTO"

  # Configuration
  rsync -vr $CONFIG_DIR "$INSTALLTO"
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

  say "$SEPARATOR"
  say "$APPLICATIONNAME installed into $INSTALLTO"
  say "$SEPARATOR"
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
    ;;
  --uninstall | -u)
    clean_legacy
    ;;
    # ATTENTION: This option is dangerous because it completely removes all files
    # related to kw, e.g., '.config' file under kw controls. For this reason, we do
    # not want to add a short version, and the user has to be sure about this
    # operation.
  --completely-remove)
    clean_legacy "-d"
    ;;
  --help | -h)
    usage
    ;;
  --html)
    sphinx-build -b html documentation/ build
    ;;
  *)
    complain "Invalid number of arguments"
    exit 1
    ;;
esac
