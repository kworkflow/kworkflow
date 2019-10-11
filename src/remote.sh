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
DEPLOY_SCRIPT="$plugins_path/kernel_install/deploy.sh"

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
  local flag="$2"
  local remote="$3"
  local port="$4"
  local user="$5"
  local composed_cmd=""

  if [[ -z "$command" ]]; then
    warning "No command specified"
    exit 22
  fi

  # Set default values if not specified
  remote=${remote:-"localhost"}
  port=${port:-"22"}
  user=${user:-"root"}
  flag=${flag:-"HIGHLIGHT_CMD"}

  composed_cmd="ssh -p $port $user@$remote \"$command\""
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
  local src="$1"
  local dst="$2"
  local remote="$3"
  local port="$4"
  local user="$5"
  local flag="$6"

  src=${src:-"$kw_dir/$LOCAL_TO_DEPLOY_DIR/*"}

  dst=${dst:-"$REMOTE_KW_DEPLOY"}
  remote=${remote:-"localhost"}
  port=${port:-"22"}
  user=${user:-"root"}
  flag=${flag:-"HIGHLIGHT_CMD"}

  cmd_manager "$flag" "rsync -e 'ssh -p $port' -La $src $user@$remote:$dst"
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
  local remote="$1"
  local port="$2"
  local user="$3"
  local flag="$4"

  cmd="cat /etc/os-release | grep -w ID | cut -d = -f 2"
  remote=${remote:-"localhost"}
  port=${port:-"22"}
  user=${user:-"root"}
  flag=${flag:-"SILENT"}

  cmd_remotely "$cmd" "$flag" "$remote" "$port" "$user"
}
