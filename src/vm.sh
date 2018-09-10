function kw::vm_mount_old
{
  sudo mount -o loop,offset=32256 $VDISK $QEMU_MNT
}

function kw::vm_mount
{
  mkdir -p $MOUNT_POINT
  kw::say "Mount $VDISK in $MOUNT_POINT"
  guestmount -a $VDISK -i $MOUNT_POINT
  if [ "$?" != 0 ] ; then
    kw::complain "Something went wrong when tried to mount $VDISK in $MOUNT_POINT"
  fi
}

function kw::vm_umount
{
  kw::say "Unmount $MOUNT_POINT"
  guestunmount $MOUNT_POINT
  if [ "$?" != 0 ] ; then
    kw::complain "Something went wrong when tried to unmount $VDISK in $MOUNT_POINT"
  fi
}

function kw::vm_boot
{
  $QEMU -hda $VDISK \
    ${QEMU_OPTS} \
    -kernel $BUILD_DIR/$TARGET/arch/x86/boot/bzImage \
    -append "root=/dev/sda1 debug console=ttyS0 console=ttyS1 console=tty1" \
    -net nic -net user,hostfwd=tcp::5555-:22 \
    -serial stdio \
    -device virtio-gpu-pci,virgl -display gtk,gl=on 2> /dev/null
}

function kw::vm_up
{

  kw::check_local_configuration

  kw::say "Starting Qemu with: "
  echo "$QEMU ${configurations[qemu_hw_options]}" \
       "${configurations[qemu_net_options]}" \
       "${configurations[qemu_path_image]}"

  $QEMU ${configurations[qemu_hw_options]} \
        ${configurations[qemu_net_options]} \
        ${configurations[qemu_path_image]}
}

function kw::vm_ssh
{
  kw::say "SSH to: port: " ${configurations[port]} " ip: " ${configurations[ip]}
  ssh -p ${configurations[port]} ${configurations[ip]}
}

function kw::vm_prepare
{
  local path_ansible=$HOME/.config/kw/deploy_rules/
  local current_path=$PWD
  kw::say "Deploying with Ansible, this will take some time"
  cd $path_ansible
  ansible-playbook kworkflow.yml --extra-vars "user=$USER" || cd $current_path
  cd $current_path
}
