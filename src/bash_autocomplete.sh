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

  kw_options['kw']='init build deploy bd diff ssh vars codestyle self-update
                    maintainers kernel-config-manager config remote explore
                    pomodoro report device backup debug mail env patch-hub
                    clear-cache drm vm version man help'

  kw_options['init']='--arch --remote --target --force --template --verbose'

  kw_options['build']='--help --info --menu --cpu-scaling --ccache --llvm --clean
                       --full-cleanup --verbose --doc --warnings --save-log-to'

  kw_options['b']="${kw_options['build']}"

  kw_options['deploy']='--remote --local --reboot --no-reboot --modules --list
                        --list-all --ls-line --setup --uninstall --verbose
                        --force --create-package --from-package'
  kw_options['d']="${kw_options['deploy']}"

  kw_options['bd']='--verbose'

  kw_options['diff']='--no-interactive'
  kw_options['df']="${kw_options['diff']}"

  kw_options['ssh']='--remote --script --command --verbose --help'
  kw_options['s']="${kw_options['ssh']}"

  kw_options['self-update']='--unstable --help'
  kw_options['u']="${kw_options['self-update']}"

  kw_options['maintainers']='--authors --update-patch'
  kw_options['m']="${kw_options['mantainers']}"

  kw_options['kernel-config-manager']='--force --save --description --list --get
                                       --remove --fetch --output --optimize --remote'
  kw_options['k']="${kw_options['kernel-config-manager']}"

  kw_options['config']='--local --global --show --help'

  kw_options['remote']='add remove rename --list --global --set-default --verbose'

  kw_options['explore']='--log --grep --all --only-header --only-source --exactly --verbose'
  kw_options['e']="${kw_options['explore']}"

  kw_options['pomodoro']='--set-timer --check-timer --show-tags --tag --description --help'
  kw_options['p']="${kw_options['pomodoro']}"

  kw_options['report']='--day --week --month --year --output --statistics --pomodoro --all'
  kw_options['r']="${kw_options['report']}"

  kw_options['device']='--local --remote --vm'

  kw_options['backup']='--restore --force --verbose --help'

  kw_options['debug']='--remote --local --event --ftrace --dmesg --cmd
                       --history --disable --reset --list --follow --help'

  kw_options['mail']='--list --send --to --cc --simulate --setup --email --name --smtpencryption
                      --template --interactive --local --global --private --verify
                      --force --no-interactive --rfc --verbose --smtpuser --smtpserver
                      --smtpserverport --smtppass'

  kw_options['env']='--list --create --use --exit-env --destroy --verbose'

  kw_options['patch-hub']='--help'

  kw_options['drm']='--remote --local --gui-on --gui-off --load-module
                     --unload-module --conn-available --modes --verbose --help'

  kw_options['vm']='--mount --umount --up --alert --help'

  mapfile -t COMPREPLY < <(compgen -W "${kw_options[${previous_command}]} " -- "${current_command}")

  # TODO:
  # Autocomplete in the bash terminal is a powerful tool which allows us to
  # make many interesting things. In the future, we could use a tree.

}

complete -o default -F _kw_autocomplete kw
