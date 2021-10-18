include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/remote.sh"
include "$KW_LIB_DIR/signal_manager.sh"

declare -gr metadata_dir='metadata'
declare -gr configs_dir='configs'
declare -gA options_values
declare -g root='/'
declare -g PROC_CONFIG_PATH='/proc/config.gz'

# This function handles the options available in 'configm'.
#
# @* This parameter expects a list of parameters, such as '-n', '-d', and '-f'.
#
# Returns:
# Return 0 if everything ends well, otherwise return an errno code.
function execute_config_manager()
{
  local name_config
  local description_config
  local force
  local flag='SILENT'
  local optimize
  local user
  local remote
  local ip
  local port

  if [[ -z "$*" ]]; then
    list_configs
    return "$?"
  fi

  if [[ "$1" =~ -h|--help ]]; then
    config_manager_help "$1"
    exit 0
  fi

  parse_configm_options "$@"

  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    exit 22 # EINVAL
  fi

  name_config="${options_values['SAVE']}"
  description_config="${options_values['DESCRIPTION']}"
  force="${options_values['FORCE']}"
  optimize="${options_values['OPTIMIZE']}"

  if [[ -n "${options_values['SAVE']}" ]]; then
    save_config_file "$force" "$name_config" "$description_config"
    return "$?"
  fi

  if [[ -n "${options_values['LIST']}" ]]; then
    list_configs
    return "$?"
  fi

  if [[ -n "${options_values['GET']}" ]]; then
    get_config "${options_values['GET']}" "$force"
    return "$?"
  fi

  if [[ -n "${options_values['REMOVE']}" ]]; then
    remove_config "${options_values['REMOVE']}" "$force"
    return "$?"
  fi

  if [[ -n "${options_values['FETCH']}" ]]; then
    fetch_config "$flag" "$force" "${options_values['OUTPUT']}" "$optimize" "${options_values['TARGET']}"
    return "$?"
  fi
}

