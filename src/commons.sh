. $src_script_path/cfg.sfh --source-only
. $src_script_path/miscellaneous.sh --source-only

KWORKFLOW_CONFIG_PATH=$PWD/kworkflow.config

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
DEFAULT_DEPLOY_TARGET="guest"

TARGET="qemu"

BASHPATH=/bin/bash

# Default configuration
declare -A configurations=( ["ip"]="127.0.0.1" ["port"]="2222" )

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
    echo -e "\tDEPLOY TARGET: $DEFAULT_DEPLOY_TARGET"
  else
    say "kw found a kworkflow.conf file. Read options:"
    echo -en "\tQEMU OPTIONS: ${configurations[qemu_hw_options]}"
    echo     "${configurations[qemu_net_options]}"
    echo -e "\tVDISK: ${configurations[qemu_path_image]}"
    echo -e "\tDEPLOY TARGET: ${configurations[deploy_target]}"
  fi
}

function check_local_configuration()
{
  # File does not exist, use default configuration
  if [ ! -f $KWORKFLOW_CONFIG_PATH ] ; then
    configurations=(
      [qemu_path_image]=$VDISK
      [qemu_hw_options]=$QEMU_OPT
      [qemu_net_options]=""
      [port]=$DEFAULT_PORT
      [ip]=$DEFAULT_IP
      [deploy_target]=$DEFAULT_DEPLOY_TARGET
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

function set_deploy_target()
{
  # Check if value is acceptable
  if [ "$1" != "host" ] && [ "$1" != "guest" ]; then
    complain "Invalid deploy target"
    return
  fi

  # Set file and loaded configurations
  set_configuration_variable "deploy_target" "$1"
  configurations[deploy_target]=$1
}
