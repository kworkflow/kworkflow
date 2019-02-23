#!/bin/bash

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
