. $src_script_path/commons.sh --source-only

function vm_mount
{
  check_local_configuration

  mkdir -p $MOUNT_POINT
  say "Mount $VDISK in $MOUNT_POINT"
  guestmount -a $VDISK -i $MOUNT_POINT
  if [ "$?" != 0 ] ; then
    complain "Something went wrong when tried to mount $VDISK in $MOUNT_POINT"
  fi
}

function vm_umount
{
  check_local_configuration

  say "Unmount $MOUNT_POINT"
  guestunmount $MOUNT_POINT
  if [ "$?" != 0 ] ; then
    complain "Something went wrong when tried to unmount $VDISK in $MOUNT_POINT"
  fi
}

function vm_boot
{
  #seems broken
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

  say "Starting kw libvirt network with: "
  echo "$VIRT_NET_START $VIRT_NET_NAME"
  $VIRT_NET_START $VIRT_NET_NAME
  
  say "Starting VM with: "
  echo "$VIRT_START $VIRT_VM_NAME"
  $VIRT_START $VIRT_VM_NAME
  
  say "Connecting to VM with:"
  echo "$VIRT_VIEWER $VIRT_VM_NAME"
  $VIRT_VIEWER $VIRT_VM_NAME
}

function vm_down
{
  check_local_configuration

  say "Killing the VM with: "
  echo "$VIRT_DESTROY $VIRT_VM_NAME"
  $VIRT_DESTROY $VIRT_VM_NAME
  
  say "Stopping the kw libvirt networ with: "
  echo "$VIRT_NET_DESTROY $VIRT_VM_NAME"
  $VIRT_NET_DESTROY $VIRT_VM_NAME
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
  local image_path=${configurations[qemu_path_image]}

  say "VM installation process."
  say "Creating libvirt network..."
  sudo $VIRT_NET_DEFINE $HOME/.config/kw/virt-network.xml
  $VIRT_NET_START $VIRT_NET_NAME
  say "Creating libvirt vm..."
  $VIRT_INSTALL -n $VIRT_VM_NAME \
                --ram 1024 \
                --boot hd \
                --vcpus=2 \
                --cpu=host \
                --os-type=linux \
                --os-variant=virtio26 \
                --disk=$image_path,format=qcow2 \
                --filesystem $HOME,kw_share \
                --network network=$VIRT_NET_NAME \

  #TODO: Set static IP address on virt-network.xml

  say "Deploying with Ansible, this will take some time"
  cd $path_ansible
  ansible-playbook kworkflow.yml --extra-vars "user=$USER" || cd $current_path
  cd $current_path

  $VIRT_SHUTDOWN $VIRT_VM_NAME
  $VIRT_NET_DESTROY $VIRT_NET_NAME
}
