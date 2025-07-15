# NOTE: It is recommended that src/lib/kw_config_loader.sh be included before this
# file
include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

# We now have a kw directory visible for users in the home directory, which is
# used for saving temporary files to be deployed in the target machine.
LOCAL_REMOTE_DIR='remote'
LOCAL_TO_DEPLOY_DIR='to_deploy'

# For making the deploy in the remote machine straightforward, we create a
# directory on the host that will be used for centralizing files required for
# the new deploy.
REMOTE_KW_DEPLOY='/root/kw_deploy'

declare -gA remote_parameters

# This function checks if connecting to the host machine via ssh is possible.
# It is helpful to invoke this function before performing any meaningful
# operation that depends on the ssh connection.
#
# @flag: How to display a command, the default value is
#   'SILENT'. For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @remote: IP or domain name.
# @port: TCP Port. Default value is 22.
# @user: User in the host machine. Default value is "root"
# @remote_file: Path to the remote file
# @remote_file_host: Hostname in the ssh file
#
# Returns:
# In case of success, this function returns 0, otherwise, it can return:
# 2   - It did not find the remote_file
# 101 - Network is not reachable
# 125 - The operation was canceled
# 255 - Unknown error
function is_ssh_connection_configured()
{
  local flag=${1:-'SILENT'}
  local remote=${2:-${remote_parameters['REMOTE_IP']}}
  local port=${3:-${remote_parameters['REMOTE_PORT']}}
  local user=${4:-${remote_parameters['REMOTE_USER']}}
  local remote_file=${5:-${remote_parameters[REMOTE_FILE]}}
  local remote_file_host=${5:-${remote_parameters[REMOTE_FILE_HOST]}}
  local ssh_cmd='ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5'
  local output
  local ret

  if [[ -z "$remote" && -z "$port" && -z "$user" ]]; then
    if [[ -n "${remote_file}" ]]; then
      ssh_cmd+=" -F ${remote_file} ${remote_file_host}"
    else
      return 2 # ENOENT
    fi
  else
    ssh_cmd+=" -p ${port} ${user}@${remote}"
  fi

  [[ "$flag" == 'VERBOSE' ]] && ssh_cmd+=' -v'

  ssh_cmd+=' exit'

  output=$(cmd_manager "$flag" "$ssh_cmd" 2>&1)
  if [[ "$?" == 255 ]]; then
    ssh_error_handling "$output"
    # The remove host identification issue
    if [[ "$?" == 111 ]]; then
      remove_key_from_kwown_hosts "$flag" "$ssh_cmd"
      ret="$?"

      # User canceled the manual update
      [[ "$ret" == 125 ]] && return 125 # ECANCELED
      # Some other unknown error occurred
      [[ "$ret" != 0 ]] && return 101 # ENETUNREACH

      # Retry the ssh command
      cmd_manager "$flag" "$ssh_cmd"
      [[ "$?" != 0 ]] && return 101 # ENETUNREACH
      return 0
    fi

    return 255
  fi

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s\n' "$output"

  return 0
}

# This function is responsible for handling specific ssh errors. Unfortunately,
# when the SSH command fails, it always returns 255, which does not provide a
# fine-grained way to deal with particular issues. To workaround this
# limitation, this function parses the error message.
#
# @error_message: String with the error message from the ssh command
#
# Return:
# 0 - If does not find anything
# 111 - If remote host identification has changed
function ssh_error_handling()
{
  local error_message="$1"
  local remote_host_change_message='.*WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED.*'

  # Case 1: Remote host identification change, return 111
  grep --line-regexp --quiet "$remote_host_change_message" <<< "$error_message"
  if [[ "$?" == 0 ]]; then
    return 111 # ECONNREFUSED
  fi

  return 0
}

