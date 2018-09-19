#!/bin/bash

# Set required variables
EASY_KERNEL_WORKFLOW=${EASY_KERNEL_WORKFLOW:-"kw"}
src_script_path=${src_script_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/src"}
external_script_path=${external_script_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/external"}

# Export external variables required by kworkflow
export EASY_KERNEL_WORKFLOW

function kw()
{
  action=$1
  shift

  case "$action" in
    mount)
      (
        . $src_script_path/vm.sh --source-only

        vm_mount
      )
      ;;
    umount)
      (
        . $src_script_path/vm.sh --source-only

        vm_umount
      )
      ;;
    boot)
      (
        . $src_script_path/vm.sh --source-only

        vm_boot
      )
      ;;
    up|u)
      (
        . $src_script_path/vm.sh --source-only

        vm_up
      )
      ;;
    down|d)
      (
        . $src_script_path/vm.sh --source-only

        vm_down
      )
      ;;
    register|r)
      (
        . $src_script_path/vm.sh --source-only

        vm_register
      )
      ;;
    clean|c)
      (
        . $src_script_path/vm.sh --source-only

        vm_clean
      )
      ;;
    prepare|p)
      (
        . $src_script_path/vm.sh --source-only

        vm_prepare
      )
      ;;
    build|b)
      (
        . $src_script_path/mk.sh --source-only

        mk_build
      )
      ;;
    install|i)
      (
        . $src_script_path/mk.sh --source-only

        mk_install
      )
      ;;
    new|n)
      (
        . $src_script_path/mk.sh --source-only

        vm_new_release_deploy
      )
      ;;
    bi)
      (
        . $src_script_path/mk.sh --source-only

        mk_build && mk_install
      )
      ;;
    ssh|s)
      (
        . $src_script_path/vm.sh --source-only

        vm_ssh
      )
      ;;
    vars)
      (
        . $src_script_path/commons.sh --source-only

        show_variables
      )
      ;;
    codestyle)
      (
      . $src_script_path/checkpatch_wrapper.sh --source-only

        execute_checkpatch $@
      )
      ;;
    maintainers)
      (
        . $src_script_path/get_maintainer_wrapper.sh --source-only

        execute_get_maintainer $@
      )
      ;;
    help)
      (
        . $src_script_path/utils.sh --source-only

        kworkflow-help
      )
      ;;
    *)
      (
        . $src_script_path/utils.sh --source-only
        . $src_script_path/miscellaneous.sh --source-only

        complain "Invalid option"
        kworkflow-help
      )
      ;;
  esac
}
