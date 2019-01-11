. $src_script_path/commons.sh --source-only

function vm_mount
{
  mkdir -p ${configurations[mount_point]}

  say "Mount ${configurations[qemu_path_image]}" \
      "in ${configurations[mount_point]}"

  guestmount -a ${configurations[qemu_path_image]} \
             -i ${configurations[mount_point]}

  if [ "$?" != 0 ] ; then
    complain "Something went wrong when tried to mount" \
        "${configurations[qemu_path_image]} in ${configurations[mount_point]}"
    return 1
  fi
}

function vm_umount
{
  say "Unmount ${configurations[mount_point]}"
  guestunmount ${configurations[mount_point]}
  if [ "$?" != 0 ] ; then
    complain "Something went wrong when tried to unmount" \
        "${configurations[qemu_path_image]} in ${configurations[mount_point]}"
    return 1
  fi
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

function vm_ssh
{
  say "SSH"
  say "-> Port: " ${configurations[ssh_port]} " IP: " ${configurations[ssh_ip]}
  ssh -p ${configurations[ssh_port]} ${configurations[ssh_ip]}
}

function vm_prepare
{
  local path_ansible=$HOME/.config/kw/deploy_rules/
  local current_path=$PWD
  local ret=0
  say "Deploying with Ansible, this will take some time"
  cd $path_ansible
  ansible-playbook kworkflow.yml --extra-vars "user=$USER"
  ret=$?
  cd $current_path
  return $ret
}
