include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

# these should be the default names for config files
CONFIG_FILENAME='kworkflow.config'
BUILD_CONFIG_FILENAME='build.config'
DEPLOY_CONFIG_FILENAME='deploy.config'
VM_CONFIG_FILENAME='vm.config'
MAIL_CONFIG_FILENAME='mail.config'
MAIL_CONFIG_FILENAME='lore.config'
KW_DIR='.kw'

# Basic targets
VM_TARGET=1
LOCAL_TARGET=2
REMOTE_TARGET=3

# VM should be the default
TARGET="$VM_TARGET"

# Default configuration
declare -gA configurations
declare -gA configurations_global
declare -gA configurations_local

# Build configuration
declare -gA build_config
declare -gA build_config_global
declare -gA build_config_local

# Deploy configuration
declare -gA deploy_config
declare -gA deploy_config_global
declare -gA deploy_config_local

# VM configuration
declare -gA vm_config
declare -gA vm_config_global
declare -gA vm_config_local

# Mail configuration
declare -gA mail_config
declare -gA mail_config_global
declare -gA mail_config_local

# Notification configuration
declare -gA notification_config
declare -gA notification_config_global
declare -gA notification_config_local

# Notification configuration
declare -gA lore_config
declare -gA lore_config_global
declare -gA lore_config_local

# Default target option from kworkflow.config
declare -gA deploy_target_opt=(['local']=2 ['remote']=3)

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
    [cflags]='Specify compilation flags'
  )

  printf '%s\n' '  Kernel build options:'
  local -n descriptions='build'

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
    [old_kernel_backup]='Backup the previous kernel if the current kernel to be deployed has the same name'
    [strip_modules_debug_option]='Modules will be stripped after they are installed which will reduce the initramfs size'
  )

  printf '%s\n' '  Kernel deploy options:'
  local -n descriptions='deploy'
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
    [default_to_recipients]='E-mail addresses to always be included as To: recipients'
    [default_cc_recipients]='E-mail addresses to always be included as CC: recipients'
  )

  printf '%s\n' '  kw mail options:'
  local -n descriptions='mail'
  print_array mail_config mail
}

function show_vm_variables()
{
  local test_mode=0
  local has_local_vm_config='No'

  [[ -f "${PWD}/${KW_DIR}/${VM_CONFIG_FILENAME}" ]] && has_local_vm_config='Yes'

  say 'kw VM configuration variables:'
  printf '%s\n' "  Local VM config file: $has_local_vm_config"

  if [[ "$1" == 'TEST_MODE' ]]; then
    test_mode=1
  fi

  local -Ar vm=(
    [virtualizer]='Virtualisation tool'
    [qemu_hw_options]='QEMU hardware setup'
    [qemu_net_options]='QEMU Net options'
    [qemu_path_image]='Path for QEMU image'
    [mount_point]='VM mount point'
  )

  printf '%s\n' '  Kernel vm options:'
  local -n descriptions='vm'
  print_array vm_config vm
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

  printf '%s\n' '  Kernel notification options:'
  local -n descriptions='notification'

  print_array notification_config notification
}

function show_lore_variables()
{
  local test_mode=0
  local has_local_lore_config='No'

  [[ -f "${PWD}/${KW_DIR}/${BUILD_CONFIG_FILENAME}" ]] && has_local_lore_config='Yes'

  say 'kw lore configuration variables:'
  printf '%s\n' "  Local notification config file: $has_local_lore_config"

  if [[ "$1" == 'TEST_MODE' ]]; then
    test_mode=1
  fi

  local -Ar lore=(
    [lists]='List that you want to follow'
  )

  printf '%s\n' '  Kernel upstream Lore options:'
  local -n descriptions='lore'

  print_array lore_config lore
}

