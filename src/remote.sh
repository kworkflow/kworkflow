# NOTE: It is recommended that src/kw_config_loader.sh be included before this
# file
include "$KW_LIB_DIR/kw_config_loader.sh"

# We now have a kw directory visible for users in the home directory, which is
# used for saving temporary files to be deployed in the target machine.
LOCAL_REMOTE_DIR="remote"
LOCAL_TO_DEPLOY_DIR="to_deploy"

# For making the deploy in the remote machine straightforward, we create a
# directory on the host that will be used for centralizing files required for
# the new deploy.
REMOTE_KW_DEPLOY="/root/kw_deploy"

# We have a generic script named `distro_deploy.sh` that handles the essential
# operation of installing a new kernel; it depends on "kernel_install" plugin
# for work as expected
DISTRO_DEPLOY_SCRIPT="$REMOTE_KW_DEPLOY/distro_deploy.sh"
DEPLOY_SCRIPT="$KW_PLUGINS_DIR/kernel_install/deploy.sh"
DEPLOY_SCRIPT_SUPPORT="$KW_PLUGINS_DIR/kernel_install/utils.sh"

declare -gA remote_parameters

# This function is responsible for executing a command in a remote machine.
#
# @command Command to be executed inside the remote machine
# @flag How to display a command, the default value is
#   "HIGHLIGHT_CMD". For more options see `src/kwlib.sh` function `cmd_manager`
# @remote IP or domain name. Default value is "localhost".
# @port TCP Port. Default value is "22".
# @user User in the host machine. Default value is "root"
#
# Returns:
# If no command is specified, we finish the execution and return 22
function cmd_remotely()
{
  local command="$1"
  local flag=${2:-"HIGHLIGHT_CMD"}
  local remote=${3:-${configurations[ssh_ip]}}
  local port=${4:-${configurations[ssh_port]}}
  local user=${5:-${configurations[ssh_user]}}
  local bash_code="$6"
  local composed_cmd=""

  if [[ -z "$command" ]]; then
    warning "No command specified"
    exit 22
  fi

  composed_cmd="ssh -p $port $user@$remote"
  if [[ -v configurations['ssh_configfile'] && -v configurations['hostname'] ]]; then
    composed_cmd="ssh -F ${configurations['ssh_configfile']} ${configurations['hostname']}"
  fi

  if [[ "$bash_code" == 1 ]]; then
    composed_cmd="$composed_cmd 'sudo bash -c '\''$command'\'"
  else
    composed_cmd="$composed_cmd sudo \"$command\""
  fi

  cmd_manager "$flag" "$composed_cmd"
}

# This function copy files from host to the remote machine. kw has its
# directory for copying data from the host to remote and vice-versa; for this
# reason, this function uses these directories as a default behavior (for more
# information see LOCAL_TO_DEPLOY_DIR).
#
# @src Origin of the file to be send
# @dst Destination for sending the file
# @remote IP or domain name. Default value is "localhost".
# @port TCP Port. Default value is "22".
# @user User in the host machine. Default value is "root"
# @flag How to display a command, the default value is "HIGHLIGHT_CMD". For
#   more options see `src/kwlib.sh` function `cmd_manager`
function cp_host2remote()
{
  local src=${1:-"$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"}
  local dst=${2:-"$REMOTE_KW_DEPLOY"}
  local remote=${3:-${remote_parameters['REMOTE_IP']}}
  local port=${4:-${remote_parameters['REMOTE_PORT']}}
  local user=${5:-${remote_parameters['REMOTE_USER']}}
  local flag=${6:-"HIGHLIGHT_CMD"}

  if [[ -v configurations['ssh_configfile'] && -v configurations['hostname'] ]]; then
    cmd_manager "$flag" "rsync -e 'ssh -F ${configurations['ssh_configfile']}' -La $src ${configurations['hostname']}:$dst --rsync-path='sudo rsync'"
  else
    cmd_manager "$flag" "rsync -e 'ssh -p $port' -La $src $user@$remote:$dst --rsync-path='sudo rsync'"
  fi

  cmd_remotely "chown -R root:root $dst" "$flag" "$remote" "$port" "$user"
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
  local flag=${4:-"SILENT"}

  cmd='cat /etc/os-release | grep -w ID | cut -d = -f 2'
  cmd_remotely "$cmd" "$flag" "$remote" "$port" "$user"
}

# Kw can deploy a new kernel image or modules (or both) in a target machine
# based on a Linux repository; however, we need a place for adding the
# intermediaries archives that we will send to a remote device. This function
# prepares such a directory.
function prepare_host_deploy_dir()
{
  if [[ -z "$KW_CACHE_DIR" ]]; then
    complain "\$KW_CACHE_DIR isn't set. The kw directory at home may not exist"
    return 22
  fi

  # We should expect the setup.sh script create the directory $HOME/kw.
  # However, does not hurt check for it and create in any case
  if [[ ! -d "$KW_CACHE_DIR" ]]; then
    mkdir -p "$KW_CACHE_DIR"
  fi

  if [[ ! -d "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR" ]]; then
    mkdir -p "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR"
  fi

  if [[ ! -d "$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR" ]]; then
    mkdir -p "$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR"
  fi
}

# To deploy a new kernel or module, we have to prepare a directory in the
# remote machine that will accommodate a set of files that we need to update
# the kernel. This function checks if we support the target distribution and
# finally prepared the remote machine for receiving the new kernel. Finally, it
# creates a "/root/kw_deploy" directory inside the remote machine and prepare
# it for deploy.
#
# @remote IP address of the target machine
# @port Destination for sending the file
# @user User in the host machine. Default value is "root"
# @flag How to display a command, default is SILENT
function prepare_remote_dir()
{
  local remote="$1"
  local port="$2"
  local user="$3"
  local flag="$4"
  local kw_deploy_cmd="mkdir -p $REMOTE_KW_DEPLOY"
  local distro_info=""
  local distro=""

  distro_info=$(which_distro "$remote" "$port" "$user")
  distro=$(detect_distro "/" "$distro_info")

  if [[ $distro =~ "none" ]]; then
    complain "Unfortunately, there's no support for the target distro"
    exit 95 # ENOTSUP
  fi

  cmd_remotely "$kw_deploy_cmd" "$flag" "$remote" "$port" "$user"

  # Send the specific deploy script as a root
  cp_host2remote "$KW_PLUGINS_DIR/kernel_install/$distro.sh" \
    "$DISTRO_DEPLOY_SCRIPT" "$remote" "$port" "$user" "$flag"
  cp_host2remote "$DEPLOY_SCRIPT" "$REMOTE_KW_DEPLOY/" "$remote" "$port" \
    "$user" "$flag"
  cp_host2remote "$DEPLOY_SCRIPT_SUPPORT" "$REMOTE_KW_DEPLOY/" "$remote" \
    "$port" "$user" "$flag"
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
  else # CLI
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
