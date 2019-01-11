#!/bin/bash

# Set required variables
EASY_KERNEL_WORKFLOW=${EASY_KERNEL_WORKFLOW:-"kw"}
src_script_path=${src_script_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/src"}
external_script_path=${external_script_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/external"}
config_files_path=${config_files_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/etc"}

# Export external variables required by kworkflow
export EASY_KERNEL_WORKFLOW

complete -W "export e build b bi install i prepare p new n ssh s mail mount mo
             umount um boot bo vars v up u codestyle c maintainers m help h" kw

function kw()
{
  action=$1
  shift

  case "$action" in
    mount|mo)
      (
        . $src_script_path/vm.sh --source-only

        vm_mount
      )
      ;;
    umount|um)
      (
        . $src_script_path/vm.sh --source-only

        vm_umount
      )
      ;;
    boot|bo)
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
    vars|v)
      (
        . $src_script_path/commons.sh --source-only

        show_variables
      )
      ;;
    codestyle|c)
      (
      . $src_script_path/checkpatch_wrapper.sh --source-only

        execute_checkpatch $@
      )
      ;;
    maintainers|m)
      (
        . $src_script_path/get_maintainer_wrapper.sh --source-only

        execute_get_maintainer $@
      )
      ;;
    help|h)
      (
        . $src_script_path/help.sh --source-only

        kworkflow-help
      )
      ;;
    explore|e)
      (
        . $src_script_path/explore.sh --source-only

        explore "$@"
      )
      ;;
    *)
      (
        . $src_script_path/help.sh --source-only
        . $src_script_path/kwio.sh --source-only

        complain "Invalid option"
        kworkflow-help
        return 1
      )
      ;;
  esac
}