# This function read the configuration file and make the parser of the data on
# it. For more information about the configuration file, take a look at
# "etc/kworkflow.config" in the kworkflow directory.
# @parameter: This function expects a path to the configuration file.
function parse_configuration()
{
  local config_path="$1"
  local config_array="${2:-configurations}"
  local config_array_scope="$3"
  local value

  if [ ! -f "$config_path" ]; then
    return 22 # 22 means Invalid argument - EINVAL
  fi

  # The `read` command will read all the characters untill it  finds  a  newline
  # character and then write those characters onto the given variable  (in  this
  # case, the `line` variable). If it does not find a newline `\n` character, it
  # will exit with status code 1. This  evaluates  to  false,  which  means  the
  # shellscript exits the loop. Therefore, if the last line  is  not  empty  but
  # misses the newline character, the loop won't be  run  and  the  last  config
  # option won't be read. We handle this edge case by checking if  line  is  not
  # empty and proceeding to run the loop once more if necessary.
  #
  # shellcheck disable=SC2162
  while read line || [[ -n "$line" ]]; do
    # Line started with # or that are blank should be ignored
    [[ "$line" =~ ^# || "$line" =~ ^$ ]] && continue

    if grep -qF = <<< "$line"; then
      varname="$(cut -d '=' -f 1 <<< "$line" | tr -d '[:space:]')"
      value="$(cut -d '=' -f 2- <<< "${line%#*}")"
      value="$(sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' <<< "$value")"

      eval "${config_array}"'["$varname"]="$value"'
      if [[ -n "${config_array_scope}" ]]; then
        eval "${config_array_scope}"'["$varname"]="$value"'
      fi
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
  local target_array_global=''
  local target_array_local=''
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
    'vm')
      target_array='vm_config'
      ;;
    'lore')
      target_array='lore_config'
      ;;
  esac

  target_array_global="${target_array}_global"
  target_array_local="${target_array}_local"

  target_config_file="${target_config}.config"
  parse_configuration "${KW_ETC_DIR}/${target_config_file}" "$target_array" "$target_array_global"

  # XDG_CONFIG_DIRS is a colon-separated list of directories for config
  # files to be searched, in order of preference. Since this function
  # reads config files in a reversed order of preference, we must
  # traverse it from back to top. Example: if
  # XDG_CONFIG_DIRS=/etc/xdg:/home/user/myconfig:/etc/myconfig
  # we will want to parse /etc/myconfig, then /home/user/myconfig, then
  # /etc/xdg.
  config_dirs_size="${#config_dirs[@]}"
  for ((i = config_dirs_size - 1; i >= 0; i--)); do
    parse_configuration "${config_dirs["$i"]}/${KWORKFLOW}/${target_config_file}" "$target_array" "$target_array_global"
  done

  parse_configuration "${XDG_CONFIG_HOME:-"${HOME}/.config"}/${KWORKFLOW}/${target_config_file}" "$target_array" "$target_array_global"

  # Old users may have kworkflow.config at $PWD
  if [[ -f "$PWD/$CONFIG_FILENAME" ]]; then
    warning 'We will stop supporting kworkflow.config in the kernel root directory in favor of using a .kw/ directory.'
    if is_kernel_root "$PWD" &&
      [[ $(ask_yN 'Do you want to migrate to the new configuration file approach? (Recommended)') =~ 1 ]]; then
      mkdir -p "$PWD/$KW_DIR/"
      mv "$PWD/$CONFIG_FILENAME" "$PWD/$KW_DIR/$CONFIG_FILENAME"
    else
      parse_configuration "${PWD}/${CONFIG_FILENAME}" "$target_array" "$target_array_local"
    fi
  fi

  if [[ -f "${PWD}/${KW_DIR}/${target_config_file}" ]]; then
    parse_configuration "${PWD}/${KW_DIR}/${target_config_file}" "$target_array" "$target_array_local"
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

load_vm_config()
{
  load_configuration 'vm'
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

load_lore_config()
{
  load_configuration 'lore'
}

load_all_config()
{
  load_notification_config
  load_kworkflow_config
  load_deploy_config
  load_build_config
  load_mail_config
  load_lore_config
  load_vm_config
}
