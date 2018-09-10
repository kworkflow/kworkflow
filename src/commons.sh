BASE=$HOME/p/linux-trees
MOUNT_POINT=$HOME/p/mount
BUILD_DIR=$BASE/build-linux

QEMU_ARCH="x86_64"
QEMU="qemu-system-${QEMU_ARCH}"
QEMU_OPTS="-enable-kvm -smp 2 -m 1024"
VDISK="$HOME/p/virty.qcow2"
QEMU_MNT="/mnt/qemu"
DEFAULT_PORT="2222"
DEFAULT_IP="127.0.0.1"

TARGET="qemu"

BASHPATH=/bin/bash

# Default configuration
declare -A configurations=( ["ip"]="127.0.0.1" ["port"]="2222" )

function kw::show_variables()
{
  echo -e "\tBASE: $BASE"
  echo -e "\tBUILD_DIR: $BUILD_DIR"
  echo -e "\tQEMU ARCH: $QEMU_ARCH"
  echo -e "\tQEMU COMMAND: $QEMU"
  echo -e "\tQEMU OPTIONS: $QEMU_OPTS"
  echo -e "\tVDISK: $VDISK"
  echo -e "\tQEMU MOUNT POINT: $QEMU_MNT"
  echo -e "\tTARGET: $TARGET"
}

function kw::check_local_configuration()
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
