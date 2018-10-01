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
. $src_script_path/config_manager.sh

# Export external variables required by kworkflow
export EASY_KERNEL_WORKFLOW

function kworkflow-help()
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
    "\tregister_config <PATH> <COMMENT> - Save a config file in kw database\n"\
    "\tshow_configs - Show all configuration files saved in kw database\n"\
    "\tget_config <INDEX> - copy a '.config' in the current path\n"\
    "\thelp"
}

function kw()
{
  action=$1
  shift

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
    up|u)
      vm_up
      ;;
    prepare|p)
      vm_prepare
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
    new|n)
      vm_new_release_deploy
      ;;
    bi)
      mk_build && mk_install
      ;;
    ssh|s)
      vm_ssh
      ;;
    mail)
      mk_send_mail
      ;;
    vars)
      show_variables
      ;;
    codestyle)
      execute_checkpatch $@
      ;;
    maintainers)
      execute_get_maintainer $@
      ;;
    register_config|rc)
      register_config $@
      ;;
    show_configs|sc)
      show_configs $@
      ;;
    get_config|gc)
      get_config $@
      ;;
    help)
      kworkflow-help
      ;;
    *)
      complain "Invalid option"
      kworkflow-help
      ;;
  esac
}
