#!/bin/bash

# Set required variables
EASY_KERNEL_WORKFLOW=${EASY_KERNEL_WORKFLOW:-"easy-kernel-workflow"}
src_script_path=${src_script_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/src"}

set -e

# Load code (take care with the order)
. $src_script_path/commons --source-only
. $src_script_path/vm --source-only
. $src_script_path/mk --source-only

# Export external variables required by easy-kernel-workflow
export EASY_KERNEL_WORKFLOW

function easy-kernel-workflow()
{
  if [ "$#" -eq 1 ] ; then
    action=$1
  elif [ "$#" -eq 2 ] ; then
    TARGET=$1
    action=$2
  fi

  case "$action" in
    mount)
      vm_mount
      ;;
    umount)
      vm_umount
      ;;
    boot)
      vm_boot
      ;;
    export)
      mk_export_kbuild $@
      ;;
    build|b)
      mk_build
      ;;
    install|i)
      mk_install
      ;;
    bi)
      mk_build
      mk_install
      ;;
    mail)
      mk_send_mail
      ;;
    help)
      # TODO: Unify help
      echo "--- mk ---"
      mk_help
      echo "--- vm ---"
      vm_help
      ;;
    *)
      mk_help
      vm_help
      ;;
  esac
}
