include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"

# these should be the default names for config files
CONFIG_FILENAME='kworkflow.config'
BUILD_CONFIG_FILENAME='build.config'
DEPLOY_CONFIG_FILENAME='deploy.config'
MAIL_CONFIG_FILENAME='mail.config'
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

# Deploy configuration
declare -gA deploy_config

# Mail configuration
declare -gA mail_config

# Notification configuration
declare -gA notification_config

# Default target option from kworkflow.config
declare -gA deploy_target_opt=(['local']=2 ['remote']=3)

# This function is used to show the current set up used by kworkflow.
function show_variables_main()
{
  local test_mode=0
  local has_local_config='No'

  load_all_config

  if [[ "$1" =~ ^-h|^--help ]]; then
    vars_help "$@"
    exit 0
  fi

  # TODO: Drop [[ -f "$PWD/$CONFIG_FILENAME" ]] in the future
  if [[ -f "${PWD}/${KW_DIR}/${CONFIG_FILENAME}" || -f "${PWD}/${CONFIG_FILENAME}" ]]; then
    has_local_config='Yes'
  fi

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
    [notification]='Notification options'
    [misc]='Miscellaneous options'
  )

  groups=(
    'deploy'
    'mail'
    'ssh'
    'notification'
    'misc'
    'build'
  )

  say 'kw configuration variables:'
  printf '%s\n' "  Local config file: $has_local_config"

  for group in "${groups[@]}"; do
    local -n descriptions="$group"
    case "$group" in
      'build')
        show_build_variables "$@"
        continue
        ;;
      'deploy')
        show_deploy_variables "$@"
        continue
        ;;
      'mail')
        show_mail_variables "$@"
        continue
        ;;
      'notification')
        show_notification_variables "$@"
        continue
        ;;
    esac

    printf '%s\n' "  ${group_descriptions["$group"]}:"
    print_array configurations descriptions "$test_mode"
  done
}

# This is a helper function that prints the option description followed by the
# option value.
#
# @config_array Array with values
# @option_description Array with the option description
# @test_mode only used for test
#
# Return:
# Print <option description> (option): value
function print_array()
{
  local -n config_array="$1"
  local -n option_description="$2"
  local test_mode="$3"

  for option in "${!option_description[@]}"; do
    if [[ -n ${config_array["$option"]} || "$test_mode" == 1 ]]; then
      printf '%s\n' "    ${option_description[$option]} ($option): ${config_array[$option]}"
    fi
  done
}

# This function is used to show the current set up used by kworkflow.
function show_build_variables()
{
  local test_mode=0
  local has_local_build_config='No'

  [[ -f "${PWD}/${KW_DIR}/${BUILD_CONFIG_FILENAME}" ]] && has_local_build_config='Yes'

  say 'kw build configuration variables:'
  printf '%s\n' "  Local build config file: $has_local_build_config"

  if [[ "$1" == 'TEST_MODE' ]]; then
    test_mode=1
  fi

  local -Ar build=(
    [arch]='Target arch'
    [cpu_scaling_factor]='CPU scaling factor'
    [enable_ccache]='Enable ccache'
    [use_llvm]='Use the LLVM toolchain'
    [warning_level]='Compilation warning level'
    [log_path]='Path kw should save the `make` output to'
    [kernel_img_name]='Kernel image name'
    [cross_compile]='Cross-compile name'
    [menu_config]='Kernel menu config'
    [doc_type]='Command to generate kernel-doc'
  )

  printf '%s\n' "  Kernel build options:"
  local -n descriptions="build"

  print_array build_config build
}

# This function is used to show the current set up used by kworkflow.
function show_deploy_variables()
{
  local test_mode=0
  local has_local_deploy_config='No'

  [[ -f "${PWD}/${KW_DIR}/${DEPLOY_CONFIG_FILENAME}" ]] && has_local_deploy_config='Yes'

  say 'kw deploy configuration variables:'
  printf '%s\n' "  Local deploy config file: $has_local_deploy_config"

  if [[ "$1" == 'TEST_MODE' ]]; then
    test_mode=1
  fi

  local -Ar deploy=(
    [default_deploy_target]='Deploy target'
    [reboot_after_deploy]='Reboot after deploy'
    [kw_files_remote_path]='kw files in the remote machine'
    [deploy_temporary_files_path]='Temporary files path used in the remote machine'
    [deploy_default_compression]='Default compression option used in the deploy'
    [dtb_copy_pattern]='How kw should copy dtb files to the boot folder'
    [strip_modules_debug_option]='Modules will be stripped after they are installed which will reduce the initramfs size'
  )

  printf '%s\n' "  Kernel deploy options:"
  local -n descriptions="deploy"
  print_array deploy_config deploy
}

