#!/bin/bash

# Set required variables
EASY_KERNEL_WORKFLOW=${EASY_KERNEL_WORKFLOW:-"kw"}
src_script_path=${src_script_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/src"}
external_script_path=${external_script_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/external"}

# Load code (take care with the order)
. $src_script_path/commons.sh --source-only
. $src_script_path/miscellaneous.sh --source-only
. $src_script_path/vm.sh --source-only
. $src_script_path/mk.sh --source-only
. $src_script_path/checkpatch_wrapper.sh --source-only
. $src_script_path/get_maintainer_wrapper.sh --source-only

# Export external variables required by kworkflow
export EASY_KERNEL_WORKFLOW

function kw::help()
{
  echo -e "Usage: kw [target] cmd"

  echo -e "\nThe current supported targets are:\n" \
       "\t host - this machine\n" \
       "\t qemu - qemu machine\n" \
       "\t arm - arm machine"

  echo -e "\nCommands:\n" \
    "\texport\n" \
    "\tbuild,b - Build Kernel and modules\n" \
    "\tinstall,i - Install modules\n" \
    "\tbi - Build and install modules\n" \
    "\tprepare,p - Deploy basic environment in the VM\n" \
    "\tnew,n - Install new Kernel image\n" \
    "\tssh,s - Enter in the vm\n" \
    "\tmail - create the git send-email line from the 'emails'"\
        "in the current dir\n" \
    "\tmount - Mount partition with qemu-nbd\n" \
    "\tumount - Umount partition created with qemu-nbd\n" \
    "\tboot\n" \
    "\tvars - Show variables\n" \
    "\tup,u - Wake up vm\n" \
    "\tcodestyle - Apply checkpatch on directory or file\n" \
    "\tmaintainers - Return the maintainers and the mailing list\n" \
    "\thelp"
}

function kw()
{
  action=$1
  shift

  case "$action" in
    mount)
      kw::vm_mount
      ;;
    umount)
      kw::vm_umount
      ;;
    boot)
      kw::vm_boot
      ;;
    up|u)
      kw::vm_up
      ;;
    prepare|p)
      kw::vm_prepare
      ;;
    export)
      kw::mk_export_kbuild $@
      ;;
    build|b)
      kw::mk_build
      ;;
    install|i)
      kw::mk_install
      ;;
    new|n)
      kw::vm_new_release_deploy
      ;;
    bi)
      kw::mk_build && kw::mk_install
      ;;
    ssh|s)
      kw::vm_ssh
      ;;
    mail)
      kw::mk_send_mail
      ;;
    vars)
      kw::show_variables
      ;;
    codestyle)
      kw::execute_checkpatch $@
      ;;
    maintainers)
      kw::execute_get_maintainer $@
      ;;
    help)
      kw::help
      ;;
    *)
      kw::complain "Invalid option"
      kw::help
      ;;
  esac
}
