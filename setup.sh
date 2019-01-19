#!/bin/bash

set -e

declare -r APPLICATIONNAME="kw"
declare -r APPLICATIONNAME_1="vm"
declare -r APPLICATIONNAME_2="mk"
declare -r SRCDIR="src"
declare -r DEPLOY_DIR="deploy_rules"
declare -r CONFIG_DIR="etc"
declare -r INSTALLTO="$HOME/.config/$APPLICATIONNAME"

declare -r EXTERNAL_SCRIPTS="external"

. src/kwio.sh --source-only

function usage()
{
  say "--install   | -i   Install $APPLICATIONNAME"
  say "--uninstall | -u   Uninstall $APPLICATIONNAME"
}

function clean_legacy()
{
  say "Removing ..."
  local trash=$(mktemp -d)

  # Remove files
  if [ -d $INSTALLTO ]; then
    mv $INSTALLTO $trash
  fi

  local toDelete="$APPLICATIONNAME"
  eval "sed -i '/$toDelete/d' $HOME/.bashrc"
}

function setup_config_file()
{
  say "Setting up global configuration file"
  local config_files="$INSTALLTO/$CONFIG_DIR/*.config"
  sed -i "s/USERKW/$USER/g" $config_files
  # FIXME: The following sed command assumes users won't
  # have files containing ",".
  sed -i "s,INSTALLPATH,$INSTALLTO,g" $config_files
  sed -i "/^#?.*/d" $config_files

}

# Synchronize .vim and .vimrc with repository.
function synchronize_files()
{
  say "Installing ..."

  mkdir -p $INSTALLTO

  # Copy the script
  cp $APPLICATIONNAME.sh $INSTALLTO
  rsync -vr $SRCDIR $INSTALLTO
  rsync -vr $DEPLOY_DIR $INSTALLTO

  # Configuration
  rsync -vr $CONFIG_DIR $INSTALLTO
  setup_config_file

  # Add to bashrc
  echo "# $APPLICATIONNAME" >> $HOME/.bashrc
  echo "source $INSTALLTO/$APPLICATIONNAME.sh" >> $HOME/.bashrc

  say $SEPARATOR
  say "$APPLICATIONNAME installed into $INSTALLTO"
  say $SEPARATOR
}

function download_stuff()
{
  URL=$1
  PATH_TO=$2
  ret=$(wget $URL -P $PATH_TO)

  if [ "$?" != 0 ] ; then
    warning "Problem to download, verify your connection"
    warning "kw is not full installed"
  fi
}

function get_external_scripts()
{
  local ret

  local -r CHECKPATCH_URL="https://raw.githubusercontent.com/torvalds/linux/master/scripts/checkpatch.pl"
  local -r CHECKPATCH_CONST_STRUCTS="https://raw.githubusercontent.com/torvalds/linux/master/scripts/const_structs.checkpatch"
  local -r CHECKPATCH_SPELLING="https://raw.githubusercontent.com/torvalds/linux/master/scripts/spelling.txt"

  say "Download and install external scripts..."
  echo

  mkdir -p $INSTALLTO/$EXTERNAL_SCRIPTS
  CHECKPATCH_TARGET_PATH=$INSTALLTO/$EXTERNAL_SCRIPTS
  download_stuff $CHECKPATCH_URL $CHECKPATCH_TARGET_PATH
  download_stuff $CHECKPATCH_CONST_STRUCTS $CHECKPATCH_TARGET_PATH
  download_stuff $CHECKPATCH_SPELLING $CHECKPATCH_TARGET_PATH

  echo
}

function install_home()
{
  # First clean old installation
  clean_legacy
  # Download external scripts
  get_external_scripts
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
  *)
    complain "Invalid number of arguments"
    exit 1
    ;;
esac