# This function handles the save operation of kernel's '.config' file. It
# checks if the '.config' exists and saves it using git (dir.:
# <kw_install_path>/configs)
#
# @force Force option. If it is set and the current name was already saved,
#        this option will override the '.config' file under the 'name'
#        specified by '-n' without any message.
# @name This option specifies a name for a target .config file. This name
#       represents the access key for .config.
# @description Description for a config file, de descrition from '-d' flag.
function save_config_file()
{
  local -r force="$1"
  local -r name="$2"
  local -r description="$3"
  local -r original_path="$PWD"
  local -r dot_configs_dir="$KW_DATA_DIR/configs"

  if [[ ! -f "$original_path/.config" ]]; then
    complain 'There is no .config file in the current directory'
    return 2 # ENOENT
  fi

  if [[ ! -d "$dot_configs_dir" || ! -d "$dot_configs_dir/$metadata_dir" ]]; then
    mkdir -p "$dot_configs_dir"
    cd "$dot_configs_dir" || exit_msg 'It was not possible to move to configs dir'
    git init --quiet
    mkdir -p "$metadata_dir" "$configs_dir"
  fi

  cd "$dot_configs_dir" || exit_msg 'It was not possible to move to configs dir'

  # Check if the metadata related to .config file already exists
  if [[ ! -f "$metadata_dir/$name" ]]; then
    touch "$metadata_dir/$name"
  elif [[ "$force" != 1 ]]; then
    if [[ $(ask_yN "$name already exists. Update?") =~ '0' ]]; then
      complain 'Save operation aborted'
      cd "$original_path" || exit_msg 'It was not possible to move back from configs dir'
      return 0
    fi
  fi

  if [[ -n "$description" ]]; then
    printf '%s\n' "$description" > "$metadata_dir/$name"
  fi

  cp "$original_path/.config" "$dot_configs_dir/$configs_dir/$name"
  git add "$configs_dir/$name" "$metadata_dir/$name"
  git commit -m "New config file added: $USER - $(date)" > /dev/null 2>&1

  if [[ "$?" == 1 ]]; then
    warning "Warning: $name: there's nothing new in this file"
  else
    success "Saved $name"
  fi

  cd "$original_path" || exit_msg 'It was not possible to move back from configs dir'
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
  if [[ -d "$KW_CACHE_DIR/config" ]]; then
    cmd_manager "$flag" "mv $KW_CACHE_DIR/config/* $PWD"
    cmd_manager "$flag" "rmdir $KW_CACHE_DIR/config"
  fi

  if [[ -f "$KW_CACHE_DIR/lsmod" ]]; then
    cmd_manager "$flag" "rm $KW_CACHE_DIR/lsmod"
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
#   options see `src/kwlib.sh` function `cmd_manager`.
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
  local user="${remote_parameters['REMOTE_USER']}"
  local ip="${remote_parameters['REMOTE_IP']}"
  local port="${remote_parameters['REMOTE_PORT']}"
  local ret
  local -r CMD_LOAD_CONFIG_MODULE="modprobe -q configs && [ -s $PROC_CONFIG_PATH ]"
  local CMD_GET_CONFIG="zcat /proc/config.gz > $output"

  [[ "$target" == 3 ]] && CMD_GET_CONFIG="zcat /proc/config.gz > /tmp/$output"

  case "$target" in
    1) # VM
      # We do not support this option with VM
      return 95
      ;;
    2) # LOCAL
      # Try to find /proc/config, if we cannot find, attempt to load the module
      # and try it again. If we fail, give of of using /proc/config
      if [[ ! -f "$PROC_CONFIG_PATH" ]]; then
        cmd_manager "$flag" "sudo $CMD_LOAD_CONFIG_MODULE"
        [[ "$?" != 0 ]] && return 95 # Operation not supported
      fi

      cmd_manager "$flag" "$CMD_GET_CONFIG"
      return 0
      ;;
    3) # REMOTE
      cmd_remotely "[ -f $PROC_CONFIG_PATH ]" "$flag" "$ip" "$port" "$user"
      if [[ "$?" != 0 ]]; then
        cmd_remotely "$CMD_LOAD_CONFIG_MODULE" "$flag" "$ip" "$port" "$user"
        [[ "$?" != 0 ]] && return 95 # Operation not supported
      fi

      cmd_remotely "$CMD_GET_CONFIG" "$flag" "$ip" "$port" "$user"
      [[ "$?" != 0 ]] && return 95 # Operation not supported
      remote2host "$flag" "/tmp/$output" "$PWD"
      return 0
      ;;
  esac

  return 95 # ENOTSUP
}

