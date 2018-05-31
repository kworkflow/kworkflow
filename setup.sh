#!/bin/bash

set -e

declare -r APPLICATIONNAME="kworkflow"
declare -r APPLICATIONNAME_1="vm"
declare -r APPLICATIONNAME_2="mk"
declare -r SRCDIR="src"
declare -r INSTALLTO="$HOME/.config/$APPLICATIONNAME"

declare -r EXTERNAL_SCRIPTS="external"
declare -r CHECKPATCH_URL="https://raw.githubusercontent.com/torvalds/linux/master/scripts/checkpatch.pl"

. src/miscellaneous --source-only

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

# Synchronize .vim and .vimrc with repository.
function synchronize_files()
{
  say "Installing ..."

  mkdir -p $INSTALLTO

  # Copy the script
  cp $APPLICATIONNAME.sh $INSTALLTO
  rsync -vr $SRCDIR $INSTALLTO

  # Add to bashrc
  echo "# $APPLICATIONNAME" >> $HOME/.bashrc
  echo "source $INSTALLTO/$APPLICATIONNAME.sh" >> $HOME/.bashrc

  say $SEPARATOR
  say "$APPLICATIONNAME installed into $INSTALLTO"
  say $SEPARATOR
}

function get_external_scripts()
{
  local ret

  say "Download and install external scripts..."
  echo

  mkdir -p $INSTALLTO/$EXTERNAL_SCRIPTS
  ret=$(wget $CHECKPATCH_URL -P $INSTALLTO/$EXTERNAL_SCRIPTS)
  if [ $ret != 0 ] ; then
    warning "Problem to download checkpatch, verify your connection"
    warning "kworkflow not full installed"
  fi

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
