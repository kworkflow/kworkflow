#!/bin/bash
include "${KW_LIB_DIR}/lib/remote.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

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
  local flag
  local port
  local script_path
  local cmd
  local ssh_cmd
  local user
  local remote
  local remote_file
  local remote_file_host
  local ssh_compose='ssh'
  local transfer_type=''

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

  flag=${options_values['TEST_MODE']}
  script_path=${options_values['SCRIPT']}
  cmd=${options_values['CMD']}
  send=${options_values['SEND']}
  get=${options_values['GET']}
  to=${options_values['TO']}

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'
  flag=${flag:-'SILENT'}

  is_ssh_connection_configured "$flag"
  if [[ "$?" != 0 ]]; then
    ssh_connection_failure_message
    exit 101 # ENETUNREACH
  fi

  if [[ -n "$cmd" ]]; then
    run_command_in_the_remote "$flag"
    return "$?"
  fi

  if [[ -n "$script_path" ]]; then
    run_script_in_the_remote "$flag"
    return "$?"
  fi

  [[ -n "$get" ]] && transfer_type='get'
  [[ -n "$send" ]] && transfer_type='send'
  if [[ -n ${transfer_type} ]]; then
    ssh_transfer_file "$flag" "$transfer_type"
    return "$?"
  fi

  # Just ssh into the remote
  ssh_remote "$flag"
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

  flag=${flag:-'SILENT'}

  user="${remote_parameters['REMOTE_USER']}"
  remote="${remote_parameters['REMOTE_IP']}"
  port="${remote_parameters['REMOTE_PORT']}"
  remote_file="${remote_parameters['REMOTE_FILE']}"
  remote_file_host="${remote_parameters['REMOTE_FILE_HOST']}"

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
  local flag="$1"
  local ssh_compose

  flag=${flag:-'SILENT'}

  cmd=${options_values['CMD']}

  ssh_compose=$(handle_ssh)
  ssh_compose+=" $cmd"

  cmd_manager "$flag" "$ssh_compose"
}

