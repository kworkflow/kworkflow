. $src_script_path/miscellaneous.sh --source-only

BASE=$HOME/p/linux-trees
MOUNT_POINT=$HOME/p/mount
BUILD_DIR=$BASE/build-linux

VDISK="$HOME/p/virty.qcow2"
DEFAULT_PORT="22"
DEFAULT_IP="192.168.122.2"
DEFAULT_CONFIG_PATH=$HOME/.config/kw/config_files
VIRT_NET_NAME="kworkflow-network"
VIRT_VM_NAME="kworkflow-vm"

TARGET="libvirt"

BASHPATH=/bin/bash

# Default configuration
declare -A configurations=( ["ip"]="$DEFAULT_IP" ["port"]="$DEFAULT_PORT" )

function show_variables()
{
  say "Global values:"

  echo -e "\tBASE: $BASE"
  echo -e "\tBUILD_DIR: $BUILD_DIR"
  echo -e "\tTARGET: $TARGET"

  check_local_configuration

  if [ $? -eq 1 ] ; then
    say "There is no kworkflow.conf, adopt default values for:"
    echo -e "\tVDISK: $VDISK"
  else
    say "kw found a kworkflow.conf file. Read options:"
    echo -e "\tVDISK: ${configurations[virt_path_image]}"
    echo -e "\tVIRT_DRIVER: ${configurations[virt_driver]}"
  fi
}

function check_local_configuration()
{
  local config_path=$PWD/kworkflow.config
  
  # File does not exist, use default configuration
  if [ ! -f $config_path ] ; then
    config_path=$DEFAULT_CONFIG_PATH/kworkflow-default.config
  fi

  while read line
  do
    if echo $line | grep -F = &>/dev/null
    then
      varname=$(echo $line | cut -d '=' -f 1 | tr -d '[:space:]')
      configurations[$varname]=$(echo "$line" | cut -d '=' -f 2-)
    fi
  done < $config_path 

  local connect="--connect=${configurations[virt_driver]}"

  export VIRT_INSTALL="virt-install $connect"
  export VIRT_VIEWER="virt-viewer $connect"
  export VIRT_NET_DEFINE="virsh $connect net-define"
  export VIRT_NET_START="virsh $connect net-start"
  export VIRT_NET_DESTROY="virsh $connect net-destroy"
  export VIRT_NET_UNDEFINE="virsh $connect net-undefine"
  export VIRT_NET_LIST="virsh $connect net-list --all"
  export VIRT_START="virsh $connect start"
  export VIRT_DESTROY="virsh $connect destroy"
  export VIRT_SHUTDOWN="virsh $connect shutdown"
  export VIRT_UNDEFINE="virsh $connect undefine"
  export VIRT_LIST="virsh $connect list --all"

}