# Usually, this function is used as the fallback from get_config_from_proc,
# which will try to retrieve the config file from the standard /boot folder.
#
# @flag How to display a command, the default value is "SILENT". For more
#   options see `src/kwlib.sh` function `cmd_manager`.
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

  case "$target" in
    1) # VM
      # TODO: We can support VM in this scenario
      return 95 # We do not support this option with VM
      ;;
    2) # LOCAL
      cmd="cp ${root}boot/config-$(uname -r) $output 2>/dev/null"
      cmd_manager "$flag" "$cmd"
      [[ "$?" != 0 ]] && return 95 # ENOTSUP
      return 0
      ;;
    3) # REMOTE
      kernel_release=$(cmd_remotely 'uname -r' "$flag")
      cmd_remotely "[ -f ${root}boot/config-$kernel_release ]" "$flag"
      [[ "$?" != 0 ]] && return 95 # ENOTSUP

      remote2host "$flag" "${root}boot/config-$kernel_release" "$PWD"
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
#   options see `src/kwlib.sh` function `cmd_manager`.
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

  cross_compile=${configurations[cross_compile]}
  arch=${configurations[arch]}
  # TODO: Right now, the below variable has no meaning and will be empty. Let's
  # expand the config file to enable developers to define ASIC targets.
  asic=${configurations[asic]}

  # Build command
  [[ -n "$arch" ]] && cmd+=" ARCH=$arch"
  [[ -n "$cross_compile" ]] && cmd+=" CROSS_COMPILE=$cross_compile"
  [[ -n "$asic" ]] && cmd+=" $asic\_defconfig"

  # If the --output option is passed, we don't want to override the current
  # config
  if [[ -f "$PWD/.config" && "$output" != '.config' ]]; then
    cmd+=" && mv $PWD/.config $output && mv $KW_CACHE_DIR/config/.config $PWD/.config"
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

  output=${output:-'.config'}

  # Folder to store files in case there's an interruption and we need to return
  # things to the state they were before or in case we need a place to store
  # files temporarily.
  mkdir -p "$KW_CACHE_DIR/config"

  if [[ -f "$PWD/$output" ]]; then
    if [[ -z "$force" && $(ask_yN "Do you want to overwrite $output in your current directory?") =~ "0" ]]; then
      warning 'Operation aborted'
      return 125 #ECANCELED
    fi

    cp "$PWD/$output" "$KW_CACHE_DIR/config"
  fi

  # If --output is provided, we need to backup the current config file
  if [[ -f "$PWD/.config" && "$output" != '.config' ]]; then
    cp "$PWD/.config" "$KW_CACHE_DIR/config"
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
  cmd='make olddefconfig'
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
        mods=$(cmd_remotely 'lsmod' "$flag" "$ip" "$port" "$user")
        ;;
    esac

    printf "%s" "$mods" > "$KW_CACHE_DIR/lsmod"

    cmd="make localmodconfig LSMOD=$KW_CACHE_DIR/lsmod"

    # 'make localmodconfig' uses .config from the current directory. So, we need
    # to rename the configuration file named <output> to .config. We also need to
    # check if there is already a .config in the current directory, and if
    # <output> isn't '.config'.
    # If there is a .config, we move it to KW_CACHE_DIR, rename <output> to
    # .config, run 'make localmodconfig', then move things back to place.
    if [[ "$output" != '.config' ]]; then
      if [[ -f "$PWD/.config" ]]; then
        cmd_manager "$flag" "mv $PWD/$output $PWD/.config"
        cmd_manager "$flag" "$cmd"
        cmd_manager "$flag" "mv $PWD/.config $PWD/$output"
        cmd_manager "$flag" "mv $KW_CACHE_DIR/config/.config $PWD/.config"
      else
        cmd_manager "$flag" "mv $PWD/$output $PWD/.config"
        cmd_manager "$flag" "$cmd"
        cmd_manager "$flag" "mv $PWD/.config $PWD/$output"
      fi
    else
      cmd_manager "$flag" "$cmd"
    fi

    rm -f "$KW_CACHE_DIR/lsmod"
  fi

  rm -rf "$KW_CACHE_DIR/config"
  success 'Successfully retrieved' "$output"
}

