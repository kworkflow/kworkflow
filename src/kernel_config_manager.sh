include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kw_db.sh"
include "${KW_LIB_DIR}/lib/remote.sh"
include "${KW_LIB_DIR}/lib/signal_manager.sh"

declare -gA options_values
declare -g root='/'
declare -g PROC_CONFIG_PATH='/proc/config.gz'

# This function handles the options available in 'kernel-config-manager'.
#
# @* This parameter expects a list of parameters, such as '-n', '-d', and '-f'.
#
# Returns:
# Return 0 if everything ends well, otherwise return an errno code.
function kernel_config_manager_main()
{
  local name_config
  local description_config
  local force
  local flag
  local optimize
  local user
  local remote
  local ip
  local port
  local env_name

  flag=${flag:-'SILENT'}

  if [[ -z "$*" ]]; then
    list_configs "$flag"
    return "$?"
  fi

  if [[ "$1" =~ -h|--help ]]; then
    config_manager_help "$1"
    exit 0
  fi

  parse_kernel_config_manager_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    exit 22 # EINVAL
  fi

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  env_name=$(get_current_env_name)
  if [[ "$?" == 0 ]]; then
    options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']="${KW_CACHE_DIR}/${ENV_DIR}/${env_name}"
  fi

  name_config="${options_values['SAVE']}"
  description_config="${options_values['DESCRIPTION']}"
  force="${options_values['FORCE']}"
  optimize="${options_values['OPTIMIZE']}"

  if [[ -n "${options_values['SAVE']}" ]]; then
    save_config_file "$force" "$name_config" "$description_config" "$flag"
    return "$?"
  fi

  if [[ -n "${options_values['LIST']}" ]]; then
    list_configs "$flag"
    return "$?"
  fi

  if [[ -n "${options_values['GET']}" ]]; then
    get_config "${options_values['GET']}" "$force" "$flag"
    return "$?"
  fi

  if [[ -n "${options_values['REMOVE']}" ]]; then
    remove_config "${options_values['REMOVE']}" "$force" "$flag"
    return "$?"
  fi

  if [[ -n "${options_values['FETCH']}" ]]; then
    fetch_config "$flag" "$force" "${options_values['OUTPUT']}" "$optimize" "${options_values['TARGET']}"
    return "$?"
  fi
}

# This function handles the save operation of kernel's '.config' file. It first
# checks if the '.config' is registered in the database. If it isn't or if the user
# wants to overwrite the file, kw saves the '.config' file in 'KW_DATA_DIR/configs'
# and adds its metadata to the database.
#
# @force Force option. If it is set and the current name was already saved,
#        this option will override the '.config' file under the 'name'
#        specified by '-n' without any message.
# @config_name Name for identifying a target .config file. This name
#              represents the access key for .config.
# @description Description for a config file, de descrition from '-d' flag.
# @flag: Flag to control function output
#
# Return:
# Returns 0 if operation is successful or aborted (no overwrite) and 2 if
# kw can't find a .config file to save.
function save_config_file()
{
  local -r force="$1"
  local -r config_name="$2"
  local description="$3"
  local flag="${4:-SILENT}"
  local kernel_source_tree_path="$PWD"
  local -r kernel_configs_dir="${KW_DATA_DIR}/configs"
  local is_on_database=''
  local datetime
  local database_columns='("name","description","path","last_updated_datetime")'
  local -a values=()
  local rows
  local cmd
  local ret
  declare -A condition_array

  # Get env's kernel source tree
  if [[ -n "${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}" ]]; then
    kernel_source_tree_path="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  fi

  # Checks if there is a kernel config file named '.config' in the target dir
  if [[ ! -f "${kernel_source_tree_path}/.config" ]]; then
    complain "There is no kernel config file named '.config' in the directory ${kernel_source_tree_path}"
    return 2 # ENOENT
  fi

  [[ "$flag" == 'VERBOSE' ]] && flag='CMD_SUBSTITUTION_VERBOSE'

  # Checks if there is already an entry for that kernel config file in the database
  condition_array=(['name']="${config_name}")
  is_on_database="$(select_from 'kernel_config' '' 'condition_array' "$flag")"
  if [[ -n "${is_on_database}" && "$force" != 1 ]]; then
    warning "Kernel config file named '${config_name}' already exists."
    if [[ $(ask_yN "Do you want to overwrite it?") =~ '0' ]]; then
      say 'Save operation aborted'
      return 0
    fi
  fi

  # Create local dir for storing the kernel config files if it doesn't exists
  if [[ ! -d "${kernel_configs_dir}" ]]; then
    cmd="mkdir --parents ${kernel_configs_dir}"
    cmd_manager "$flag" "$cmd"
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      complain 'Could not create kernel configs directory'
      return "$ret"
    fi
  fi

  cmp --silent "${kernel_source_tree_path}/.config" "${kernel_configs_dir}/${config_name}"
  if [[ "$?" == 0 && "$force" != 1 ]]; then
    warning "'${config_name}' kernel config file stored in local filesystem is up to date"
    if [[ $(ask_yN "Do you want to continue?") =~ '0' ]]; then
      say 'Save operation aborted'
      return 0
    fi
  fi

  # Store kernel config file in local filesystem
  cmd="cp ${kernel_source_tree_path}/.config ${kernel_configs_dir}/${config_name}"
  cmd_manager "$flag" "$cmd"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain "Couldn't copy ${kernel_source_tree_path}/.config to ${kernel_configs_dir}/${config_name}"
    return "$ret"
  fi

  if [[ -z "$description" ]]; then
    description='NULL'
  fi

  # Add/Update kernel config entry in local database
  datetime=$(date '+%Y-%m-%d %H:%M:%S')
  values=("$config_name" "$description" "${kernel_configs_dir}/${config_name}" "$datetime")
  rows="$(format_values_db 4 "${values[@]}")"
  replace_into '"kernel_config"' "$database_columns" "$rows" '' "$flag"
  ret="$?"

  if [[ "$ret" -gt 0 ]]; then
    complain "Could not save user kernel config file"
    if is_safe_path_to_remove "${kernel_configs_dir}/${config_name}"; then
      cmd_manager "$flag" "rm ${kernel_configs_dir}/${config_name}"
    fi
  else
    success "Saved kernel config '${config_name}'"
  fi
}

