. $src_script_path/kwio.sh --source-only

BASE="$HOME/p/linux-trees"
BUILD_DIR="$BASE/build-linux"

CONFIG_FILENAME=kworkflow.config

# Basic targets
VM_TARGET=1
LOCAL_TARGET=2
REMOTE_TARGET=3

# VM should be the default
TARGET="$VM_TARGET"

# Default configuration
declare -A configurations

# This function is used to show the current set up used by kworkflow.
function show_variables()
{
  local has_local_config_path="No"

  if [ -f "$PWD/kworkflow.config" ] ; then
    has_local_config_path="Yes"
  else
    has_local_config_path="No"
  fi

  say "Variables:"
  echo -e "\tLocal config file: $has_local_config_path"
  echo -e "\tTarget arch: ${configurations[arch]}"
  echo -e "\tMount point: ${configurations[mount_point]}"
  echo -e "\tVirtualization tool: ${configurations[virtualizer]}"
  echo -e "\tQEMU options: ${configurations[qemu_hw_options]}"
  echo -e "\tQEMU Net options: ${configurations[qemu_net_options]}"
  echo -e "\tVdisk: ${configurations[qemu_path_image]}"
}

# This function read the configuration file and make the parser of the data on
# it. For more information about the configuration file, take a look at
# "etc/kworkflow.config" in the kworkflow directory.
# @parameter: This function expects a path to the configuration file.
function parse_configuration()
{
  local config_path="$1"
  local filename="$(basename "$config_path")"

  if [ ! -f "$config_path" ] || [ "$filename" != kworkflow.config ] ; then
    return 22 # 22 means Invalid argument - EINVAL
  fi

  while read line
  do
    if echo "$line" | grep -F = &>/dev/null
    then
      varname="$(echo "$line" | cut -d '=' -f 1 | tr -d '[:space:]')"
      configurations["$varname"]="$(echo "$line" | cut -d '=' -f 2-)"
    fi
  done < "$config_path"
}

# This function loads the kw configuration files into memory, populating the
# $configurations hashtable. The files are parsed in a specific order, allowing
# higher level setting definitions to overwrite lower level ones.
function load_configuration()
{
  parse_configuration "$etc_files_path/$CONFIG_FILENAME"
  parse_configuration "$HOME/.kw/$CONFIG_FILENAME"
  parse_configuration "$PWD/$CONFIG_FILENAME"
}

# Every time that "kw_config_loader.sh" is included, the configuration file has
# to be loaded
load_configuration