# This function transfers a local file or directory to a
# specified remote destination or gets a file or directory
# from the specified remote path and saves it to the local
# machine at the specified path.
#
# @flag: Expecting a flag, by default, cmd_manager does not
# expects flags and always show the command. For more details
# see the function `cmd_manager` in `src/lib/kwlib.sh`.
# @transfer_type: Transfer type, either 'send' or 'get'.
#
# Returns:
# return 2 (ENOENT): Indicates source file/directory doesn't exist.
# return 125 (ECANCELED): Indicates user-cancelled operation.
function ssh_transfer_file()
{
  local flag="$1"
  local transfer_type="$2"
  local user
  local port
  local remote
  local remote_file
  local remote_file_host
  local transfer_path
  local to_path
  local cmd
  local ssh_compose
  local filename
  local filename_path
  local exist_path
  local rsync_options

  flag=${flag:-'SILENT'}

  user="${remote_parameters['REMOTE_USER']}"
  port="${remote_parameters['REMOTE_PORT']}"
  remote="${remote_parameters['REMOTE_IP']}"
  remote_file="${remote_parameters['REMOTE_FILE']}"
  remote_file_host="${remote_parameters['REMOTE_FILE_HOST']}"

  send=${options_values['SEND']}
  get=${options_values['GET']}
  to_path=${options_values['TO']:-'.'}

  transfer_path="${get:-$send}"
  ssh_compose=$(handle_ssh)
  filename=$(basename "$transfer_path")
  exist_path="$to_path"

  case "$transfer_type" in
    'send')
      cmd_manager "$flag" "${ssh_compose} '[[ -f ${to_path}/${filename} ]]'"

      if [[ "$?" -eq 0 ]]; then
        complain "The '${filename}' file already exists on the remote machine."
        if [[ $(ask_yN 'Do you wish to overwrite it?') =~ '0' ]]; then
          return 125 # ECANCELED
        fi
      fi

      if [[ ! -e "$transfer_path" ]]; then
        complain "The file or directory '${transfer_path}' does not exist."
        return 2 # ENOENT
      fi

      cmd="rsync -avzq ${transfer_path} -e "
      rsync_options="'ssh -p ${port}' ${user}@${remote}:${to_path}"

      if [[ -f "$remote_file" ]]; then
        rsync_options="'ssh -F ${remote_file}' ${remote_file_host}:${to_path}"
      fi

      cmd+="$rsync_options"

      cmd_manager "$flag" "$cmd"

      rsync_return_code="$?"
      if [[ "$rsync_return_code" -ne 0 ]]; then
        complain "An error occurred while uploading the file(s). rsync return code: ${rsync_return_code}"
        return "$rsync_return_code"
      fi

      success 'File(s) uploaded successfully.'
      ;;
    'get')
      cmd_manager "$flag" "${ssh_compose} [[ ! -e '${transfer_path}' ]]"
      if [[ "$?" -eq 0 ]]; then
        complain "The file or directory '${transfer_path}' does not exist on the remote machine."
      fi

      if [[ -f "${to_path}/${filename}" ]]; then
        complain "The '${filename}' file already exists."

        if [[ $(ask_yN 'Do you wish to overwrite it?') =~ '0' ]]; then
          return 125 # ECANCELED
        fi
      fi

      cmd='rsync -e '
      rsync_options="'ssh -p ${port}' -avzq ${user}@${remote}:${transfer_path} ${to_path}"

      if [[ -f "$remote_file" ]]; then
        rsync_options="'ssh -F ${remote_file}' -avzq ${remote_file_host}:${transfer_path} ${to_path}"
      fi

      cmd+="$rsync_options"

      cmd_manager "$flag" "$cmd"
      rsync_return_code="$?"
      if [[ "$rsync_return_code" -ne 0 ]]; then
        complain "An error occurred while uploading the file(s). rsync return code: ${rsync_return_code}"
        exit "$rsync_return_code"
      fi

      success 'The file(s) have been successfully received.'
      ;;
    *)
      complain "Invalid transfer type: '${transfer_type}'"
      ;;
  esac
}

function run_script_in_the_remote()
{
  local script_path
  local ssh_compose
  local ssh_script
  local flag="$1"

  flag=${flag:-'SILENT'}

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
  local flag="$1"

  flag=${flag:-'SILENT'}

  ssh_compose=$(handle_ssh)

  cmd_manager "$flag" "$ssh_compose"
}

function parser_ssh_options()
{
  local options
  local long_options='help,test_mode,script:,command:,remote:,verbose,send:,get:,to:'
  local short_options='h,s:,c:,r:'
  local transition_variables

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'ssh' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['SCRIPT']=''
  options_values['SEND']=''
  options_values['GET']=''
  options_values['TO']=''
  options_values['COMMAND']=''
  options_values['VERBOSE']=''
  options_values['TEST_MODE']=''

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
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      --send)
        options_values['SEND']="$2"
        shift 2
        ;;
      --get)
        options_values['GET']="$2"
        shift 2
        ;;
      --to)
        options_values['TO']="$2"
        shift 2
        ;;
      --help | -h)
        ssh_help "$1"
        exit
        ;;
      TEST_MODE)
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
    '  ssh (--verbose) - enable verbose for ssh operation' \
    '  ssh (-r | --remote) - ssh command line remote' \
    '  ssh (-s | --script) <script-path> - Script path in the host that will run in the target' \
    '  ssh (-c | --command) <string-command> - Command to be executed in the target machine' \
    '  ssh (--send <local-path> [--to <remote-path>])- Sends a file or directory from the local machine to the specified remote path.' \
    '  ssh (--get <remote-path> [--to <local-path>])- Gets a file or directory from the specified remote path and saves it to the local machine.'
}
