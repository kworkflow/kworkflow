#!/bin/bash

# Set required variables
EASY_KERNEL_WORKFLOW=${EASY_KERNEL_WORKFLOW:-"kw"}
src_script_path=${src_script_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/src"}
external_script_path=${external_script_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/external"}
config_files_path=${config_files_path:-"$HOME/.config/$EASY_KERNEL_WORKFLOW/etc"}

# Export external variables required by kworkflow
export EASY_KERNEL_WORKFLOW

_kw_autocomplete()
{
    local current_command previous_command kw_options
    COMPREPLY=()
    current_command="${COMP_WORDS[COMP_CWORD]}"
    previous_command="${COMP_WORDS[COMP_CWORD-1]}"
    kw_options="export e build b bi install i prepare p new n ssh s
                mail mount mo umount um boot bo vars v up u codestyle c
                maintainers m help h"

    # By default, autocomplete with kw_options
    if [[ ${previous_command} == kw ]] ; then
        COMPREPLY=( $(compgen -W "${kw_options}" -- ${current_command}) )
        return 0
    fi

    # TODO:
    # Autocomplete in the bash terminal is a powerful tool which allows us to
    # make many interesting things. In the future, we could add an
    # autocompletion for subcommands, the code below illustrates an example
    # that tries to add this feature for the ‘maintainers’ options.
    #
    # For maintainers and m options, autocomplete with folder
    # if [ ${previous_command} == maintainers ] || [ ${previous_command} == m ] ; then
    #   COMPREPLY=( $(compgen -d -- ${current_command}) )
    #   return 0
    # fi
}
complete -o default -F _kw_autocomplete kw

function kw()
{
  action=$1
  shift

  case "$action" in
    mount|mo)
      (
        . $src_script_path/vm.sh --source-only

        vm_mount
        local ret=$?
        alert_completion "kw build" "$1"
        return $ret
      )
      ;;
    umount|um)
      (
        . $src_script_path/vm.sh --source-only

        vm_umount
        local ret=$?
        alert_completion "kw build" "$1"
        return $ret
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
        local ret=$?
        alert_completion "kw prepare" "$1"
        return $ret
      )
      ;;
    build|b)
      (
        . $src_script_path/mk.sh --source-only

        mk_build
        local ret=$?
        alert_completion "kw build" "$1"
        return $ret
      )
      ;;
    install|i)
      (
        . $src_script_path/mk.sh --source-only

        mk_install
        local ret=$?
        alert_completion "kw install" "$1"
        return $ret
      )
      ;;
    new|n)
      (
        . $src_script_path/mk.sh --source-only

        vm_new_release_deploy
        local ret=$?
        alert_completion "kw new" "$1"
        return $ret
      )
      ;;
    bi)
      (
        . $src_script_path/mk.sh --source-only

        mk_build && mk_install
        local ret=$?
        alert_completion "kw bi" "$1"
        return $ret
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
