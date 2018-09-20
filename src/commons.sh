. $src_script_path/cfg.sh --source-only
. $src_script_path/miscellaneous.sh --source-only

KWORKFLOW_CONFIG_PATH=$PWD/kworkflow.config
KWORKFLOW_CONFIG_DEFAULT="$HOME/.config/kw/kworkflow.config"

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
  else
    say "kw found a kworkflow.conf file. Read options:"
  fi
  echo -en "\tQEMU OPTIONS: ${configurations[qemu_hw_options]}"
  echo     "${configurations[qemu_net_options]}"
  echo -e "\tVDISK: ${configurations[qemu_path_image]}"
  echo -e "\tDEPLOY TARGET: ${configurations[deploy_target]}"
}

function check_local_configuration()
{
  local result=0
  # File does not exist, use default configuration
  if [ ! -f "$CONFIG_PATH" ]; then
    CONFIG_PATH=$KWORKFLOW_CONFIG_DEFAULT
    result=1
  fi

  while read line
  do
    if echo $line | grep -F = &>/dev/null
    then
      varname=$(echo $line | cut -d '=' -f 1 | tr -d '[:space:]')
      configurations[$varname]=$(echo "$line" | cut -d '=' -f 2-)
    fi
  done < $CONFIG_PATH
  return $result
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

function set_configuration_variable()
{
  local file=$KWORKFLOW_CONFIG_DEFAULT
  sed -i "s/$1=\w*/$1=$2/g" "$file"
}
