# NOTE: It is recommended that src/kw_config_loader.sh be included before this
# file
include "$KW_LIB_DIR/kw_config_loader.sh"

# We now have a kw directory visible for users in the home directory, which is
# used for saving temporary files to be deployed in the target machine.
LOCAL_REMOTE_DIR='remote'
LOCAL_TO_DEPLOY_DIR='to_deploy'

# For making the deploy in the remote machine straightforward, we create a
# directory on the host that will be used for centralizing files required for
# the new deploy.
REMOTE_KW_DEPLOY='/root/kw_deploy'

declare -gA remote_parameters

# This function is responsible for executing a command in a remote machine.
#
# @command Command to be executed inside the remote machine
# @flag How to display a command, the default value is
#   "HIGHLIGHT_CMD". For more options see `src/kwlib.sh` function `cmd_manager`
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
  local command="$1"
  local flag=${2:-'HIGHLIGHT_CMD'}
  local remote=${3:-${configurations[ssh_ip]}}
  local port=${4:-${configurations[ssh_port]}}
  local user=${5:-${configurations[ssh_user]}}
  local bash_code="$6"
  local save_output_path="$7"
  local composed_cmd=''
  local redirect_mode=''

  if [[ -z "$command" ]]; then
    warning 'No command specified'
    exit 22
  fi

  composed_cmd="ssh -p $port $user@$remote"
  if [[ -v configurations['ssh_configfile'] && -v configurations['hostname'] ]]; then
    composed_cmd="ssh -F ${configurations['ssh_configfile']} ${configurations['hostname']}"
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
#   more options see `src/kwlib.sh` function `cmd_manager`
# @rsync_params Additional optional flags and parameters to be passed directly to rsync
function cp2remote()
{
  local flag=${1:-'HIGHLIGHT_CMD'}
  local src=${2:-"$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"}
  local dst=${3:-"$REMOTE_KW_DEPLOY"}
  local rsync_params="$4"
  local remote=${5:-${remote_parameters['REMOTE_IP']}}
  local port=${6:-${remote_parameters['REMOTE_PORT']}}
  local user=${7:-${remote_parameters['REMOTE_USER']}}

  if [[ -v configurations['ssh_configfile'] && -v configurations['hostname'] ]]; then
    rsync_target="'ssh -F ${configurations['ssh_configfile']}' $src ${configurations['hostname']}:$dst"
  else
    rsync_target="'ssh -p $port' $src $user@$remote:$dst"
  fi

  # The -LrlptD flags for rsync are similar to the -La flags used for archiving
  # files and resolving symlinks the diference lies on the absence of the -og
  # flags that preserve group and user ownership. We don't want to preserve
  # ownership in order to automatically transfer the files to the root user and
  # group.
  cmd_manager "$flag" "rsync -e $rsync_target -LrlptD --rsync-path='sudo rsync' $rsync_params"
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
  local ip=${4:-${configurations[ssh_ip]}}
  local port=${5:-${configurations[ssh_port]}}
  local user=${6:-${configurations[ssh_user]}}

  cmd_manager "$flag" "rsync -e \"ssh -p $port\" $user@$ip:$src $dst"
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

  cmd='cat /etc/os-release | grep -w ID | cut -d = -f 2'
  cmd_remotely "$cmd" "$flag" "$remote" "$port" "$user"
}

# Populate remote info
#
# @parameters: Command line parameter to be parsed
#
# Returns:
# This function populates the variables REMOTE_IP and REMOTE_PORT of the
# remote_parameters array based on the config file or command line. If it
# cannot retrieve those data, it returns 22.
function populate_remote_info()
{
  local ip="$1"
  local temp_ip
  local port=22
  local user='root'

  if [[ -z "$ip" ]]; then
    remote_parameters['REMOTE_IP']=${configurations[ssh_ip]}
    remote_parameters['REMOTE_PORT']=${configurations[ssh_port]}
    remote_parameters['REMOTE_USER']=${configurations[ssh_user]}
  else
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
  fi

  ip="${remote_parameters['REMOTE_IP']}:${remote_parameters['REMOTE_PORT']}"
  remote_parameters['REMOTE']="$ip"

  if [[ -z "$ip" || "$ip" =~ ^: ]]; then
    complain 'Something went wrong with the remote option'
    return 22 # EINVAL
  fi

  return 0
}