# Clean-up for fetch_config. When running --fetch, some files may be
# overwritten. If the user decides to cancel the command, important
# configuration files may be gone. To overcome that, we run use cleanup, to both
# retrieve these files and remove the temporary ones left.
function cleanup()
{
  local flag=${1:-'SILENT'}
  say 'Cleaning up and retrieving files...'

  # Setting dotglob to include hidden files when running 'mv'
  shopt -s dotglob
  if [[ -d "${KW_CACHE_DIR}/config" ]]; then
    cmd_manager "$flag" "mv ${KW_CACHE_DIR}/config/* ${PWD}"
    cmd_manager "$flag" "rmdir ${KW_CACHE_DIR}/config"
  fi

  if [[ -f "${KW_CACHE_DIR}/lsmod" ]]; then
    cmd_manager "$flag" "rm ${KW_CACHE_DIR}/lsmod"
  fi

  say 'Exiting...'
  exit 0
}

# This function attempts to get the config file from /proc/config.gz. It first
# checks if this file is available and not empty; if this function cannot find
# /proc/config.gz, it will attempt to load the configs modules and try again.
# For the remote option, this function reads from remote_parameters directly.
#
# @flag How to display a command, the default value is "SILENT". For more
#   options see `src/lib/kwlib.sh` function `cmd_manager`.
# @output File name to save the config file.
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
#
# Return:
# In case of successful return 0, otherwise, return 95.
function get_config_from_proc()
{
  local flag="$1"
  local output="$2"
  local target="$3"
  local ret
  local -r CMD_LOAD_CONFIG_MODULE="modprobe -q configs && [ -s ${PROC_CONFIG_PATH} ]"
  local CMD_GET_CONFIG="zcat /proc/config.gz > ${output}"
  local config_base_path="$PWD"

  if [[ -n "${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}" ]]; then
    config_base_path="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  fi

  [[ "$target" == 3 ]] && CMD_GET_CONFIG="zcat /proc/config.gz > /tmp/${output}"

  case "$target" in
    1) # VM
      # We do not support this option with VM
      return 95 # ENOTSUP
      ;;
    2) # LOCAL
      # Try to find /proc/config, if we cannot find, attempt to load the module
      # and try it again. If we fail, give of of using /proc/config
      if [[ ! -f "$PROC_CONFIG_PATH" ]]; then
        cmd_manager "$flag" "sudo ${CMD_LOAD_CONFIG_MODULE}"
        [[ "$?" != 0 ]] && return 95 # Operation not supported
      fi

      cmd_manager "$flag" "$CMD_GET_CONFIG"
      return 0
      ;;
    3) # REMOTE
      cmd_remotely "$flag" "[ -f ${PROC_CONFIG_PATH} ]"
      if [[ "$?" != 0 ]]; then
        cmd_remotely "$flag" "$CMD_LOAD_CONFIG_MODULE"
        [[ "$?" != 0 ]] && return 95 # Operation not supported
      fi

      cmd_remotely "$flag" "$CMD_GET_CONFIG"
      [[ "$?" != 0 ]] && return 95 # Operation not supported
      remote2host "$flag" "/tmp/${output}" "$config_base_path"
      return 0
      ;;
  esac

  return 95 # ENOTSUP
}