# Remove current host from the known_hosts file.
#
# @flag: How to display a command, the default value is
#   "HIGHLIGHT_CMD". For more options see `src/lib/kwlib.sh` function `cmd_manager`.
# @ssh_cmd: The ssh command that failed to execute.
#
# Returns:
# 0 - If everything is ok
# 125 - if the user cancel the operation or the result code from ssh-keygen
#       command.
function remove_key_from_kwown_hosts()
{
  local flag=${1:-'SILENT'}
  local ssh_cmd="$2"
  local remove_key_cmd='ssh-keygen -q -f'

  #shellcheck disable=SC2119
  extract_remote_info_from_config_file

  remove_key_cmd+=" '${HOME}/.ssh/known_hosts' -R '${remote_parameters['REMOTE_IP']}'"

  warning 'kw was not able to ssh into:'
  warning " Host: ${remote_parameters['REMOTE_IP']}"
  warning " Port: ${remote_parameters['REMOTE_PORT']}"
  warning " User: ${remote_parameters['REMOTE_USER']}"
  warning 'Due to a remote host identification issue.'
  if [[ $(ask_yN 'Do you want kw to remove the current host from the known_hosts file?') =~ '0' ]]; then
    say ' No problem, the operation has been canceled.'
    say ' You can try to manually check the kw issue by using the below command:'
    say "  ${ssh_cmd}"
    return 125 # ECANCELED
  fi

  cmd_manager "$flag" "$remove_key_cmd"
}

# This function converts part of the information in the ssh file into the
# remote_parameters array.
#
# @remote_file_host: Hostname in the ssh file
# @remote_file: Path to the remote file
function extract_remote_info_from_config_file()
{
  local remote_file_host=${1:-${remote_parameters['REMOTE_FILE_HOST']}}
  local remote_file=${2:-${remote_parameters['REMOTE_FILE']}}
  local trimmed_remote_file
  local line_number
  local remote
  local line
  local port
  local user

  # Getting the line number of the target host
  line_number=$(grep --line-number "^Host ${remote_file_host}\$" "$remote_file" | cut --delimiter=':' -f1)
  ((line_number++))
  # Trimming remote file from target host line upward
  trimmed_remote_file=$(tail --lines "+${line_number}" "${remote_file}")
  # Getting the line number of next host from target host, if it exists
  line_number=$(printf '%s' "$trimmed_remote_file" | grep --line-number --max-count=1 '^Host' | cut --delimiter=':' -f1)
  # In case next host exists, trim remote file again from next host line downward
  if [[ -n "$line_number" ]]; then
    ((line_number--))
    trimmed_remote_file=$(printf '%s' "$trimmed_remote_file" | head --lines "$line_number")
  fi

  # Here, we are matching lines with Hostname/Port/User occurrences that happen between the target
  # host line and the next host line (if it exists) in the remote config file and only have leading
  # spaces (excludes commented lines). We then cut the resulting string to get only the value of
  # the Hostname/Port/User line.
  line=$(printf '%s' "$trimmed_remote_file" | grep --max-count=1 '^[[:blank:]]*Hostname')
  remote=$(printf '%s' "$line" | rev | cut --delimiter=' ' -f1 | rev)

  line=$(printf '%s' "$trimmed_remote_file" | grep --max-count=1 '^[[:blank:]]*Port')
  port=$(printf '%s' "$line" | rev | cut --delimiter=' ' -f1 | rev)

  line=$(printf '%s' "$trimmed_remote_file" | grep --max-count=1 '^[[:blank:]]*User')
  user=$(printf '%s' "$line" | rev | cut --delimiter=' ' -f1 | rev)

  remote_parameters['REMOTE_IP']="$remote"
  remote_parameters['REMOTE_PORT']="$port"
  remote_parameters['REMOTE_USER']="$user"
}

function ssh_connection_failure_message()
{
  local remote=${remote_parameters['REMOTE_IP']}
  local port=${remote_parameters['REMOTE_PORT']}
  local user=${remote_parameters['REMOTE_USER']}
  local remote_file=${remote_parameters['REMOTE_FILE']}
  local remote_file_host=${remote_parameters['REMOTE_FILE_HOST']}
  local line_number
  local trimmed_remote_file
  local line

  # If a config file is being used, we need to set the IP, port
  # and user from the config file.
  if [[ -z "$remote" && -z "$port" && -z "$user" ]]; then
    if [[ -n "${remote_parameters['REMOTE_FILE']}" ]]; then
      #shellcheck disable=SC2119
      extract_remote_info_from_config_file
      remote="${remote_parameters['REMOTE_IP']}"
      user="${remote_parameters['REMOTE_USER']}"
      port="${remote_parameters['REMOTE_PORT']}"
    else
      complain 'Could not find remote config file.'
      complain 'Suggestion: check if there is a remote.config or try using'
      complain '  kw ssh (-r | --remote) <user>@<ip>:<port>'
      return
    fi
  fi

  complain 'We could not reach the remote machine by using:'
  complain " IP: ${remote}"
  complain " User: ${user}"
  complain " Port: ${port}"
  complain 'Please ensure that the above info is correct.'
  complain 'Suggestion: Check if your remote machine permits root login via ssh'
  complain 'or check if your public key is in the remote machine.'
}

