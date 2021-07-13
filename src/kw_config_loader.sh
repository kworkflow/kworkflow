include "$KW_LIB_DIR/kwio.sh"

CONFIG_FILENAME=kworkflow.config

# Basic targets
VM_TARGET=1
LOCAL_TARGET=2
REMOTE_TARGET=3

# VM should be the default
TARGET="$VM_TARGET"

# Default configuration
declare -gA configurations

# Default target option from kworkflow.config
declare -gA deploy_target_opt=(['vm']=1 ['local']=2 ['remote']=3)

# This function is used to show the current set up used by kworkflow.
function show_variables()
{
  local test_mode=0
  local has_local_config_path="No"

  if [ -f "$PWD/kworkflow.config" ]; then
    has_local_config_path="Yes"
  else
    has_local_config_path="No"
  fi

  if [[ "$1" == 'TEST_MODE' ]]; then
    test_mode='1'
  fi

  local -Ar ssh=(
    [ssh_user]='SSH user'
    [ssh_ip]='SSH address'
    [ssh_port]='SSH port'
    [ssh_configfile]='SSH configuration file'
    [hostname]='Hostname of the target in the SSH configuration file'
  )

  local -Ar build=(
    [mount_point]='Mount point'
    [arch]='Target arch'
    [kernel_img_name]='Kernel image name'
    [cross_compile]='Cross-compile name'
    [menu_config]='Kernel menu config'
    [doc_type]='Command to generate kernel-doc'
  )

  local -Ar qemu=(
    [virtualizer]='Virtualisation tool'
    [qemu_hw_options]='QEMU hardware setup'
    [qemu_net_options]='QEMU Net options'
    [qemu_path_image]='Path for QEMU image'
  )

  local -Ar notification=(
    [alert]='Default alert options'
    [sound_alert_command]='Command for sound notification'
    [visual_alert_command]='Command for visual notification'
  )

  local -Ar deploy=(
    [default_deploy_target]='Deploy target'
    [reboot_after_deploy]='Reboot after deploy'
  )

  local -Ar misc=(
    [disable_statistics_data_track]='Disable tracking of statistical data'
    [gui_on]='Command to activate GUI'
    [gui_off]='Command to deactivate GUI'
  )

  local -Ar group_descriptions=(
    [build]='Kernel build options'
    [deploy]='kernel deploy options'
    [ssh]='SSH options'
    [qemu]='QEMU options'
    [notification]='Notification options'
    [misc]='Miscellaneous options'
  )

  say "kw configuration variables:"
  echo -e "  Local config file: $has_local_config_path"

  for group in 'build' 'deploy' 'qemu' 'ssh' 'notification' 'misc'; do
    echo "  ${group_descriptions["$group"]}:"
    local -n descriptions="$group"

    for option in "${!descriptions[@]}"; do
      if [[ -v configurations["$option"] || "$test_mode" == '1' ]]; then
        echo "    ${descriptions[$option]} ($option): ${configurations[$option]}"
      fi
    done
  done
}

# This function read the configuration file and make the parser of the data on
# it. For more information about the configuration file, take a look at
# "etc/kworkflow.config" in the kworkflow directory.
# @parameter: This function expects a path to the configuration file.
function parse_configuration()
{
  local config_path="$1"

  if [ ! -f "$config_path" ]; then
    return 22 # 22 means Invalid argument - EINVAL
  fi
  # shellcheck disable=SC2162
  while read line; do
    # Line started with # should be ignored
    [[ "$line" =~ ^# ]] && continue

    if echo "$line" | grep -F = &> /dev/null; then
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
  parse_configuration "$KW_ETC_DIR/$CONFIG_FILENAME"
  parse_configuration "$HOME/.kw/$CONFIG_FILENAME"
  parse_configuration "$PWD/$CONFIG_FILENAME"
}

# Every time that "kw_config_loader.sh" is included, the configuration file has
# to be loaded
load_configuration