# Usually, this function is used as the fallback from get_config_from_proc,
# which will try to retrieve the config file from the standard /boot folder.
#
# @flag How to display a command, the default value is "SILENT". For more
#   options see `src/lib/kwlib.sh` function `cmd_manager`.
# @output File name to save the config file.
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
#
# Return:
# In case of successful return 0, otherwise, return 95.
function get_config_from_boot()
{
  local flag="$1"
  local output="$2"
  local target="$3"
  local kernel_release
  local user="${remote_parameters['REMOTE_USER']}"
  local ip="${remote_parameters['REMOTE_IP']}"
  local port="${remote_parameters['REMOTE_PORT']}"
  local cmd
  local config_base_path="$PWD"

  if [[ -n "${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}" ]]; then
    config_base_path="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  fi

  case "$target" in
    1) # VM
      # TODO: We can support VM in this scenario
      return 95 # We do not support this option with VM
      ;;
    2) # LOCAL
      cmd="cp ${root}boot/config-$(uname -r) ${output} 2>/dev/null"
      cmd_manager "$flag" "$cmd"
      [[ "$?" != 0 ]] && return 95 # ENOTSUP
      return 0
      ;;
    3) # REMOTE
      kernel_release=$(cmd_remotely "$flag" 'uname -r')
      cmd_remotely "$flag" "[ -f ${root}boot/config-${kernel_release} ]"
      [[ "$?" != 0 ]] && return 95 # ENOTSUP

      remote2host "$flag" "${root}boot/config-${kernel_release}" "$config_base_path"
      return 0
      ;;
  esac

  return 95 # ENOTSUP
}

# Usually, this function is used as a final fallback to retrieve a config file.
# This function uses the default defconfig and the kw config files to generate
# the new config file.
#
# @flag How to display a command, the default value is "SILENT". For more
#   options see `src/lib/kwlib.sh` function `cmd_manager`.
# @output File name to save the config file.
#
# Return:
# In case of successful return 0, otherwise, return 125.
function get_config_from_defconfig()
{
  local flag="$1"
  local output="$2"
  local cross_compile
  local arch
  local ret
  local cmd='make defconfig'

  if ! is_kernel_root "$PWD"; then
    complain 'This command should be run in a kernel tree.'
    return 125 # ECANCELED
  fi

  cross_compile=${build_config[cross_compile]:-${configurations[cross_compile]}}
  arch=${build_config[arch]:-${configurations[arch]}}

  # Build command
  [[ -n "$arch" ]] && cmd+=" ARCH=${arch}"
  [[ -n "$cross_compile" ]] && cmd+=" CROSS_COMPILE=${cross_compile}"

  # If the --output option is passed, we don't want to override the current
  # config
  if [[ -f "${PWD}/.config" && "$output" != '.config' ]]; then
    cmd+=" && mv ${PWD}/.config ${output} && mv ${KW_CACHE_DIR}/config/.config ${PWD}/.config"
  fi

  cmd_manager "$flag" "$cmd"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    return "$ret"
  fi
}