# This function is responsible for executing a command in a remote machine.
#
# @command Command to be executed inside the remote machine
# @flag How to display a command, the default value is
#   "HIGHLIGHT_CMD". For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @remote IP or domain name.
# @port TCP Port. Default value is 22.
# @user User in the host machine. Default value is "root"
# @bash_code If this parameter is set with a value, we are trying to run shell
#   code in the remote by using a string.
# @save_output_path This command implies that the user wants to capture the
#   output in a specific path.
#
# Returns:
# If no command is specified, we finish the execution and return 22
function cmd_remotely()
{
  local flag=${1:-'HIGHLIGHT_CMD'}
  local command="$2"
  local remote=${3:-${remote_parameters['REMOTE_IP']}}
  local port=${4:-${remote_parameters['REMOTE_PORT']}}
  local user=${5:-${remote_parameters['REMOTE_USER']}}
  local bash_code="$6"
  local save_output_path="$7"
  local composed_cmd="ssh -p ${port} ${user}@${remote}"
  local redirect_mode=''

  if [[ -z "$command" ]]; then
    warning 'No command specified'
    exit 22
  fi

  # If all parameters are empty, we must try the config file
  if [[ -z "$remote" && -z "$port" && -z "$user" ]]; then
    if [[ -n ${remote_parameters['REMOTE_FILE']} ]]; then
      composed_cmd="ssh -F ${remote_parameters['REMOTE_FILE']} ${remote_parameters['REMOTE_FILE_HOST']}"
    fi
  fi

  if [[ -n "$save_output_path" ]]; then
    redirect_mode='KW_REDIRECT_MODE'
  fi

  if [[ -n "$bash_code" ]]; then
    composed_cmd="$composed_cmd 'sudo bash -c '\''$command'\'"
  else
    composed_cmd="$composed_cmd sudo \"$command\""
  fi

  cmd_manager "$flag" "$composed_cmd" "$redirect_mode" "$save_output_path"
}

# This function copy files from host to the remote machine. kw has its
# directory for copying data from the host to remote and vice-versa; for this
# reason, this function uses these directories as a default behavior (for more
# information see LOCAL_TO_DEPLOY_DIR).
#
# @src Origin of the file to be send
# @dst Destination for sending the file
# @flag How to display a command, the default value is "HIGHLIGHT_CMD". For
#   more options see `src/lib/kwlib.sh` function `cmd_manager`
# @rsync_params Additional optional flags and parameters to be passed directly to rsync
function cp2remote()
{
  local flag=${1:-'HIGHLIGHT_CMD'}
  local src=${2:-"${KW_CACHE_DIR}/${LOCAL_TO_DEPLOY_DIR}/*"}
  local dst=${3:-"${REMOTE_KW_DEPLOY}"}
  local rsync_params="$4"
  local remote=${5:-${remote_parameters['REMOTE_IP']}}
  local port=${6:-${remote_parameters['REMOTE_PORT']}}
  local user=${7:-${remote_parameters['REMOTE_USER']}}
  local quiet="$8"
  local progress_flag='--info=progress2'

  if [[ -z "$remote" && -z "$port" && -z "$user" ]]; then
    if [[ -n ${remote_parameters['REMOTE_FILE']} ]]; then
      rsync_target="'ssh -F ${remote_parameters['REMOTE_FILE']}' ${src} ${remote_parameters['REMOTE_FILE_HOST']}:$dst"
    fi
  else
    rsync_target="'ssh -p ${port}' ${src} ${user}@${remote}:${dst}"
  fi

  [[ -n "$quiet" ]] && progress_flag=''

  # The -LrlptD flags for rsync are similar to the -La flags used for archiving
  # files and resolving symlinks the diference lies on the absence of the -og
  # flags that preserve group and user ownership. We don't want to preserve
  # ownership in order to automatically transfer the files to the root user and
  # group. --partial --progress
  cmd_manager "$flag" "rsync $progress_flag -e $rsync_target -LrlptD --rsync-path='sudo rsync' $rsync_params"
}

