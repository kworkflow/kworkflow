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

function easy-kernel-workflow-help()
{
  echo -e "Usage: easy-kernel-workflow [target] cmd"

  echo -e "\nThe current supported targets are:\n" \
       "\t host - this machine\n" \
       "\t qemu - qemu machine\n" \
       "\t arm - arm machine"

  echo -e "\nCommands:\n" \
    "\texport\n" \
    "\tbuild,b - Build Kernel and modules\n" \
    "\tinstall,i - Install modules\n" \
    "\tbi - Build and install modules\n" \
    "\tmail - create the git send-email line from the 'emails'"\
        "in the current dir\n" \
    "\tmount - Mount partition with qemu-nbd\n" \
    "\tumount - Umount partition created with qemu-nbd\n" \
    "\tboot\n" \
    "\tvars - Show variables\n" \
    "\tup - Wake up vm\n" \
    "\thelp"
}

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
    up)
      vm_up
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
    vars)
      show_variables
      ;;
    help)
      easy-kernel-workflow-help
      ;;
    *)
      easy-kernel-workflow-help
      ;;
  esac
}