# This function manages how kw retrieves and handle .config file. For trying to
# retrieve the config file, this function tries three different approaches:
#
# 1. /proc/config.gz
# 2. /boot/config-*
# 3. defconfig
#
# @flag How to display a command.
# @force Force option. If it's set, it will ignore the warning if there's
#        another .config file in the current directory and the file will be
#        overwritten.
# @output File name. This option requires an argument, which will be the name of
#         the .config file to be retrieved.
# @optimize Optimize flag, if set then 'make localmodconfig' is used.
# @target Target can be 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET).
function fetch_config()
{
  local flag="$1"
  local force="$2"
  local output="$3"
  local optimize="$4"
  local target="$5"
  local user="${remote_parameters['REMOTE_USER']}"
  local ip="${remote_parameters['REMOTE_IP']}"
  local port="${remote_parameters['REMOTE_PORT']}"
  local kernel_release
  local mods
  local cmd
  local arch
  local ret
  local config_base_path="$PWD"

  output=${output:-'.config'}
  flag=${flag:-'SILENT'}

  if [[ -n "${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}" ]]; then
    config_base_path="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
    output_kbuild_flag=" --silent O=${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  fi

  if [[ "$target" == "$REMOTE_TARGET" ]]; then
    # Check connection before try to work with remote
    is_ssh_connection_configured "$flag"
    if [[ "$?" != 0 ]]; then
      ssh_connection_failure_message
      exit 101 # ENETUNREACH
    fi
  fi

  # Folder to store files in case there's an interruption and we need to return
  # things to the state they were before or in case we need a place to store
  # files temporarily.
  cmd="mkdir -p ${KW_CACHE_DIR}/config"
  cmd_manager "$flag" "$cmd"

  if [[ -f "${config_base_path}/${output}" ]]; then
    if [[ -z "$force" && "$(ask_yN "Do you want to overwrite ${output} in your current directory?")" =~ '0' ]]; then
      warning 'Operation aborted'
      return 125 #ECANCELED
    fi

    cmd="cp ${config_base_path}/${output} ${KW_CACHE_DIR}/config"
    cmd_manager "$flag" "$cmd"
  fi

  # If --output is provided, we need to backup the current config file
  if [[ -f "${config_base_path}/.config" && "$output" != '.config' ]]; then
    cmd="cp ${config_base_path}/.config ${KW_CACHE_DIR}/config"
    cmd_manager "$flag" "$cmd"
  fi

  signal_manager 'cleanup' || warning 'Was not able to set signal handler'

  # 1. Try to get the info from /proc/config.gz
  get_config_from_proc "$flag" "$output" "$target"
  ret="$?"

  # 2. Try to get the info from /boot
  if [[ "$ret" != 0 ]]; then
    get_config_from_boot "$flag" "$output" "$target"
    ret="$?"
  fi

  # 3. Get the config from defconfig
  [[ "$ret" != 0 ]] && get_config_from_defconfig "$flag" "$output"
  [[ "$?" == 125 ]] && return 125 # ECANCELED

  # Let's ensure that we keep all of the options from the old .config and set
  # new options to their default values.
  cmd="make olddefconfig${output_kbuild_flag}"
  cmd_manager "$flag" "$cmd"

  if [[ -n "$optimize" ]]; then
    if ! is_kernel_root "$PWD"; then
      complain 'This command should be run in a kernel tree.'
      return 125 # ECANCELED
    fi

    case "$target" in
      1) # VM
        complain 'kw does not support config optimization for VM'
        return 95 # ENOTSUP
        ;;
      2) # LOCAL
        mods=$(cmd_manager "$flag" 'lsmod')
        ;;
      3) # REMOTE
        mods=$(cmd_remotely "$flag" 'lsmod')
        ;;
    esac

    printf '%s' "$mods" > "${KW_CACHE_DIR}/lsmod"

    cmd="make localmodconfig LSMOD=${KW_CACHE_DIR}/lsmod${output_kbuild_flag}"

    # 'make localmodconfig' uses .config from the current directory. So, we need
    # to rename the configuration file named <output> to .config. We also need to
    # check if there is already a .config in the current directory, and if
    # <output> isn't '.config'.
    # If there is a .config, we move it to KW_CACHE_DIR, rename <output> to
    # .config, run 'make localmodconfig', then move things back to place.
    if [[ "$output" != '.config' ]]; then
      if [[ -f "${config_base_path}/.config" ]]; then
        cmd_manager "$flag" "mv ${config_base_path}/${output} ${config_base_path}/.config"
        cmd_manager "$flag" "$cmd"
        cmd_manager "$flag" "mv ${config_base_path}/.config ${config_base_path}/${output}"
        cmd_manager "$flag" "mv ${KW_CACHE_DIR}/config/.config ${config_base_path}/.config"
      else
        cmd_manager "$flag" "mv ${config_base_path}/${output} ${config_base_path}/.config"
        cmd_manager "$flag" "$cmd"
        cmd_manager "$flag" "mv ${config_base_path}/.config ${config_base_path}/${output}"
      fi
    else
      cmd_manager "$flag" "$cmd"
    fi

    cmd="rm -f ${KW_CACHE_DIR}/lsmod"
    cmd_manager "$flag" "$cmd"
  fi

  cmd="rm -rf ${KW_CACHE_DIR}/config"
  cmd_manager "$flag" "$cmd"
  success 'Successfully retrieved' "$output"
}

