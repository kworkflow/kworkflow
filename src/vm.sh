. $src_script_path/commons.sh --source-only

function vm_status
{
  local tmp=$($VIRT_LIST | grep " $1 " | awk '{ print $3}')
  if [ ! -n "$tmp" ]; then
    tmp="inexistent"
  fi
  echo $tmp
}

function net_status
{
  local tmp=$($VIRT_NET_LIST | grep " $1 " | awk '{ print $2}')
  if [ ! -n "$tmp" ]; then
    tmp="inexistent"
  fi
  echo $tmp
}

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

function vm_up
{
  check_local_configuration 

  if [ $(net_status $VIRT_NET_NAME) == "inexistent" ] || \
     [ $(vm_status $VIRT_VM_NAME) == "inexistent" ]; then
    complain "Error, either the VM or the Network is not defined." 
    complain "Please register them using 'kw register'"
    return
  fi

  if [ $(net_status $VIRT_NET_NAME) == "inactive" ]; then
    say "Starting kw libvirt network with: "
    echo "$VIRT_NET_START $VIRT_NET_NAME"
    $VIRT_NET_START $VIRT_NET_NAME
  fi

  if [ $(vm_status $VIRT_VM_NAME) == "shut" ]; then
    say "Starting VM with: "
    echo "$VIRT_START $VIRT_VM_NAME"
    $VIRT_START $VIRT_VM_NAME
  fi  

  say "Connecting to VM with:"
  echo "$VIRT_VIEWER $VIRT_VM_NAME"
  $VIRT_VIEWER $VIRT_VM_NAME
}

function vm_down
{
  check_local_configuration

  if [ $(vm_status $VIRT_VM_NAME) == "running" ]; then
    say "Killing the VM with: "
    echo "$VIRT_DESTROY $VIRT_VM_NAME"
    $VIRT_DESTROY $VIRT_VM_NAME
  fi  
 
  if [ $(net_status $VIRT_NET_NAME) == "active" ]; then
    say "Stopping the kw libvirt network with: "
    echo "$VIRT_NET_DESTROY $VIRT_NET_NAME"
    $VIRT_NET_DESTROY $VIRT_NET_NAME
  fi 
}

function vm_ssh
{
  check_local_configuration

  say "SSH to: port: " ${configurations[port]} " ip: " ${configurations[ip]}
  ssh -p ${configurations[port]} ${configurations[ip]}
}

function vm_clean
{
  say "Cleaning kw-related libvirt entries..."
  vm_down

  
  if [ $(net_status $VIRT_NET_NAME) == "inactive" ]; then
    say "Undefining kw libvirt network with: $VIRT_NET_UNDEFINE $VIRT_NET_NAME"
    $VIRT_NET_UNDEFINE $VIRT_NET_NAME
  fi
  if [ $(vm_status $VIRT_VM_NAME) == "shut" ]; then
    say "Undefining kw vm with: $VIRT_UNDEFINE $VIRT_VM_NAME"
    $VIRT_UNDEFINE $VIRT_VM_NAME
  fi
}

function vm_register
{

  check_local_configuration
  
  local current_path=$PWD
  local virt_net_config_path=$PWD/kworkflow-network.xml

  #set network config to default if inexistent
  if [ ! -f $virt_net_config_path ]; then
    virt_net_config_path=$DEFAULT_CONFIG_PATH/kworkflow-network-default.xml
  fi

  if [ $(vm_status $VIRT_VM_NAME) != "inexistent" ] || \
     [ $(net_status $VIRT_NET_NAME) != "inexistent" ]; then
    complain "It seems that either the VM or the Network is already registered."
    complain "Please run 'kw clean' to unregister both VM and Network."
    return
  fi

  say "VM installation process."
  say "Creating libvirt network. Sudo is required here."
  sudo $VIRT_NET_DEFINE --file $virt_net_config_path  
  $VIRT_NET_START $VIRT_NET_NAME
  say "Creating libvirt vm..."
  $VIRT_INSTALL -n $VIRT_VM_NAME \
                --ram 1024 \
                --boot hd \
                --vcpus=2 \
                --cpu=host \
                --os-type=linux \
                --os-variant=virtio26 \
                --disk=${configurations[virt_path_image]},format=qcow2 \
                --filesystem $HOME,kw_share \
                --network network=$VIRT_NET_NAME \

  #TODO: Set static IP address on virt-network.xml

}

function vm_prepare
{
  check_local_configuration
  
  local path_ansible=$HOME/.config/kw/deploy_rules/
  
  say "Deploying with Ansible, this will take some time"
  cd $path_ansible
  ansible-playbook kworkflow.yml --extra-vars "user=$USER" || cd $current_path
  cd $current_path

  $VIRT_SHUTDOWN $VIRT_VM_NAME
  $VIRT_NET_DESTROY $VIRT_NET_NAME
}
