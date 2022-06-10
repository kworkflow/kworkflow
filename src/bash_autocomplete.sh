function _kw_autocomplete()
{
  declare -A kw_options

  local current_command previous_command kw_options comp_curr

  comp_curr=$COMP_CWORD

  if [[ "$COMP_CWORD" -gt 2 ]]; then
    comp_curr=2
  fi

  current_command="${COMP_WORDS[$COMP_CWORD]}"
  previous_command="${COMP_WORDS[$comp_curr - 1]}"

  kw_options['kw']='backup bd build clear-cache codestyle configm debug deploy
                    device diff drm explore help init maintainers mail man mount
                    pomodoro report ssh umount up vars version'

  kw_options['backup']='--restore --force --help'

  kw_options['build']='--menu --info --doc --cpu-scaling --ccache --warnings --help'
  kw_options['b']="${kw_options['build']}"

  kw_options['configm']='--fetch --get --list --remove --save --force
                         --description --output --optimize --remote'
  kw_options['g']="${kw_options['configm']}"

  kw_options['debug']='--local --remote --event --ftrace --dmesg --cmd
                       --history --disable --list --follow --reset --help'

  kw_options['bd']='--verbose'

  kw_options['deploy']='--force --list --list-all --local --ls-line --modules
                        --reboot --remote --uninstall --vm --setup --verbose'
  kw_options['d']="${kw_options['deploy']}"

  kw_options['device']='--local --remote --vm'

  kw_options['diff']='--no-interactive'
  kw_options['df']="${kw_options['diff']}"

  kw_options['explore']='--log --grep --all'
  kw_options['e']="${kw_options['explore']}"

  kw_options['init']='--arch --force --remote --target --template'

  kw_options['mail']='--setup --local --global --force --verify --list --email
                     --name --smtpuser --smtpencryption --smtpserver
                     --smtpserverport --smtppass --template --interactive
                     --no-interactive --send --to --cc --simulate --private'

  kw_options['maintainers']='--authors --update-patch'
  kw_options['m']="${kw_options['mantainers']}"

  kw_options['pomodoro']='--description --list --set-timer --tag'
  kw_options['p']="${kw_options['pomodoro']}"

  kw_options['report']='--day --pomodoro --all --month --output --week --year --statistics'
  kw_options['r']="${kw_options['report']}"

  kw_options['ssh']='--command --script'
  kw_options['s']="${kw_options['ssh']}"

  mapfile -t COMPREPLY < <(compgen -W "${kw_options[${previous_command}]} " -- "${current_command}")

  # TODO:
  # Autocomplete in the bash terminal is a powerful tool which allows us to
  # make many interesting things. In the future, we could use a tree.

}

complete -o default -F _kw_autocomplete kw