# List name, description and last updated datetime of all kernel config files
# managed by kw.
function list_configs()
{
  local flag="${1:-SILENT}"
  local configs

  [[ "$flag" == 'VERBOSE' ]] && flag='CMD_SUBSTITUTION_VERBOSE'

  configs="$(select_from 'kernel_config' 'name AS \"Name\", description AS \"Description\", last_updated_datetime AS \"Last updated\"' '' "$flag" '.mode column')"

  if [[ -z "$configs" ]]; then
    say 'There are no .config files managed by kw'
    return 0
  fi

  say 'List of .config files managed by kw'
  printf '%s\n' "$configs"
}

# Remove and Get operation in the kernel-config-manager has similar criteria for working,
# because of this, basic_config_validations centralize the basic requirement
# validation.
#
# @config_name Name that identifies .config
# @force Force option. If set, it will ignores the warning message.
# @operation You can specify the operation name here
# @message Customized message to be showed to the users
# @flag: Flag to control function output
#
# Returns:
# Exits with 0 if everything ends well, otherwise exits an errno code.
# TODO: Best to return and let the caller handle it
function basic_config_validations()
{
  local config_name="$1"
  local force="$2"
  local operation="$3"
  local message="$4"
  local flag="${5:-SILENT}"
  local query_output
  local -r kernel_configs_dir="${KW_DATA_DIR}/configs"
  declare -A condition_array

  if [[ ! -f "${kernel_configs_dir}/${config_name}" ]]; then
    complain "Couldn't find config file named: ${config_name}"
    exit 2 # ENOENT
  fi

  [[ "$flag" == 'VERBOSE' ]] && flag='CMD_SUBSTITUTION_VERBOSE'

  condition_array=(['name']="${config_name}")
  query_output="$(select_from 'kernel_config' '' 'condition_array' "$flag")"

  if [[ -z "${query_output}" ]]; then
    complain "Couldn't find config in database named: ${config_name}"
    # Ask user what to do with hanging local .config
    if [[ $(ask_yN "Remove file ${kernel_configs_dir}/${config_name}?") =~ '1' ]]; then
      if is_safe_path_to_remove "${kernel_configs_dir}/${config_name}"; then
        say "Removing file: ${kernel_configs_dir}/${config_name}"
        cmd_manager "$flag" "rm ${kernel_configs_dir}/${config_name}"
      fi
    else
      say "${kernel_configs_dir}/${config_name} not removed"
    fi
    exit 2 # ENOENT
  fi

  if [[ "$force" != 1 ]]; then
    warning "$message"
    if [[ $(ask_yN 'Are you sure that you want to proceed?') =~ '0' ]]; then
      say "${operation} operation aborted"
      exit 0
    fi
  fi
}

# This function retrieves from one of the config files under the control of kw
# and put it in the current directory. This operation can be dangerous since it
# will override the existing .config file; because of this, it has a warning
# message.
#
# @config_name Name that identifies .config
# @force Force option. If it is set and the current name was already saved,
#        this option will override the '.config' file under the 'name'
#        specified by '-n' without any message.
#
# Returns:
# Exit with 0 if everything ends well, otherwise exit an errno code.
function get_config()
{
  local config_name="$1"
  local force="$2"
  local flag="$3"
  local -r kernel_configs_dir="${KW_DATA_DIR}/configs"
  local -r msg='This operation will override the current .config file'
  local config_base_path="$PWD"
  local cmd

  force=${force:-0}
  flag=${flag:-'SILENT'}

  if [[ -n "${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}" ]]; then
    config_base_path="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  fi

  # If we does not have a local config, there's no reason to warn the user
  [[ ! -f "${config_base_path}/.config" ]] && force=1

  basic_config_validations "$config_name" "$force" 'Get' "$msg" "$flag"

  cmd="cp ${kernel_configs_dir}/${config_name} ${config_base_path}/.config"
  cmd_manager "$flag" "$cmd"
  say "Current config file updated based on ${config_name}"
}

