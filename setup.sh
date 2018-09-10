#!/bin/bash

set -e

declare -r APPLICATIONNAME="kw"
declare -r APPLICATIONNAME_1="vm"
declare -r APPLICATIONNAME_2="mk"
declare -r SRCDIR="src"
declare -r DEPLOY_DIR="deploy_rules"
declare -r INSTALLTO="$HOME/.config/$APPLICATIONNAME"

declare -r EXTERNAL_SCRIPTS="external"

. src/miscellaneous.sh --source-only

function usage()
{
  kw::say "--install   | -i   Install $APPLICATIONNAME"
  kw::say "--uninstall | -u   Uninstall $APPLICATIONNAME"
}

function clean_legacy()
{
  kw::say "Removing ..."
  local trash=$(mktemp -d)

  # Remove files
  if [ -d $INSTALLTO ]; then
    mv $INSTALLTO $trash
  fi

  local toDelete="$APPLICATIONNAME"
  eval "sed -i '/$toDelete/d' $HOME/.bashrc"
}

# Synchronize .vim and .vimrc with repository.
function synchronize_files()
{
  kw::say "Installing ..."

  mkdir -p $INSTALLTO

  # Copy the script
  cp $APPLICATIONNAME.sh $INSTALLTO
  rsync -vr $SRCDIR $INSTALLTO
  rsync -vr $DEPLOY_DIR $INSTALLTO

  # Add to bashrc
  echo "# $APPLICATIONNAME" >> $HOME/.bashrc
  echo "source $INSTALLTO/$APPLICATIONNAME.sh" >> $HOME/.bashrc

  kw::say $SEPARATOR
  kw::say "$APPLICATIONNAME installed into $INSTALLTO"
  kw::say $SEPARATOR
}

function download_stuff()
{
  URL=$1
  PATH_TO=$2
  ret=$(wget $URL -P $PATH_TO)

  if [ "$?" != 0 ] ; then
    kw::warning "Problem to download, verify your connection"
    kw::warning "kw is not full installed"
  fi
}

function get_external_scripts()
{
  local ret

  local -r CHECKPATCH_URL="https://raw.githubusercontent.com/torvalds/linux/master/scripts/checkpatch.pl"
  local -r CHECKPATCH_CONST_STRUCTS="https://raw.githubusercontent.com/torvalds/linux/master/scripts/const_structs.checkpatch"
  local -r CHECKPATCH_SPELLING="https://raw.githubusercontent.com/torvalds/linux/master/scripts/spelling.txt"

  kw::say "Download and install external scripts..."
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
    kw::complain "Invalid number of arguments"
    exit 1
    ;;
esac
