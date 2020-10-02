. "$KW_LIB_DIR/kw_config_loader.sh" --source-only

function vm_mount
{
  local ret=0
  mkdir -p ${configurations[mount_point]}

  say "Mount ${configurations[qemu_path_image]}" \
      "in ${configurations[mount_point]}"

  guestmount -a ${configurations[qemu_path_image]} \
             -i ${configurations[mount_point]}

  if [ "$?" != 0 ] ; then
    complain "Something went wrong when tried to mount" \
        "${configurations[qemu_path_image]} in ${configurations[mount_point]}"
  fi

  return "$ret"
}

function vm_umount
{
  local ret=0
  say "Unmount ${configurations[mount_point]}"
  guestunmount ${configurations[mount_point]}
  ret="$?"
  if [ "$ret" != 0 ] ; then
    complain "Something went wrong when tried to unmount" \
        "${configurations[qemu_path_image]} in ${configurations[mount_point]}"
  fi

  return "$ret"
}

function vm_boot
{
  ${configurations[virtualizer]} -hda ${configurations[qemu_path_image]} \
    ${configurations[qemu_hw_options]} \
    -kernel $BUILD_DIR/$TARGET/arch/x86/boot/bzImage \
    -append "root=/dev/sda1 debug console=ttyS0 console=ttyS1 console=tty1" \
    -net nic -net user,hostfwd=tcp::5555-:22 \
    -serial stdio \
    -device virtio-gpu-pci,virgl -display gtk,gl=on 2> /dev/null
}

function vm_up
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
function vm_ssh
{
  local opts=$@
  local port=${configurations[ssh_port]}
  local target=${configurations[ssh_ip]}

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
