. $src_script_path/cfg.sh --source-only
. $src_script_path/miscellaneous.sh --source-only

KWORKFLOW_CONFIG_PATH=$PWD/kworkflow.config
KWORKFLOW_CONFIG_DEFAULT_PATH="$HOME/.config/kw/etc/kworkflow.config"

# Default configuration
declare -A configurations=( )

function get_deploy_target()
{
  check_local_configuration
  TARGET=${configurations[deploy_target]}
  while getopts 'hg' c
  do
    case $c in
      h) TARGET="host" ;;
      g) TARGET="guest" ;;
    esac
  done
  echo $TARGET
} 

function show_variables()
{
  check_local_configuration

  say "Global values:"

  echo -e "\tBASE: ${configurations[base]}"
  echo -e "\tBUILD_DIR: ${configurations[build_dir]}"
  echo -e "\tQEMU ARCH: ${configurations[qemu_arch]}"
  echo -e "\tQEMU COMMAND: ${configurations[qemu]}"
  echo -e "\tQEMU MOUNT POINT: ${configurations[qemu_mnt]}"

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
  load_configuration $KWORKFLOW_CONFIG_DEFAULT_PATH
  local result=1

  # Check if local config exist and use it
  if [ -f "$CONFIG_PATH" ]; then
    load_configuration $KWORKFLOW_CONFIG_PATH
    result=0
  fi
  return $result
}

function load_configuration()
{
  while read line
  do
    if echo $line | grep -F = &>/dev/null
    then
      varname=$(echo $line | cut -d '=' -f 1 | tr -d '[:space:]')
      configurations[$varname]=$(echo "$line" | cut -d '=' -f 2-)
    fi
  done < $1
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
  cfg_write $KWORKFLOW_CONFIG_DEFAULT_PATH $1 $2
}
