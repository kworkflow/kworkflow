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
function kw_ssh_main()
{
  local port
  local script_path
  local cmd
  local ssh_cmd
  local flag
  local user
  local remote
  local remote_file
  local remote_file_host
  local ssh_compose='ssh'

  parser_ssh_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    exit 22 # EINVAL
  fi

  user="${remote_parameters['REMOTE_USER']}"
  remote="${remote_parameters['REMOTE_IP']}"
  port="${remote_parameters['REMOTE_PORT']}"
  remote_file="${remote_parameters['REMOTE_FILE']}"
  remote_file_host="${remote_parameters['REMOTE_FILE_HOST']}"

  script_path=${options_values['SCRIPT']}
  cmd=${options_values['CMD']}
  flag=${options_values['VERBOSE']}

  is_ssh_connection_configured "$flag"
  if [[ "$?" != 0 ]]; then
    ssh_connection_failure_message
    exit 101 # ENETUNREACH
  fi

  if [[ -n "$cmd" ]]; then
    run_command_in_the_remote
    return "$?"
  fi

  if [[ -n "$script_path" ]]; then
    run_script_in_the_remote
    return "$?"
  fi

  # Just ssh into the remote
  ssh_remote
  return "$?"
}

function handle_ssh()
{
  local user
  local port
  local remote
  local ssh_compose='ssh'
  local remote_file
  local remote_file_host
  local flag

  user="${remote_parameters['REMOTE_USER']}"
  remote="${remote_parameters['REMOTE_IP']}"
  port="${remote_parameters['REMOTE_PORT']}"
  remote_file="${remote_parameters['REMOTE_FILE']}"
  remote_file_host="${remote_parameters['REMOTE_FILE_HOST']}"
  flag=${options_values['VERBOSE']}

  [[ -z "$flag" ]] && ssh_compose+=' -v'

  # Add port
  [[ -n "$port" ]] && port="-p ${port}"

  # With file
  if [[ -f "$remote_file" ]]; then
    ssh_compose+=" -F ${remote_file} ${remote_file_host}"
  else
    ssh_compose+=" ${port} ${user}@${remote}"
  fi

  printf '%s' "$ssh_compose"
}

function run_command_in_the_remote()
{
  local cmd
  local flag
  local ssh_compose

  cmd=${options_values['CMD']}
  flag=${options_values['VERBOSE']}

  ssh_compose=$(handle_ssh)
  ssh_compose+=" $cmd"

  cmd_manager "$flag" "$ssh_compose"
}

function run_script_in_the_remote()
{
  local script_path
  local ssh_compose
  local ssh_script
  local flag

  flag=${options_values['VERBOSE']}

  script_path=${options_values['SCRIPT']}
  if [[ ! -f "$script_path" ]]; then
    complain "No such file: $script_path"
    exit 2 # ENOENT
  fi

  ssh_script="\"bash -s\" -- < $script_path"
  ssh_compose=$(handle_ssh)

  ssh_compose+=" $ssh_script"
  cmd_manager "$flag" "$ssh_compose"
}

function ssh_remote()
{
  local ssh_compose
  local flag

  flag=${options_values['VERBOSE']}

  ssh_compose=$(handle_ssh)

  cmd_manager "$flag" "$ssh_compose"
}

function parser_ssh_options()
{
  local options
  local long_options='help,test_mode,script:,command:,remote:,verbose'
  local short_options='h,s:,c:,r:,v'
  local transition_variables

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'ssh' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['SCRIPT']=''
  options_values['COMMAND']=''
  options_values['VERBOSE']='SILENT'

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']='Something is wrong in the remote option'
    return 22 # EINVAL
  fi

  eval "set -- $options"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --remote | -r)
        populate_remote_info "$2"
        if [[ "$?" == 22 ]]; then
          options_values['ERROR']="$option"
          return 22
        fi
        shift 2
        ;;
      --script | -s)
        options_values['SCRIPT']+="$2"
        shift 2
        ;;
      --command | -c)
        options_values['CMD']+="$2"
        shift 2
        ;;
      --verbose | -v)
        options_values['VERBOSE']=''
        shift
        ;;
      --help | -h)
        ssh_help "$1"
        exit
        ;;
      test_mode)
        options_values['VERBOSE']='TEST_MODE'
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
    '  ssh (-v | --verbose) - enable verbose for ssh operation' \
    '  ssh (-r | --remote) - ssh command line remote' \
    '  ssh (-s | --script) <script-path> - Script path in the host that will run in the target' \
    '  ssh (-c | --command) <string-command> - Command to be executed in the target machine'
}
