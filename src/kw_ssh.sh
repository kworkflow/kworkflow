include "$KW_LIB_DIR/remote.sh"
include "$KW_LIB_DIR/kwlib.sh"

# Hash containing user options
declare -gA options_values

# This function manages ssh operations. Currently, we have three basic actions:
# connect to the host machine, execute a command in the host machine, and
# perform a local script inside the host machine.
#
# @opts Pass modifier argument to the ssh command. Available options are
#   (--command|-c) and (--script|-s). If this parameter receives a null value
#   this function will perform a simple ssh connection; otherwise, it will
#   attempt to execute a command or script on the remote host.
function kw_ssh()
{
  local port
  local script_path
  local cmd
  local ssh_cmd
  local flag
  local user
  local remote

  parser_ssh_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    exit 22 # EINVAL
  fi

  user="${remote_parameters['REMOTE_USER']}"
  remote="${remote_parameters['REMOTE_IP']}"
  port="${remote_parameters['REMOTE_PORT']}"
  script_path=${options_values['SCRIPT']}
  cmd=${options_values['CMD']}
  flag=${options_values['TEST_MODE']}

  if [[ -n "${options_values['SCRIPT']}" ]]; then
    if [[ ! -f "$script_path" ]]; then
      complain "No such file: $script_path"
      exit 2 # ENOENT
    fi

    ssh_cmd="\"bash -s\" -- < $script_path"
  elif [[ -n "$cmd" ]]; then
    ssh_cmd="$cmd"
  fi

  # Add port
  if [ -n "$port" ]; then
    port="-p $port"
  fi

  cmd_manager "$flag" "ssh $port $user@$remote $ssh_cmd"
}

function parser_ssh_options()
{
  local options
  local short_options='h,s:,c:'
  local long_options='help,test_mode,script:,command:'
  local transition_variables

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'ssh' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['SCRIPT']=''
  options_values['COMMAND']=''
  options_values['TEST_MODE']=''

  # Set default values
  if [[ -n ${configurations[default_deploy_target]} ]]; then
    transition_variables=${configurations[default_deploy_target]}
    options_values['TARGET']=${deploy_target_opt[$transition_variables]}
  fi

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']='Something is wrong in the remote option'
    return 22 # EINVAL
  fi

  eval "set -- $options"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --script | -s)
        options_values['SCRIPT']+="$2"
        shift 2
        ;;
      --command | -c)
        options_values['CMD']+="$2"
        shift 2
        ;;
      --help | -h)
        ssh_help "$1"
        exit
        ;;
      test_mode)
        options_values['TEST_MODE']='TEST_MODE'
        shift
        ;;
      --) # End of options, beginning of arguments
        shift
        ;;
      *)
        options_values['ERROR']="$1"
        return 22
        ;;
    esac
  done
}

function ssh_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'ssh'
    return
  fi
  printf '%s\n' 'kw ssh:' \
    '  ssh - ssh support under kw' \
    '  ssh (-s | --script) <script-path> - Script path in the host that will run in the target' \
    '  ssh (-c | --command) <string-command> - Command to be executed in the target machine'
}
