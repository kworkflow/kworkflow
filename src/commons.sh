. $src_script_path/miscellaneous.sh --source-only

BASE=$HOME/p/linux-trees
MOUNT_POINT=$HOME/p/mount
BUILD_DIR=$BASE/build-linux

QEMU_ARCH="x86_64"
QEMU="qemu-system-${QEMU_ARCH}"
QEMU_OPTS="-enable-kvm -smp 2 -m 1024"
VDISK="$HOME/p/virty.qcow2"
QEMU_MNT="/mnt/qemu"
DEFAULT_PORT="22"
DEFAULT_IP="192.168.122.2"
VIRT_INSTALL="virt-install"
VIRT_VIEWER="virt-viewer"
VIRT_NET_DEFINE="virsh net-create --file"
VIRT_NET_NAME="kworkflow-network"
VIRT_NET_START="virsh net-start"
VIRT_NET_DESTROY="virsh net-destroy"
VIRT_START="virsh start"
VIRT_DESTROY="virsh destroy"
VIRT_SHUTDOWN="virsh shutdown"
VIRT_VM_NAME="kworkflow-vm"

TARGET="qemu"

BASHPATH=/bin/bash

# Default configuration
declare -A configurations=( ["ip"]="$DEFAULT_IP" ["port"]="$DEFAULT_PORT" )

function show_variables()
{
  say "Global values:"

  echo -e "\tBASE: $BASE"
  echo -e "\tBUILD_DIR: $BUILD_DIR"
  echo -e "\tQEMU ARCH: $QEMU_ARCH"
  echo -e "\tQEMU COMMAND: $QEMU"
  echo -e "\tQEMU MOUNT POINT: $QEMU_MNT"
  echo -e "\tTARGET: $TARGET"

  check_local_configuration

  if [ $? -eq 1 ] ; then
    say "There is no kworkflow.conf, adopt default values for:"
    echo -e "\tQEMU OPTIONS: $QEMU_OPTS"
    echo -e "\tVDISK: $VDISK"
  else
    say "kw found a kworkflow.conf file. Read options:"
    echo -en "\tQEMU OPTIONS: ${configurations[qemu_hw_options]}"
    echo     "${configurations[qemu_net_options]}"
    echo -e "\tVDISK: ${configurations[qemu_path_image]}"
  fi
}

function check_local_configuration()
{
  local config_path=$PWD/kworkflow.config

  # File does not exist, use default configuration
  if [ ! -f $config_path ] ; then
    configurations=(
      [qemu_path_image]=$VDISK
      [qemu_hw_options]=$QEMU_OPT
      [qemu_net_options]=""
      [port]=$DEFAULT_PORT
      [ip]=$DEFAULT_IP
    )
    return 1
  fi

  while read line
  do
    if echo $line | grep -F = &>/dev/null
    then
      varname=$(echo $line | cut -d '=' -f 1 | tr -d '[:space:]')
      configurations[$varname]=$(echo "$line" | cut -d '=' -f 2-)
    fi
  done < $config_path
}
