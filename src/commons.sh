. $src_script_path/miscellaneous.sh --source-only

QEMU_OPTS="-enable-kvm -smp 2 -m 1024"

CFG_PATH="$HOME/.config/$EASY_KERNEL_WORKFLOW"

# If configurations is not set, retrieve from either local or default config.
if [ -z ${configurations+x} ]; then
  declare -A configurations=()
  check_local_configuration
fi

function show_variables
{
  check_local_configuration

  say "Global variables"

  echo -e "\tMOUNT_POINT: ${configurations[mount_point]}"
  echo -e "\tBASE: ${configurations[base]}"
  echo -e "\tBUILD_DIR: ${configurations[build_dir]}"
  echo -e "\tQEMU ARCH: ${configurations[qemu_arch]}"
  echo -e "\tQEMU COMMAND: ${configurations[qemu]}"
  echo -e "\tQEMU MOUNT POINT: ${configurations[qemu_mnt]}"
  echo -e "\tPORT: ${configurations[port]}"
  echo -e "\tIP: ${configurations[ip]}"
  echo -e "\tBASHPATH: ${configurations[bashpath]}"
  echo -e "\tTARGET: ${configurations[target]}"

  # Set as global variables for other modules.
  MOUNT_POINT=${configurations[mount_point]}
  BASE=${configurations[base]}
  BUILD_DIR=${configurations[build_dir]}
  QEMU=${configurations[qemu]}
  VDISK=${configurations[qemu_path_image]}
  QEMU_MNT=${configurations[qemu_mnt]}

  if [ $? -eq 1 ] ; then
    say "There is no kworkflow.conf, adopt default values for:"
    echo -e "\tQEMU OPTIONS: ${configurations[qemu_hw_options]}"
    echo -e "\tVDISK: ${configurations[qemu_path_image]}"
  else
    say "kw found a kworkflow.conf file. Read options:"
    echo -en "\tQEMU OPTIONS: ${configurations[qemu_hw_options]}"
    echo     "${configurations[qemu_net_options]}"
    echo -e "\tVDISK: ${configurations[qemu_path_image]}"
  fi
}

function read_config
{
  local config_path=$1
  while read line; do
    if echo $line | grep -F = &>/dev/null; then
      varname=$(echo $line | cut -d '=' -f 1 | tr -d '[:space:]')
      value=$(echo "$line" | cut -d '=' -f 2-)
      vars=$(echo "$value" | grep -o -P '\$\{*[a-zA-Z0-9_]*\}*')
      if [ ! -z "$vars" ]; then
        for v in "${vars[@]}"; do
          if [ "$v" != '$HOME' ]; then
            u=$(echo "$v" | grep -o -P '[a-zA-Z0-9_]*')
            value="${value//$v/${configurations[$u]}}"
          fi
        done
      fi
      configurations[$varname]=$value
    fi
  done < $config_path
}

function check_local_configuration()
{
  local config_path=$PWD/kworkflow.config

  # Retrieve default values.
  read_config $CFG_PATH/kworkflow.config.example
  # File does not exist, use default configuration and warn through exit code.
  if [ ! -f $config_path ] ; then
    return 1
  fi
  # Set custom values.
  read_config $config_path
}