function list_configs()
{
  local -r dot_configs_dir="$KW_DATA_DIR/configs"
  local name
  local content

  if [[ ! -d "$dot_configs_dir" || ! -d "$dot_configs_dir/$metadata_dir" ]]; then
    say 'There is no tracked .config file'
    return 0
  fi

  printf '%-30s | %-30s\n' 'Name' $'Description\n'
  for filename in "$dot_configs_dir/$metadata_dir"/*; do
    [[ ! -f "$filename" ]] && continue
    name=$(basename "$filename")
    content=$(cat "$filename")
    printf '%-30s | %-30s\n' "$name" "$content"
  done
}

# Remove and Get operation in the configm has similar criteria for working,
# because of this, basic_config_validations centralize the basic requirement
# validation.
#
# @target File name of the target config file
# @force Force option. If set, it will ignores the warning message.
# @operation You can specify the operation name here
# @message Customized message to be showed to the users
#
# Returns:
# Return 0 if everything ends well, otherwise return an errno code.
function basic_config_validations()
{
  local target="$1"
  local force="$2"
  local operation="$3" && shift 3
  local message="$*"
  local -r dot_configs_dir="$KW_DATA_DIR/configs/configs"

  if [[ ! -f "$dot_configs_dir/$target" ]]; then
    complain "No such file or directory: $target"
    exit 2 # ENOENT
  fi

  if [[ "$force" != 1 ]]; then
    warning "$message"
    if [[ $(ask_yN 'Are you sure that you want to proceed?') =~ '0' ]]; then
      complain "$operation operation aborted"
      exit 0
    fi
  fi
}

# This function retrieves from one of the config files under the control of kw
# and put it in the current directory. This operation can be dangerous since it
# will override the existing .config file; because of this, it has a warning
# message.
#
# @target File name of the target config file
# @force Force option. If it is set and the current name was already saved,
#        this option will override the '.config' file under the 'name'
#        specified by '-n' without any message.
#
# Returns:
# Exit with 0 if everything ends well, otherwise exit an errno code.
function get_config()
{
  local target="$1"
  local force="$2"
  local -r dot_configs_dir="$KW_DATA_DIR/configs/configs"
  local -r msg='This operation will override the current .config file'

  force=${force:-0}

  # If we does not have a local config, there's no reason to warn the user
  [[ ! -f "$PWD/.config" ]] && force=1

  basic_config_validations "$target" "$force" "Get" "$msg"

  cp "$dot_configs_dir/$target" .config
  say "Current config file updated based on $target"
}

# Remove a config file under kw management
#
# @target File name of the target config file
# @force Force option.
#
# Returns:
# Exit 0 if everything ends well, otherwise exit an errno code.
function remove_config()
{
  local target="$1"
  local force="$2"
  local original_path="$PWD"
  local -r dot_configs_dir="$KW_DATA_DIR/configs"
  local -r msg="This operation will remove $target from kw management"

  basic_config_validations "$target" "$force" 'Remove' "$msg"

  cd "$dot_configs_dir" || exit_msg 'It was not possible to move to configs dir'
  git rm "$configs_dir/$target" "$dot_configs_dir/$metadata_dir/$target" > /dev/null 2>&1
  git commit -m "Removed $target config: $USER - $(date)" > /dev/null 2>&1
  cd "$original_path" || exit_msg 'It was not possible to move back from configs dir'

  say "The $target config file was removed from kw management"

  # Without config file, there's no reason to keep config directory
  if [ ! "$(ls "$dot_configs_dir")" ]; then
    rm -rf "/tmp/$configs_dir"
    mv "$dot_configs_dir" /tmp
  fi
}

# This function parses the options from 'kw configm', and populates the global
# variable options_values accordingly.
function parse_configm_options()
{
  local short_options
  local long_options
  local options

  long_options='save:,list,get:,remove:,force,description:,fetch,output:,optimize,remote:'
  short_options='s:,l,r:,d:,f,o:'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw configm' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['SAVE']=''
  options_values['FORCE']=''
  options_values['OPTIMIZE']=''
  options_values['DESCRIPTION']=''
  options_values['LIST']=''
  options_values['GET']=''
  options_values['REMOVE']=''
  options_values['TARGET']="$LOCAL_TARGET"

  eval "set -- $options"

  # Set basic default values
  if [[ -n ${configurations[default_deploy_target]} ]]; then
    local config_file_deploy_target=${configurations[default_deploy_target]}
    options_values['TARGET']=${deploy_target_opt[$config_file_deploy_target]}
  else
    options_values['TARGET']="$VM_TARGET"
  fi

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']="Invalid remote: $remote"
    return 22 # EINVAL
  fi

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
        options_values['TARGET']="$REMOTE_TARGET"
        shift
        populate_remote_info "$1"
        if [[ "$?" == 22 ]]; then
          return 22 # EINVAL
        fi
        shift
        ;;
      --)
        shift
        ;;
      *)
        complain "Invalid option: $1"
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
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'configm'
    return
  fi
  printf '%s\n' 'kw config manager:' \
    '  configm --fetch [(-o | --output) <filename>] [-f | --force] [--optimize] [--remote [<user>@<ip>:<port>]] - Fetch a config' \
    '  configm (-s | --save) <name> [(-d | --description) <description>] [-f | --force] - Save a config' \
    '  configm (-l | --list) - List config files under kw management' \
    '  configm --get <name> [-f | --force] - Get a config file based named <name>' \
    '  configm (-r | --remove) <name> [-f | --force] - Remove config labeled with <name>'
}
