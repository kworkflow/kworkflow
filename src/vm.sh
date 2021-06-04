. "$KW_LIB_DIR/kw_config_loader.sh" --source-only
. "$KW_LIB_DIR/kwlib.sh" --source-only

function vm_mount()
{
  local flag="$1"
  local qemu_img_path="$2"
  local mount_point_path="$3"
  local guestmount_cmd
  local ret

  flag=${flag:-"SILENT"}
  qemu_img_path="${qemu_img_path:-${configurations[qemu_path_image]}}"
  mount_point_path="${mount_point_path:-${configurations[mount_point]}}"

  [[ $(findmnt "$mount_point_path") ]] && return 125

  mkdir -p $mount_point_path

  say "Mount $qemu_img_path in $mount_point_path"

  guestmount_cmd="guestmount -a $qemu_img_path -i $mount_point_path 2>&1"
  cmd_manager "$flag" "$guestmount_cmd"
  if [[ "$ret" ]] ; then
    complain "Something went wrong when tried to mount $qemu_img_path" \
       "in $mount_point_path"
    return "$ret"
  fi

  return 0
}

function vm_umount()
{
  local flag="$1"
  local qemu_img_path="$2"
  local mount_point_path="$3"
  local guestumount_cmd
  local ret

  flag=${flag:-"SILENT"}
  qemu_img_path="${qemu_img_path:-${configurations[qemu_path_image]}}"
  mount_point_path="${mount_point_path:-${configurations[mount_point]}}"

  if [[ $(findmnt "$mount_point_path") ]]; then
    say "Unmount $mount_point_path"

    guestumount_cmd="guestunmount $mount_point_path"
    cmd_manager "$flag" "$guestumount_cmd"
    ret="$?"
    if [[ "$ret" != 0 ]] ; then
      complain "Something went wrong when tried to unmount $qemu_img_path" \
         "in $mount_point_path"
      return "$ret"
    fi
    return 0
  fi

  return 125 #ECANCELED
}

function vm_up()
{
  say "Starting Qemu with: "
  echo "${configurations[virtualizer]} ${configurations[qemu_hw_options]}" \
       "${configurations[qemu_net_options]}" \
       "${configurations[qemu_path_image]}"

  ${configurations[virtualizer]} ${configurations[qemu_hw_options]} \
        ${configurations[qemu_net_options]} \
        ${configurations[qemu_path_image]}
}

# This function manages ssh operations. Currently, we have three basic actions:
# connect to the VM, execute a command in the VM, and perform a local script
# inside the VM.
#
# @opts Expects a parameter to be passed for the ssh command (it could be
#       --command, -c, --script, -s). If this parameter receives a null value
#       this function will make a simple ssh operation; otherwise, a command or
#       script will be attempted to execute.
function vm_ssh()
{
  local opts=$@
  local port=${configurations[ssh_port]}
  local target=${configurations[ssh_ip]}

  if [[ "$1" == -h ]]; then
    ssh_help
    exit 0
  fi

  # Mandatory parameter
  if [ -z "$target" ]; then
    complain "Invalid argument: $@"
    complain "Take a look at the config file, something is wrong in the ssh_ip"
    exit 22 # EINVAL
  fi

  if [[ $# -gt 0 ]]; then
    if [[ "$opts" =~ ^(--command|-c)= ]]; then
      opts="$(echo $opts | cut -d = -f2)"
    elif [[ "$opts" =~ ^(--script|-s)= ]]; then
      local script_path=$(echo $opts | cut -d = -f2)

      if [[ ! -f $script_path ]]; then
        complain "No such file: \"$script_path\""
        exit 2 # ENOENT
      fi

      opts="\"bash -s\" -- < $script_path"
    else
      complain "Invalid arguments: $@"
      exit 22 # EINVAL
    fi
  fi

  # Add port
  if [ ! -z "$port" ]; then
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
