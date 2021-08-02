include "$KW_LIB_DIR/remote.sh"

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
  local opts="$*"
  local port="${remote_parameters['REMOTE_PORT']}"
  local target="${remote_parameters['REMOTE_IP']}"
  local script_path

  populate_remote_info ''

  if [[ "$1" == -h ]]; then
    ssh_help
    exit 0
  fi

  # Mandatory parameter
  if [ -z "$target" ]; then
    complain "Invalid argument: $*"
    complain "Take a look at the config file, something is wrong in the ssh_ip"
    exit 22 # EINVAL
  fi

  if [[ "$#" -gt 0 ]]; then
    if [[ "$opts" =~ ^(--command|-c)= ]]; then
      opts="$(echo "$opts" | cut -d = -f2)"
    elif [[ "$opts" =~ ^(--script|-s)= ]]; then
      script_path=$(echo "$opts" | cut -d = -f2)

      if [[ ! -f $script_path ]]; then
        complain "No such file: \"$script_path\""
        exit 2 # ENOENT
      fi

      opts="\"bash -s\" -- < $script_path"
    else
      complain "Invalid arguments: $*"
      exit 22 # EINVAL
    fi
  fi

  # Add port
  if [ -n "$port" ]; then
    port="-p $port"
  fi

  say "ssh $port $target $opts"
  eval "ssh $port $target $opts"
}

function ssh_help()
{
  echo -e "kw ssh|s options:\n" \
    "\tssh|s [--script|-s=\"SCRIPT PATH\"]\n" \
    "\tssh|s [--command|-c=\"COMMAND\"]"
}
