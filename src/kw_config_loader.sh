include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"

# these should be the default names for config files
CONFIG_FILENAME='kworkflow.config'
BUILD_CONFIG_FILENAME='build.config'
KW_DIR='.kw'

# Basic targets
VM_TARGET=1
LOCAL_TARGET=2
REMOTE_TARGET=3

# VM should be the default
TARGET="$VM_TARGET"

# Default configuration
declare -gA configurations

# Build configuration
declare -gA build_config

# Default target option from kworkflow.config
declare -gA deploy_target_opt=(['vm']=1 ['local']=2 ['remote']=3)

# This function is used to show the current set up used by kworkflow.
function show_variables()
{
  local test_mode=0
  local has_local_config='No'
  local has_local_build_config='No'
  local show_build=false

  if [[ "$#" -gt 1 ]]; then
    if [[ "$1" =~ -h|--help ]]; then
      vars_help "$1"
      exit 0
    elif [[ "$1" =~ -b|--build ]]; then
      show_build=true
    fi
  fi

  # TODO: Drop [[ -f "$PWD/$CONFIG_FILENAME" ]] in the future
  if [[ -f "$PWD/$KW_DIR/$CONFIG_FILENAME" || -f "$PWD/$CONFIG_FILENAME" ]]; then
    has_local_config='Yes'
  fi

  [[ "$show_build" = true && -f "${PWD}/${KW_DIR}/${BUILD_CONFIG_FILENAME}" ]] && has_local_build_config='Yes'

  if [[ "$1" == 'TEST_MODE' ]]; then
    test_mode=1
  fi

  local -Ar ssh=(
    [ssh_user]='SSH user'
    [ssh_ip]='SSH address'
    [ssh_port]='SSH port'
    [ssh_configfile]='SSH configuration file'
    [hostname]='Hostname of the target in the SSH configuration file'
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
    [kw_files_remote_path]='kw files in the remote machine'
    [deploy_temporary_files_path]='Temporary files path used in the remote machine'
    [deploy_default_compression]='Default compression option used in the deploy'
    [dtb_copy_pattern]='How kw should copy dtb files to the boot folder'
    [strip_modules_debug_option]='Modules will be stripped after they are installed which will reduce the initramfs size'
    [mount_point]='VM mount point'
  )

  local -Ar build=(
    [arch]='Target arch'
    [kernel_img_name]='Kernel image name'
    [cross_compile]='Cross-compile name'
    [menu_config]='Kernel menu config'
    [doc_type]='Command to generate kernel-doc'
  )

  local -Ar mail=(
    [send_opts]='Options to be used when sending a patch'
    [blocked_emails]='Blocked e-mail addresses'
  )

  local -Ar misc=(
    [disable_statistics_data_track]='Disable tracking of statistical data'
    [gui_on]='Command to activate GUI'
    [gui_off]='Command to deactivate GUI'
    [checkpatch_opts]='Options to be used in the checkpatch script'
    [get_maintainer_opts]='Options to be used in the get_maintainer script'
  )

  local -Ar group_descriptions=(
    [build]='Kernel build options'
    [deploy]='Kernel deploy options'
    [mail]='Send-email options'
    [ssh]='SSH options'
    [qemu]='QEMU options'
    [notification]='Notification options'
    [misc]='Miscellaneous options'
  )

  groups=(
    'deploy'
    'mail'
    'ssh'
    'qemu'
    'notification'
    'misc'
  )

  say 'kw configuration variables:'
  printf '%s\n' "  Local config file: $has_local_config"

  if [[ "$show_build" = true ]]; then
    groups+=('build')
    printf '%s\n' "  Local build config file: $has_build_local_config"
  fi

  for group in "${groups[@]}"; do
    printf '%s\n' "  ${group_descriptions["$group"]}:"
    local -n descriptions="$group"

    if [[ "$group" = 'build' ]]; then
      local -n config_array=build_config
    else
      local -n config_array=configurations
    fi

    for option in "${!descriptions[@]}"; do
      setting="${config_array[$option]}"
      echo "$setting"
      if [[ -n "$setting" || "$test_mode" == 1 ]]; then
        printf '%s\n' "    ${descriptions[$option]} ($option): $setting"
      fi
    done
  done
}

function vars_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'vars'
    return
  fi
  printf '%s\n' 'kw vars:' \
    '  vars - Show current variable values being used by kw.'
}

# This function read the configuration file and make the parser of the data on
# it. For more information about the configuration file, take a look at
# "etc/kworkflow.config" in the kworkflow directory.
# @parameter: This function expects a path to the configuration file.
function parse_configuration()
{
  local config_path="$1"
  local config_array="${2:-configurations}"
  local value

  if [ ! -f "$config_path" ]; then
    return 22 # 22 means Invalid argument - EINVAL
  fi
  # shellcheck disable=SC2162
  while read line; do
    # Line started with # or that are blank should be ignored
    [[ "$line" =~ ^# || "$line" =~ ^$ ]] && continue

    if grep -qF = <<< "$line"; then
      varname="$(cut -d '=' -f 1 <<< "$line" | tr -d '[:space:]')"
      value="$(cut -d '=' -f 2- <<< "${line%#*}")"
      value="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$value")"

      eval "${config_array}"'["$varname"]="$value"'
    fi
  done < "$config_path"
}

# This function loads the kw configuration files into memory, populating the
# $configurations hashtable. The files are parsed in a specific order, allowing
# higher level setting definitions to overwrite lower level ones.
function load_configuration()
{
  local -a config_dirs
  local config_dirs_size
  local IFS=:
  read -ra config_dirs <<< "${XDG_CONFIG_DIRS:-"/etc/xdg"}"
  unset IFS

  parse_configuration "$KW_ETC_DIR/$CONFIG_FILENAME"

  # XDG_CONFIG_DIRS is a colon-separated list of directories for config
  # files to be searched, in order of preference. Since this function
  # reads config files in a reversed order of preference, we must
  # traverse it from back to top. Example: if
  # XDG_CONFIG_DIRS=/etc/xdg:/home/user/myconfig:/etc/myconfig
  # we will want to parse /etc/myconfig, then /home/user/myconfig, then
  # /etc/xdg.
  config_dirs_size="${#config_dirs[@]}"
  for ((i = config_dirs_size - 1; i >= 0; i--)); do
    parse_configuration "${config_dirs["$i"]}/$KWORKFLOW/$CONFIG_FILENAME"
  done

  parse_configuration "${XDG_CONFIG_HOME:-"$HOME/.config"}/$KWORKFLOW/$CONFIG_FILENAME"

  # Old users may have kworkflow.config at $PWD
  if [[ -f "$PWD/$CONFIG_FILENAME" ]]; then
    warning 'We will stop supporting kworkflow.config in the kernel root directory in favor of using a .kw/ directory.'
    if is_kernel_root "$PWD" &&
      [[ $(ask_yN 'Do you want to migrate to the new configuration file approach? (Recommended)') =~ 1 ]]; then
      mkdir -p "$PWD/$KW_DIR/"
      mv "$PWD/$CONFIG_FILENAME" "$PWD/$KW_DIR/$CONFIG_FILENAME"
    else
      parse_configuration "$PWD/$CONFIG_FILENAME"
    fi
  fi

  if [[ -f "$PWD/$KW_DIR/$CONFIG_FILENAME" ]]; then
    parse_configuration "$PWD/$KW_DIR/$CONFIG_FILENAME"
  fi
}

# Every time that "kw_config_loader.sh" is included, the configuration file has
# to be loaded
load_configuration
