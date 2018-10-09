. $src_script_path/commons.sh --source-only

function vm_mount
{
  check_local_configuration

  mkdir -p $MOUNT_POINT
  say "Mount $VDISK in $MOUNT_POINT"
  guestmount -a $VDISK -i $MOUNT_POINT
  if [ "$?" != 0 ] ; then
    complain "Something went wrong when tried to mount $VDISK in $MOUNT_POINT"
    return 1
  fi
}

function vm_umount
{
  check_local_configuration

  say "Unmount $MOUNT_POINT"
  guestunmount $MOUNT_POINT
  if [ "$?" != 0 ] ; then
    complain "Something went wrong when tried to unmount $VDISK in $MOUNT_POINT"
    return 1
  fi
}

function vm_boot
{
  check_local_configuration

  $QEMU -hda $VDISK \
    ${QEMU_OPTS} \
    -kernel $BUILD_DIR/$TARGET/arch/x86/boot/bzImage \
    -append "root=/dev/sda1 debug console=ttyS0 console=ttyS1 console=tty1" \
    -net nic -net user,hostfwd=tcp::5555-:22 \
    -serial stdio \
    -device virtio-gpu-pci,virgl -display gtk,gl=on 2> /dev/null
}

function vm_up
{

  check_local_configuration

  say "Starting Qemu with: "
  echo "$QEMU ${configurations[qemu_hw_options]}" \
       "${configurations[qemu_net_options]}" \
       "${configurations[qemu_path_image]}"

  $QEMU ${configurations[qemu_hw_options]} \
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
  local ret=0
  say "Deploying with Ansible, this will take some time"
  cd $path_ansible
  ansible-playbook kworkflow.yml --extra-vars "user=$USER"
  ret=$?
  cd $current_path
  return $ret
}