# Remove a config file under kw management
#
# @config_name Name that identifies .config
# @force Force option.
# @flag: Flag to control function output
#
# Returns:
# Exit 0 if everything ends well, otherwise exit an errno code.
function remove_config()
{
  local config_name="$1"
  local force="$2"
  local flag="${3:-SILENT}"
  declare -A condition_array
  local -r kernel_configs_dir="${KW_DATA_DIR}/configs"
  local -r msg="This operation will remove ${config_name} from kw management"
  local ret

  basic_config_validations "$config_name" "$force" 'Remove' "$msg" "$flag"

  if is_safe_path_to_remove "${kernel_configs_dir}/${config_name}"; then
    cmd_manager "$flag" "rm ${kernel_configs_dir}/${config_name}"
    if [[ "$?" -gt 0 ]]; then
      complain "Could not remove ${kernel_configs_dir}/${config_name}"
      return 1 # EPERM
    fi
  fi

  condition_array=(['name']="${config_name}")
  remove_from 'kernel_config' 'condition_array' '' '' "$flag"

  say "The ${config_name} config file was removed from kw management"
}

# This function parses the options from 'kw kernel-config-manager', and populates the global
# variable options_values accordingly.
function parse_kernel_config_manager_options()
{
  local short_options
  local long_options
  local options

  long_options='save:,list,get:,remove:,force,description:,fetch,output:,optimize,remote:,verbose'
  short_options='s:,l,r:,d:,f,o:'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw kernel-config-manager' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']=''
  options_values['SAVE']=''
  options_values['FORCE']=''
  options_values['OPTIMIZE']=''
  options_values['DESCRIPTION']=''
  options_values['LIST']=''
  options_values['GET']=''
  options_values['REMOVE']=''
  options_values['TARGET']="$LOCAL_TARGET"
  options_values['VERBOSE']=''

  # Set basic default values
  if [[ -n ${deploy_config[default_deploy_target]} ]]; then
    local config_file_deploy_target=${deploy_config[default_deploy_target]}
    options_values['TARGET']=${deploy_target_opt[$config_file_deploy_target]}
  else
    options_values['TARGET']="$VM_TARGET"
  fi

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']="Invalid remote: ${remote}"
    return 22 # EINVAL
  fi

  eval "set -- ${options}"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --force | -f)
        options_values['FORCE']=1
        shift
        ;;
      --save | -s)
        # Validate string name
        if [[ "$2" =~ ^- || -z "${2// /}" ]]; then
          complain 'Invalid argument'
          return 22 # EINVAL
        fi
        options_values['SAVE']="$2"
        shift 2
        ;;
      --description | -d)
        options_values['DESCRIPTION']="$2"
        shift 2
        ;;
      --list | -l)
        options_values['LIST']=1
        shift
        ;;
      --get)
        options_values['GET']="$2"
        shift 2
        ;;
      --remove | -r)
        options_values['REMOVE']="$2"
        shift 2
        ;;
      --fetch)
        options_values['FETCH']=1
        shift
        ;;
      --output | -o)
        options_values['OUTPUT']="$2"
        shift 2
        ;;
      --optimize)
        options_values['OPTIMIZE']=1
        shift
        ;;
      --remote)
        populate_remote_info "$2"
        if [[ "$?" == 22 ]]; then
          options_values['ERROR']="$options"
          return 22 # EINVAL
        fi
        options_values['TARGET']="$REMOTE_TARGET"
        shift 2
        ;;
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      --)
        shift
        ;;
      *)
        complain "Invalid option: ${1}"
        exit 22 # EINVAL
        ;;
    esac
  done

  if [[ -z "${options_values['FETCH']}" ]]; then
    if [[ -n "${options_values['OUTPUT']}" ]]; then
      complain '--output|-o can only be used with --fetch'
      return 22 # EINVAL
    fi
    if [[ -n "${options_values['OPTIMIZE']}" ]]; then
      complain '--optimize can only be used with --fetch'
      return 22 # EINVAL
    fi
  fi
}

function config_manager_help()
{
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'kernel-config-manager'
    return
  fi
  printf '%s\n' 'kw config manager:' \
    '  kernel-config-manager --fetch [(-o | --output) <filename>] [-f | --force] [--optimize] [--remote [<user>@<ip>:<port>]] - Fetch a config' \
    '  kernel-config-manager (-s | --save) <name> [(-d | --description) <description>] [-f | --force] - Save a config' \
    '  kernel-config-manager (-l | --list) - List config files under kw management' \
    '  kernel-config-manager --get <name> [-f | --force] - Get a config labeled with <name>' \
    '  kernel-config-manager (-r | --remove) <name> [-f | --force] - Remove config labeled with <name>' \
    '  kernel-config-manager (--verbose) - Show a detailed output'
}

load_build_config
load_deploy_config
load_kworkflow_config
