. $src_script_path/commons.sh --source-only

function vm_mount
{
  check_local_configuration

  mkdir -p ${configurations[mount_point]}
  say "Mount ${configurations[vdisk]} in ${configurations[mount_point]}"
  guestmount -a ${configurations[vdisk]} -i ${configurations[mount_point]}
  if [ "$?" != 0 ] ; then
    complain "Something went wrong when tried to mount ${configurations[vdisk]} in ${configurations[mount_point]}"
  fi
}

function vm_umount
{
  check_local_configuration

  say "Unmount ${configurations[mount_point]}"
  guestunmount ${configurations[mount_point]}
  if [ "$?" != 0 ] ; then
    complain "Something went wrong when tried to unmount ${configurations[vdisk]} in ${configurations[mount_point]}"
  fi
}

function vm_boot
{
  check_local_configuration

  ${configurations[qemu]} -hda ${configurations[vdisk]} \
    ${configurations[qemu_opts]}\
    -kernel ${configurations[build_dir]}/$TARGET/arch/x86/boot/bzImage \
    -append "root=/dev/sda1 debug console=ttyS0 console=ttyS1 console=tty1" \
    -net nic -net user,hostfwd=tcp::5555-:22 \
    -serial stdio \
    -device virtio-gpu-pci,virgl -display gtk,gl=on 2> /dev/null
}

function vm_up
{

  check_local_configuration

  say "Starting Qemu with: "
  echo "${configurations[qemu]} ${configurations[qemu_hw_options]}" \
       "${configurations[qemu_net_options]}" \
       "${configurations[qemu_path_image]}"

  ${configurations[qemu]} ${configurations[qemu_hw_options]} \
        ${configurations[qemu_net_options]} \
        ${configurations[qemu_path_image]}
}

function vm_ssh
{
  check_local_configuration

  say "SSH to: port: " ${configurations[port]} " ip: " ${configurations[ip]}
  ssh -p ${configurations[port]} ${configurations[ip]}
}

function vm_prepare
{
  local path_ansible=$HOME/.config/kw/deploy_rules/
  local current_path=$PWD
  say "Deploying with Ansible, this will take some time"
  cd $path_ansible
  ansible-playbook kworkflow.yml --extra-vars "user=$USER" || cd $current_path
  cd $current_path
}