function show_mail_variables()
{
  local test_mode=0
  local has_local_mail_config='No'

  [[ -f "${PWD}/${KW_DIR}/${MAIL_CONFIG_FILENAME}" ]] && has_local_mail_config='Yes'

  say 'kw Mail configuration variables:'
  printf '%s\n' "  Local Mail config file: $has_local_mail_config"

  if [[ "$1" == 'TEST_MODE' ]]; then
    test_mode=1
  fi

  local -Ar mail=(
    [send_opts]='Options to be used when sending a patch'
    [blocked_emails]='Blocked e-mail addresses'
  )

  printf '%s\n' "  kw mail options:"
  local -n descriptions="mail"
  print_array mail_config mail
}

function show_notification_variables()
{
  local test_mode=0
  local has_local_notification_config='No'

  [[ -f "${PWD}/${KW_DIR}/${BUILD_CONFIG_FILENAME}" ]] && has_local_notification_config='Yes'

  say 'kw notification configuration variables:'
  printf '%s\n' "  Local notification config file: $has_local_notification_config"

  if [[ "$1" == 'TEST_MODE' ]]; then
    test_mode=1
  fi

  local -Ar notification=(
    [alert]='Default alert options'
    [sound_alert_command]='Command for sound notification'
    [visual_alert_command]='Command for visual notification'
  )

  printf '%s\n' "  Kernel notification options:"
  local -n descriptions="notification"

  print_array notification_config notification
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
  local target_config="$1"
  local target_config_file
  local target_array='configurations'
  local -a config_dirs
  local config_dirs_size
  local IFS=:
  read -ra config_dirs <<< "${XDG_CONFIG_DIRS:-"/etc/xdg"}"
  unset IFS

  case "$target_config" in
    'build')
      target_array='build_config'
      ;;
    'deploy')
      target_array='deploy_config'
      ;;
    'mail')
      target_array='mail_config'
      ;;
    'notification')
      target_array='notification_config'
      ;;
  esac

  target_config_file="${target_config}.config"
  parse_configuration "${KW_ETC_DIR}/${target_config_file}" "$target_array"

  # XDG_CONFIG_DIRS is a colon-separated list of directories for config
  # files to be searched, in order of preference. Since this function
  # reads config files in a reversed order of preference, we must
  # traverse it from back to top. Example: if
  # XDG_CONFIG_DIRS=/etc/xdg:/home/user/myconfig:/etc/myconfig
  # we will want to parse /etc/myconfig, then /home/user/myconfig, then
  # /etc/xdg.
  config_dirs_size="${#config_dirs[@]}"
  for ((i = config_dirs_size - 1; i >= 0; i--)); do
    parse_configuration "${config_dirs["$i"]}/${KWORKFLOW}/${target_config_file}" "$target_array"
  done

  parse_configuration "${XDG_CONFIG_HOME:-"${HOME}/.config"}/${KWORKFLOW}/${target_config_file}" "$target_array"

  # Old users may have kworkflow.config at $PWD
  if [[ -f "$PWD/$CONFIG_FILENAME" ]]; then
    warning 'We will stop supporting kworkflow.config in the kernel root directory in favor of using a .kw/ directory.'
    if is_kernel_root "$PWD" &&
      [[ $(ask_yN 'Do you want to migrate to the new configuration file approach? (Recommended)') =~ 1 ]]; then
      mkdir -p "$PWD/$KW_DIR/"
      mv "$PWD/$CONFIG_FILENAME" "$PWD/$KW_DIR/$CONFIG_FILENAME"
    else
      parse_configuration "${PWD}/${CONFIG_FILENAME}" "$target_array"
    fi
  fi

  if [[ -f "${PWD}/${KW_DIR}/${target_config_file}" ]]; then
    parse_configuration "${PWD}/${KW_DIR}/${target_config_file}" "$target_array"
  fi
}

load_build_config()
{
  load_configuration 'build'
}

load_deploy_config()
{
  load_configuration 'deploy'
}

load_mail_config()
{
  load_configuration 'mail'
}

load_kworkflow_config()
{
  load_configuration 'kworkflow'
}

load_notification_config()
{
  load_configuration 'notification'
}

load_all_config()
{
  load_notification_config
  load_kworkflow_config
  load_deploy_config
  load_build_config
  load_mail_config
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