# This function copies files from the remote machine to the local host.
#
# @src: file path from a path stored in the remote machine
# @dst: path from local machine to store the file we're retrieving
# @ip: IP or domain name
# @port: TCP port
# @user: User in the remote machine
function remote2host()
{
  local flag=${1:-"HIGHLIGHT_CMD"}
  local src="$2"
  local dst="$3"
  local remote=${4:-${remote_parameters['REMOTE_IP']}}
  local port=${5:-${remote_parameters['REMOTE_PORT']}}
  local user=${6:-${remote_parameters['REMOTE_USER']}}
  local quiet="$7"
  local progress_flag='--info=progress2'

  if [[ -z "$remote" && -z "$port" && -z "$user" ]]; then
    if [[ -n ${remote_parameters['REMOTE_FILE']} ]]; then
      rsync_target="'ssh -F ${remote_parameters['REMOTE_FILE']}' ${remote_parameters['REMOTE_FILE_HOST']}:${src} ${dst}"
    fi
  else
    rsync_target="'ssh -p ${port}' ${user}@${remote}:${src} ${dst}"
  fi

  [[ -n "$quiet" ]] && progress_flag=''

  cmd_manager "$flag" "rsync $progress_flag -e $rsync_target -LrlptD --rsync-path='sudo rsync' $rsync_params"
}

# Access the target device and query the distro name.
#
# @remote Origin of the file to be send
# @port Destination for sending the file
# @user User in the host machine. Default value is "root"
# @flag How to display a command, default is SILENT
#
# Return:
# Return the distro name. The caller should call this function inside of
# subshell and save it to a variable.
function which_distro()
{
  local remote=${1:-${remote_parameters[ssh_ip]}}
  local port=${2:-${remote_parameters[ssh_port]}}
  local user=${3:-${remote_parameters[ssh_user]}}
  local flag=${4:-'SILENT'}
  local output

  cmd='cat /etc/os-release'
  output=$(cmd_remotely "$flag" "$cmd" "$remote" "$port" "$user")
  # TODO: I think we can find a better way to test this...
  if [[ "$flag" =~ 'TEST_MODE' ]]; then
    printf '%s' "$output"
    return
  fi

  detect_distro '' '' "$output"
}

# Populate remote info
#
# @parameters: Command line parameter to be parsed
#
# Returns:
# This function populates the variables REMOTE_IP, REMOTE_PORT, REMOTE_USER,
# REMOTE_FILE, and REMOTE_FILE_HOST of the remote_parameters array based on the
# config file or command line. If it cannot retrieve those data, it returns 22.
function populate_remote_info()
{
  local ip="$1"
  local temp_ip
  local port=22
  local user='root'
  local default_target
  local remote_file='remote.config'
  local local_config_file="${PWD}/.kw/remote.config"
  local etc_config_file="${KW_ETC_DIR}/remote.config"
  local target_config_file="$local_config_file"

  # Reset REMOTE variables
  remote_parameters['REMOTE_FILE']=''
  remote_parameters['REMOTE_FILE_HOST']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_USER']=''
  remote_parameters['REMOTE_IP']=''

  if [[ -n "$ip" ]]; then
    # Handling port
    remote_parameters['REMOTE_PORT']="$port"
    port=$(get_based_on_delimiter "$ip" ':' 2)
    # Use the specific port
    [[ "$?" != 22 ]] && remote_parameters['REMOTE_PORT']="$port"

    # Handling user
    remote_parameters['REMOTE_USER']="$user"
    user=$(get_based_on_delimiter "$ip" '@' 1)
    # There is no specific user, let's assume root
    [[ "$?" != 22 ]] && remote_parameters['REMOTE_USER']="$user"

    # Handling IP by making sure that we eliminate user and port
    temp_ip=$(get_based_on_delimiter "$ip" ':' 1)
    temp_ip=$(get_based_on_delimiter "$temp_ip" '@' 2)
    remote_parameters['REMOTE_IP']="$temp_ip"

    ip="${remote_parameters['REMOTE_IP']}:${remote_parameters['REMOTE_PORT']}"
    if [[ -z "${remote_parameters['REMOTE_IP']}" || "$ip" =~ ^: ]]; then
      complain 'Something went wrong with the remote parser'
      return 22 # EINVAL
    fi
  fi

  # Handling config file
  if [[ ! -f "${local_config_file}" ]]; then
    if [[ -f "${etc_config_file}" ]]; then
      target_config_file="$etc_config_file"
    else
      target_config_file=''
    fi
  fi

  # In this case, we parsed from CLI and the remote name is not part of the
  # config file
  if [[ -n "${remote_parameters['REMOTE_IP']}" && -z "$target_config_file" ]]; then
    remote_parameters['REMOTE_FILE']=''
    remote_parameters['REMOTE_FILE_HOST']=''
    return 0
  fi

  # --remote origin
  if [[ -n "${target_config_file}" ]]; then
    grep -xq "^Host ${remote_parameters['REMOTE_IP']}" "${target_config_file}"
    if [[ "$?" == 0 ]]; then
      remote_parameters['REMOTE_FILE']="${target_config_file}"
      remote_parameters['REMOTE_FILE_HOST']="${remote_parameters['REMOTE_IP']}"
      remote_parameters['REMOTE_PORT']=''
      remote_parameters['REMOTE_USER']=''
      remote_parameters['REMOTE_IP']=''
      return 0
    fi
  fi

  # Get default remote
  if [[ -n "${target_config_file}" && -z "${remote_parameters['REMOTE_IP']}" ]]; then
    grep -xq "^#kw-default=.*" "${target_config_file}"
    # Handle default target
    if [[ "$?" == 0 ]]; then
      # E.g., #kw-default=something
      default_target=$(head -1 "${target_config_file}" | cut -d '=' -f 2)
    else
      # E.g., Host something
      default_target=$(head -1 "${target_config_file}" | cut -d ' ' -f 2)
    fi
  # e.g., --remote origin
  elif [[ -n "${target_config_file}" && -n "${remote_parameters['REMOTE_IP']}" ]]; then
    grep -xq "^Host ${remote_parameters['REMOTE_IP']}" "${target_config_file}"
    if [[ "$?" == 0 ]]; then
      default_target="${remote_parameters['REMOTE_IP']}"
    else
      # If we could not find REMOTE_IP in the remote.config, we might have thses scenarios:
      # --remote AAA.BBB.CCC.DDD or --remote REMOTE_NAME
      # In those cases, we want to keep REMOTE_FILE and REMOTE_FILE_HOST empty
      return 0
    fi
  fi

  remote_parameters['REMOTE_FILE']="${target_config_file}"
  remote_parameters['REMOTE_FILE_HOST']="$default_target"

  # At this point, we are sure that we will use a config file, so... clean up
  # other variables to avoid weird issues
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_USER']=''
  remote_parameters['REMOTE_IP']=''

  return 0
}

# This function is responsible for setting up the ssh key for users, including
# the root user.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# If everything is alright, it returns 0, otherwise, it can return:
# - 103: ssh-copy-id failed
# - 101: ssh to the target machine failed
function setup_remote_ssh_with_passwordless()
{
  local flag="$1"
  local copy_key_cmd
  local users="root ${remote_parameters['REMOTE_USER']}"
  local root_user_setup=0

  flag=${flag:-'SILENT'}

  say '-> Trying to set up passwordless access'$'\n'

  for user in $users; do
    # Just avoid setup root twice
    [[ "$user" == 'root' && "$root_user_setup" == 1 ]] && continue
    [[ "$user" == 'root' ]] && ((root_user_setup++))

    # Use config file or ip info
    if [[ -n ${remote_parameters['REMOTE_FILE']} && -n ${remote_parameters['REMOTE_FILE_HOST']} ]]; then
      copy_key_cmd="ssh-copy-id -F ${remote_parameters['REMOTE_FILE']} ${remote_parameters['REMOTE_FILE_HOST']}"
    else
      copy_key_cmd="ssh-copy-id ${user}@${remote_parameters['REMOTE_IP']}"
    fi

    # Try to copy-ssh-id
    cmd_manager "$flag" "$copy_key_cmd"
    [[ "$?" != 0 ]] && return 103 # ECONNABORTED

    # Check if we can connect without password
    is_ssh_connection_configured "$flag" '' '' "$user"
    if [[ "$?" != 0 ]]; then
      return 101 # ENETUNREACH
    fi
  done
}
