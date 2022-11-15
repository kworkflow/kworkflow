#
# The `deploy.sh` file centralizes functions related to kernel installation.
# With kworkflow, we want to handle three scenarios:
#
# 1. Virtual Machine (VM): we want to provide support for developers that uses
#    VM during their work with Linux Kernel, because of this kw provide
#    essential features for this case.
# 2. Local: we provide support for users to utilize their machine as a target.
# 3. Remote: we provide support for deploying kernel in a remote machine. It is
#    important to highlight that a VM in the localhost can be treated as a
#    remote machine.
#
# Usually, installing modules and updating the kernel image requires root
# permission. With this idea in mind we rely on the `/root` in the remote
# machine. Additionally, for local deploy you will be asked to enter your root
# password.
#

include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/remote.sh"
include "$KW_LIB_DIR/signal_manager.sh"

# To make the deploy to a remote machine straightforward, we create a directory
# on the host that will be used for centralizing files required for the new
# deploy.
REMOTE_KW_DEPLOY='/opt/kw'
KW_DEPLOY_TMP_FILE='/tmp/kw'
REMOTE_INTERACE_CMD_PREFIX="bash $REMOTE_KW_DEPLOY/remote_deploy.sh --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"

# We now have a kw directory visible for users in the home directory, which is
# used for saving temporary files to be deployed in the target machine.
LOCAL_TO_DEPLOY_DIR='to_deploy'
LOCAL_REMOTE_DIR='remote'

# We have a generic script named `distro_deploy.sh` that handles the essential
# operation of installing a new kernel; it depends on "kernel_install" plugin
# to work as expected
DISTRO_DEPLOY_SCRIPT="$REMOTE_KW_DEPLOY/distro_deploy.sh"

# Hash containing user options
declare -gA options_values

# Associative array that map deploy info
# e.g., ['distro']='debian', ['bootloader']='grub'
declare -gA target_deploy_info

# From kw perspective, deploy a new kernel is composed of two steps: install
# modules and update kernel image. I chose this approach for reducing the
# chances of break the system due to modules and kernel mismatch. This function
# is responsible for handling some of the userspace options and calls the
# required functions to update the kernel. This function handles a different
# set of parameters for the distinct set of target machines.
#
# @build_and_deploy If the user uses `kw bd` we can safely copy the local
#                   .config file.
#
# Note: I know that developer know what they are doing (usually) and in the
# future, it will be nice if we support single kernel update (patches are
# welcome).
#
# Note: This function relies on the parameters set in the config file.
function deploy_main()
{
  local build_and_deploy="$1"
  local reboot=0
  local modules=0
  local target=0
  local list=0
  local single_line=0
  local uninstall=''
  local start=0
  local end=0
  local runtime=0
  local ret=0
  local list_all
  local setup
  local flag
  local modules_install_status
  local env_name
  local output_kbuild_path=''
  local return_tar_path
  local kernel_binary_image_name
  local cache_to_deploy_path

  # Drop build_and_deploy flag
  shift

  if [[ "$1" =~ -h|--help ]]; then
    deploy_help "$1"
    exit 0
  fi

  parse_deploy_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    exit 22 # EINVAL
  fi

  if [[ -z "${options_values['FROM_PACKAGE']}" ]]; then
    if ! is_kernel_root "$PWD"; then
      complain 'Execute this command in a kernel tree.'
      exit 125 # ECANCELED
    fi
  fi

  env_name=$(get_current_env_name)
  if [[ "$?" == 0 ]]; then
    options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']="${KW_CACHE_DIR}/${env_name}"
    output_kbuild_path=" O=${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']} --silent"
  fi

  flag="${options_values['TEST_MODE']}"
  target="${options_values['TARGET']}"
  reboot="${options_values['REBOOT']}"
  modules="${options_values['MODULES']}"
  single_line="${options_values['LS_LINE']}"
  list_all="${options_values['LS_ALL']}"
  list="${options_values['LS']}"
  uninstall="${options_values['UNINSTALL']}"
  uninstall_force="${options_values['UNINSTALL_FORCE']}"
  setup="${options_values['SETUP']}"

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  signal_manager 'cleanup' || warning 'Was not able to set signal handler'

  update_deploy_variables

  # List option
  if [[ "$list" == 1 || "$single_line" == 1 || "$list_all" == 1 ]]; then
    say 'Available kernels:'
    start=$(date +%s)
    run_list_installed_kernels "$flag" "$single_line" "$target" "$list_all"
    end=$(date +%s)

    runtime=$((end - start))
    statistics_manager 'list' "$runtime"
    exit "$?"
  fi

  # Uninstall option
  if [[ -n "$uninstall" ]]; then
    start=$(date +%s)
    run_kernel_uninstall "$target" "$reboot" "$uninstall" "$flag" "$uninstall_force"
    end=$(date +%s)

    runtime=$((end - start))
    statistics_manager 'uninstall' "$runtime"
    return "$?"
  fi

  prepare_host_deploy_dir

  # We don't want to run the setup if the user request the package creation
  if [[ -z "${options_values['CREATE_PACKAGE']}" ]]; then
    # Setup option
    # Let's ensure that the target machine is ready for the deploy
    deploy_setup "$target" "$flag"
    ret="$?"
    case "$ret" in
      103) # ECONNABORTED
        complain 'Something failed while kw tried to setup passwordless for root'
        exit 103
        ;;
      101) # ENETUNREACH
        complain 'It looks like kw successfully set up the ssh via root, but ' \
          'we could not ssh to it for some unknown reason.'
        ssh_connection_failure_message
        exit 101
        ;;
    esac

    # If user request --setup, we don't need to do anything else
    if [[ -n "$setup" ]]; then
      [[ "$ret" == 0 ]] && success 'It looks like you are ready to use kw deploy.'
      return "$?"
    fi

    collect_target_info_for_deploy "$target" "$flag"
  fi

  # NOTE: If we deploy a new kernel image that does not match with the modules,
  # we can break the boot. For security reason, every time we want to deploy a
  # new kernel version we also update all modules; maybe one day we can change
  # it, but for now this looks the safe option.

  if [[ -z "${options_values['FROM_PACKAGE']}" ]]; then
    # Note that kw needs the kernel_binary_image_name for the remote deploy
    build_kw_kernel_package return_tar_path kernel_binary_image_name "$flag"
    modules_install_status="$?"
    if [[ ! -f "$return_tar_path" ]]; then
      complain "kw was not able to generate kw package: ${return_tar_path}"
      return 22 # EINVAL
    fi

    case "$modules_install_status" in
      2)
        complain "Kernel image was not found at: ${kernel_tree_boot_folder_path}"
        exit 2 # ENOENT
        ;;
      22)
        complain 'Kernel name not specified for get_config_file_for_deploy'
        exit 22 # EINVAL
        ;;
      125)
        complain "We could not find a valid kernel image at arch/${build_config[arch]}/boot"
        complain 'Please, check if your compilation successfully completed or'
        complain 'check your kworkflow.config'
        exit 125 # ECANCELED
        ;;
    esac
  else
    if [[ ! -f "${options_values['FROM_PACKAGE']}" ]]; then
      complain "The parameter '${options_values['FROM_PACKAGE']}' is not a path"
      exit 22 # EINVAL
    fi

    cache_to_deploy_path="${KW_CACHE_DIR}/${LOCAL_TO_DEPLOY_DIR}"

    cp "${options_values['FROM_PACKAGE']}" "${cache_to_deploy_path}"
    return_tar_path="${cache_to_deploy_path}/${options_values['FROM_PACKAGE']}"
  fi

  # Get kw package option
  if [[ -n "${options_values['CREATE_PACKAGE']}" ]]; then
    mv "$return_tar_path" "$PWD"
    return "$?"
  fi

  # Full deploy
  if [[ "$modules" == 0 ]]; then
    start=$(date +%s)
    # Update name: release + alias
    run_kernel_install "$return_tar_path" "$kernel_binary_image_name" "$flag"
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      end=$(date +%s)
      runtime=$((runtime + (end - start)))
      statistics_manager 'deploy_failure' "$runtime"
      exit "$ret"
    fi
    end=$(date +%s)
    runtime=$((runtime + (end - start)))
    statistics_manager 'deploy' "$runtime"
  else # Only module deploy
    start=$(date +%s)
    modules_install "$target" "$return_tar_path" "$flag"
    end=$(date +%s)
    runtime=$((end - start))
    statistics_manager 'Modules_deploy' "$runtime"
  fi

  #shellcheck disable=SC2119
  cleanup
}

# This function is responsible for setting up the ssh key for users, including
# the root user.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# If everything is alright, it returns 0, otherwise, it can return:
# - 103: ssh-copy-id failed
# - 101: ssh to the target machine failed
function setup_remote_ssh_with_passwordless()
{
  local flag="$1"
  local copy_key_cmd
  local users="root ${remote_parameters['REMOTE_USER']}"
  local root_user_setup=0

  flag=${flag:-'SILENT'}

  say '-> Trying to set up passwordless access'$'\n'

  for user in $users; do
    # Just avoid setup root twice
    [[ "$user" == 'root' && "$root_user_setup" == 1 ]] && continue
    [[ "$user" == 'root' ]] && ((root_user_setup++))

    # Use config file or ip info
    if [[ -n ${remote_parameters['REMOTE_FILE']} && -n ${remote_parameters['REMOTE_FILE_HOST']} ]]; then
      copy_key_cmd="ssh-copy-id -F ${remote_parameters['REMOTE_FILE']} ${remote_parameters['REMOTE_FILE_HOST']}"
    else
      copy_key_cmd="ssh-copy-id ${user}@${remote_parameters['REMOTE_IP']}"
    fi

    # Try to copy-ssh-id
    cmd_manager "$flag" "$copy_key_cmd"
    [[ "$?" != 0 ]] && return 103 # ECONNABORTED

    # Check if we can connect without password
    is_ssh_connection_configured "$flag" '' '' "$user"
    if [[ "$?" != 0 ]]; then
      return 101 # ENETUNREACH
    fi
  done
}

# Every distro family has its specific idiosyncrasy; for this reason, in the
# plugin folder, we have a code per distro supported by kw. This function is
# the entry point to call the specific code for the target distro.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
function prepare_distro_for_deploy()
{
  local target="$1"
  local flag="$2"
  local distro
  local distro_info

  flag=${flag:-'SILENT'}

  say '-> Basic distro set up'$'\n'

  case "$target" in
    2) # LOCAL_TARGET
      distro=$(detect_distro '/')
      # Distro must be loaded first to ensure the right variables
      include "$KW_PLUGINS_DIR/kernel_install/$distro.sh"
      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"

      distro_deploy_setup "$flag" "${target}"
      ;;
    3) # REMOTE_TARGET
      local cmd="$REMOTE_INTERACE_CMD_PREFIX"
      cmd+=" --deploy-setup ${flag} ${target}"

      cmd_remotely "$cmd" "$flag"
      ;;
  esac
}

# We want to avoid setting up the same thing repeatedly; for this reason, kw
# creates a log status file at the end of the setup. This function generates
# the status file with the target code, date, and time information.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
function update_status_log()
{
  local target="$1"
  local flag="$2"
  local log_date=''
  local status_cmd=''

  flag=${flag:-'SILENT'}

  log_date=$(date +'%m/%d/%Y-%H:%M:%S')
  status_cmd="printf '%s;%s\n' '$target' '$log_date' >> $REMOTE_KW_DEPLOY/status"

  case "$target" in
    2) # LOCAL_TARGET
      cmd_manager "$flag" "$status_cmd"
      ;;
    3) # REMOTE_TARGET
      cmd_remotely "$status_cmd" "$flag"
      ;;
  esac
}

# This function is responsible for checking the latest status for the deploy
# setup. If it was already done, this function returns 0; otherwise, it will
# return another value that expresses the necessity of setting up the target
# machine.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Return 0 if the setup was done before, or 2 if not.
function check_setup_status()
{
  local target="$1"
  local flag="$2"
  local cmd="test -f $REMOTE_KW_DEPLOY/status"
  local ret

  flag=${flag:-'SILENT'}

  case "$target" in
    2) # LOCAL target
      cmd_manager "$flag" "$cmd"
      ret="$?"
      ;;
    3) # REMOTE_TARGET
      cmd_remotely "$cmd" "$flag"
      ret="$?"
      ;;
  esac

  if [[ "$ret" != 0 ]]; then
    return 2 # ENOENT
  fi
}

# This is the core of setting up a target machine to ensure it is ready for
# deploy. In a few words, this function will invoke ssh configuration, remote
# folder setup, distro-specific code, and update setup log. Notice that this
# function checks if the target machine needs to be set up or not.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Return 0 in case of success, otherwise, it return a code error
function deploy_setup()
{
  local target="$1"
  local flag="$2"
  # BatchMode ensure that the ssh fail if passwordless is not enabled
  local check_ssh='ssh -q -o BatchMode=yes '
  local cmd
  local ret

  flag=${flag:-'SILENT'}

  # If it is a remote, let's try to setup passwordless
  if [[ "$target" == "$REMOTE_TARGET" ]]; then
    is_ssh_connection_configured "$flag"
    if [[ "$?" != 0 ]]; then
      setup_remote_ssh_with_passwordless "$flag"
      ret="$?"
      [[ "$?" != 0 ]] && return "$ret"
    fi
  fi

  [[ "$target" == "$LOCAL_TARGET" ]] && prepare_local_dir "$flag"

  check_setup_status "$target" "$flag"
  if [[ "$?" == 0 ]]; then
    [[ "$target" == "$REMOTE_TARGET" ]] && prepare_remote_dir # Update files
    # We are good, there is no reason to setup anything else
    return 0
  fi

  # First setup cannot rely on rsync
  if [[ "$target" == "$REMOTE_TARGET" ]]; then
    prepare_remote_dir '' '' '' 1 # This only make sense in the remote
  fi

  # Distro specific scripts
  prepare_distro_for_deploy "$target" "$flag"

  # Update status log
  update_status_log "$target" "$flag"
}

# We can include plugin scripts when dealing with local, which will override
# some path variables. Since this will be a common task, this function is
# intended to centralize these required updates.
function update_deploy_variables()
{
  local kw_remote_path="${deploy_config[kw_files_remote_path]}"
  local kw_tmp_files="${deploy_config[deploy_temporary_files_path]}"

  REMOTE_KW_DEPLOY="${kw_remote_path:-$REMOTE_KW_DEPLOY}"
  KW_DEPLOY_TMP_FILE="${kw_tmp_files:-$KW_DEPLOY_TMP_FILE}"

  REMOTE_INTERACE_CMD_PREFIX="bash $REMOTE_KW_DEPLOY/remote_deploy.sh"
  REMOTE_INTERACE_CMD_PREFIX+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
}

# Kw can deploy a new kernel image or modules (or both) in a target machine
# based on a Linux repository; however, we need a place for adding the
# intermediary archives that we will send to a remote device. This function
# prepares such a directory.
function prepare_host_deploy_dir()
{
  # If all the required paths already exist, let's not waste time
  if [[ -d "$KW_CACHE_DIR" && -d "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR" &&
    -d "$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR" ]]; then
    return
  fi

  # In case we need to create some of the basic directories
  mkdir -p "$KW_CACHE_DIR"
  mkdir -p "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR"
  mkdir -p "$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR"
}

# To deploy a new kernel or module, we have to prepare a directory in the
# remote machine that will accommodate a set of files that we need to update
# the kernel. This function checks if we support the target distribution and
# finally prepared the remote machine for receiving the new kernel. Finally, it
# creates a "/root/kw_deploy" directory inside the remote machine and prepare
# it for deploy.
#
# @remote IP address of the target machine
# @port Destination for sending the file
# @user User in the host machine. Default value is "root"
# @flag How to display a command, default is SILENT
function prepare_remote_dir()
{
  local remote="${1:-${remote_parameters['REMOTE_IP']}}"
  local port="${2:-${remote_parameters['REMOTE_PORT']}}"
  local user="${3:-${remote_parameters['REMOTE_USER']}}"
  local first_deploy="$4"
  local flag="$5"
  local kw_deploy_cmd="mkdir -p $REMOTE_KW_DEPLOY"
  local distro_info=''
  local distro=''
  local remote_deploy_path="$KW_PLUGINS_DIR/kernel_install/remote_deploy.sh"
  local util_path="$KW_PLUGINS_DIR/kernel_install/utils.sh"
  local target_deploy_path="$KW_PLUGINS_DIR/kernel_install/"
  local files_to_send

  flag=${flag:-'SILENT'}

  distro_info=$(which_distro "$remote" "$port" "$user")
  distro=$(detect_distro '/' "$distro_info")

  if [[ $distro =~ "none" ]]; then
    complain "Unfortunately, there's no support for '$distro_info'"
    exit 95 # ENOTSUP
  fi

  target_deploy_path=$(join_path "$target_deploy_path" "$distro.sh")
  files_to_send="$KW_PLUGINS_DIR/kernel_install/{remote_deploy.sh,utils.sh,$distro.sh,bootloader_utils.sh,grub.sh,rpi_bootloader.sh}"

  # Send required scripts for running the deploy inside the target machine
  # Note: --archive will force the creation of /root/kw_deploy in case it does
  # not exits
  if [[ -z "$first_deploy" ]]; then
    cp2remote "$flag" "$files_to_send" "$REMOTE_KW_DEPLOY" \
      '--archive' "$remote" "$port" "$user" 'quiet'
  else
    say '* Sending kw to the remote'
    cmd_remotely "mkdir -p $REMOTE_KW_DEPLOY" "$flag"

    if [[ -n ${remote_parameters['REMOTE_FILE']} && -n ${remote_parameters['REMOTE_FILE_HOST']} ]]; then
      cmd="scp -q -F ${remote_parameters['REMOTE_FILE']} $files_to_send ${remote_parameters['REMOTE_FILE_HOST']}:$REMOTE_KW_DEPLOY"
    else
      cmd="scp -q $files_to_send ${remote_parameters['REMOTE_USER']}@${remote_parameters['REMOTE_IP']}:$REMOTE_KW_DEPLOY"
    fi

    cmd_manager "$flag" "$cmd"
  fi

  # Create temporary folder
  cmd_remotely "mkdir -p $KW_DEPLOY_TMP_FILE" "$flag"

  # TODO: In some point, we need to move the below code to ArchLinux specific
  # file
  if [[ "$distro" == 'arch' ]]; then
    cp2remote "$flag" "$KW_ETC_DIR/template_mkinitcpio.preset" "$REMOTE_KW_DEPLOY"
  fi
}

# Create the temporary folder for local deploy.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# In case of success return 0, otherwise it may return:
# - EINVAL (22): If the temporary variable is not set or if kw cannot create the temporary folder.
# - EPERM (1): If it fails to clean the temporary folder.
function prepare_local_dir()
{
  local flag="$1"
  local ret

  flag=${flag:-'SILENT'}

  update_deploy_variables

  # Check if target variables are correct
  if [[ -z "${KW_DEPLOY_TMP_FILE}" ]]; then
    return 22 # EINVAL
  fi

  # Clean deploy folder
  cmd_manager "$flag" "rm --preserve-root=all --recursive --force ${KW_DEPLOY_TMP_FILE}"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    return 1 # EPERM
  fi

  # Recreate deploy folder
  cmd_manager "$flag" "mkdir --parents ${KW_DEPLOY_TMP_FILE}"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    return 22 # EINVAL
  fi
}

# This function list all the available kernels in a VM, local, and remote
# machine. This code relies on `kernel_install` plugin, more precisely on
# `utils.sh` file which comprises all the required operations for listing new
# Kernels.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
# @single_line If this option is set to 1 this function will display all
#   available kernels in a single line separated by commas. If it gets 0 it
#   will display each kernel name by line.
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @all If this option is set to one, this will list all kernels
#   availble. If not, will list only kernels that were installed by kw.
function run_list_installed_kernels()
{
  local flag="$1"
  local single_line="$2"
  local target="$3"
  local all="$4"
  local remote
  local port
  local user
  local cmd

  flag=${flag:-'SILENT'}

  case "$target" in
    2) # LOCAL_TARGET
      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      list_installed_kernels "$flag" "$single_line" "$all"
      ;;
    3) # REMOTE_TARGET
      local cmd="$REMOTE_INTERACE_CMD_PREFIX"
      cmd+=" --list-kernels $flag $single_line $all"

      cmd_remotely "$cmd" "$flag"
      ;;
  esac

  return 0
}

# Before we start the deploy, we need to collect some basic info to ensure the
# correct deploy. The most important info is the target distro and the
# bootloader type.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Populate target_deploy_info
function collect_target_info_for_deploy()
{
  local target="$1"
  local flag="$2"
  local distro_info
  local distro
  local data
  local verbose

  flag=${flag:-'SILENT'}
  # We cannot have any sort of extra output inside collect info
  if [[ "$flag" == 'VERBOSE' ]]; then
    flag='SILENT'
    verbose=1
  fi

  case "$target" in
    2) # LOCAL_TARGET
      include "$KW_PLUGINS_DIR/kernel_install/bootloader_utils.sh"
      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      data=$(collect_deploy_info "$flag" "$target")
      ;;
    3) # REMOTE_TARGET
      # Query bootload type
      local cmd="$REMOTE_INTERACE_CMD_PREFIX"
      cmd+=" --collect-info $flag $target"

      data=$(cmd_remotely "$cmd" "$flag")
      ;;
  esac

  # Populate associative array
  declare -gA target_deploy_info="($data)"
  distro=$(detect_distro '/' "${target_deploy_info['distro']}")

  if [[ "$distro" =~ 'none' ]]; then
    complain 'Unfortunately, there is no support for the target distro'
    exit 95 # ENOTSUP
  fi

  [[ -n "$verbose" ]] && printf '%s\n' "$data"
}

# This function handles the kernel uninstall process for different targets.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @reboot If this value is equal 1, it means reboot machine after kernel
#         installation.
# @kernels_target_list String containing kernels name separated by comma
# @flag How to display a command, see `src/kwlib.sh` function `cmd_manager`
# @force If this value is equal to 1, try to uninstall kernels even if they are
#        not managed by kw
#
# Return:
# Return 0 if everything is correct or an error in case of failure
function run_kernel_uninstall()
{
  local target="$1"
  local reboot="$2"
  local kernels_target_list="$3"
  local flag="$4"
  local force="$5"
  local distro
  local remote
  local port

  flag=${flag:-''}

  case "$target" in
    2) # LOCAL_TARGET
      distro=$(detect_distro '/')

      if [[ "$distro" =~ 'none' ]]; then
        complain 'Unfortunately, there is no support for the target distro'
        exit 95 # ENOTSUP
      fi

      # Local Deploy
      # We need to update grub, for this reason we to load specific scripts.
      include "$KW_PLUGINS_DIR/kernel_install/$distro.sh"
      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      include "${KW_PLUGINS_DIR}/kernel_install/bootloader_utils.sh"
      # Let's ensure that we are using the right variables
      update_deploy_variables

      # TODO: Rename kernel_uninstall in the plugin, this name is super
      # confusing
      kernel_uninstall "$reboot" 'local' "$kernels_target_list" "$flag" "$force"
      ;;
    3) # REMOTE_TARGET
      remote="${remote_parameters['REMOTE_IP']}"
      port="${remote_parameters['REMOTE_PORT']}"
      user="${remote_parameters['REMOTE_USER']}"

      # Deploy
      # TODO
      # It would be better if `cmd_remotely` handle the extra space added by
      # line break with `\`; this may allow us to break a huge line like this.
      local cmd="$REMOTE_INTERACE_CMD_PREFIX"
      cmd+=" --uninstall-kernels '$reboot' 'remote' '$kernels_target_list' '$flag' '$force'"
      cmd_remotely "$cmd" "$flag"
      ;;
  esac
}

# When kw deploy a new kernel it creates temporary files to be used for moving
# to the target machine. There is no need to keep those files in the user
# machine, for this reason, this function is in charge of cleanup the temporary
# files at the end.
function cleanup()
{
  local flag=${1:-'SILENT'}
  say 'Cleaning up temporary files...'

  if [[ -d "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR" ]]; then
    cmd_manager "$flag" "rm -rf $KW_CACHE_DIR/$LOCAL_REMOTE_DIR/"*
  fi

  if [[ -d "$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR" ]]; then
    cmd_manager "$flag" "rm -rf $KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/"*
  fi

  say 'Exiting...'
  exit 0
}

# This function expects a parameter that specifies the target machine;
# in the first case, the host machine is the target, and otherwise the virtual
# machine.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @return_tar_path
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Note:
# This function supposes that prepare_host_deploy_dir and prepare_remote_dir
# were invoked before.
function modules_install()
{
  local target="$1"
  local return_tar_path="$2"
  local flag="$3"
  local port
  local cmd

  flag=${flag:-'SILENT'}

  case "$target" in
    2) # LOCAL_TARGET
      modules_install_to '/lib/modules' "$flag" 'local'
      ;;
    3) # REMOTE_TARGET
      cp2remote "$flag" "$return_tar_path" "$KW_DEPLOY_TMP_FILE"
      release=$(get_kernel_release "$flag")

      say "* Sending kernel package (${release}) to the remote"

      # Execute script
      cmd="$REMOTE_INTERACE_CMD_PREFIX --modules ${release}.kw.tar"
      cmd_remotely "$cmd" "$flag"
      ;;
  esac
}

# This function is responsible for handling the command to
# `make install_modules`, and it expects a target path for saving the modules
# files.
#
# @install_to Target path to install the output of the command `make
#             modules_install`.
# @flag How to display a command, see `src/kwlib.sh` function `cmd_manager`
function modules_install_to()
{
  local install_to="$1"
  local flag="$2"
  local local_deploy="$3"
  local total_lines
  local pv_cmd
  local cmd=''
  local strip_modules_debug='INSTALL_MOD_STRIP=1 '
  local output_kbuild_flag
  local env_base_path="${PWD}/"

  flag=${flag:-'SILENT'}

  if [[ -n "${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}" ]]; then
    output_kbuild_flag=" O=${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
    env_base_path="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  fi

  if [[ ${deploy_config[strip_modules_debug_option]} == 'no' ]]; then
    strip_modules_debug=''
    grep --quiet --fixed-strings --line-regexp 'CONFIG_DEBUG_INFO=y' "${env_base_path}/.config"
    if [[ "$?" == 0 ]]; then
      load_module_text "${KW_ETC_DIR}/strings/deploy.txt"
      warning "${module_text_dictionary[large_initramfs_warning]}"
    fi
  fi

  if [[ "$local_deploy" == 'local' ]]; then
    cmd="sudo true && sudo -E make ${strip_modules_debug}modules_install${output_kbuild_flag}"
  else
    cmd="make ${strip_modules_debug}INSTALL_MOD_PATH=$install_to modules_install${output_kbuild_flag}"
  fi

  if [[ "$flag" != 'VERBOSE' && -f "${env_base_path}/modules.order" ]]; then
    total_lines=$(wc -l < "${env_base_path}/modules.order")
    cmd+=" | grep INSTALL | pv -p --line-mode --size $total_lines > /dev/null"
  fi

  say '* Preparing modules'
  cmd_manager "$flag" "$cmd"
}

# This function manages three different patterns from the config file: empty,
# single folder with a pattern, multiple folders.
#
# @arch_target: Target architecture
#
# Return:
# Return a string to be used in the source parameter of a cp command.
function compose_copy_source_parameter_for_dtb()
{
  local arch_target="$1"
  local copy_pattern
  local char_count
  local dts_base_path
  local kbuild_output_prefix="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"

  copy_pattern="${deploy_config[dtb_copy_pattern]}"
  dts_base_path="arch/${arch_target}/boot/dts"

  # Check env
  if [[ -n "$kbuild_output_prefix" ]]; then
    dts_base_path="${kbuild_output_prefix}/${dts_base_path}"
  fi

  # Pattern 1: No pattern. Let's copy all dtb files, e.g., copy_pattern='*.dtb'
  if [[ -z "$copy_pattern" ]]; then
    printf '%s/*.dtb' "$dts_base_path"
    return
  fi

  # Pattern 2: Mupliple dts folder, e.g., copy_pattern={broadcom,rockchip,arm}
  char_count=$(str_count_char_repetition "$copy_pattern" ',')
  if [[ "$char_count" -ge 1 ]]; then
    printf ' -r %s/{%s}' "$dts_base_path" "$copy_pattern"
    return
  fi

  # Pattern 3: The '*' wildcard. E.g., copy_pattern='broadcom/*'
  char_count=$(str_count_char_repetition "$copy_pattern" '*')
  if [[ "$char_count" -ge 1 ]]; then
    printf '%s/%s' "$dts_base_path" "$copy_pattern"
    return
  fi

  # Pattern 3: All other cases, e.g., dts_copy_pattern=broadcom
  printf ' -r %s/%s' "$dts_base_path" "$copy_pattern"
  return
}

# After compiling a Linux kernel, it generates a binary file required to copy
# in the deploy phase. This function identifies the generated binary and
# returns its name.
#
# Return:
# Return the kernel binary name
function get_kernel_binary_name()
{
  local kbuild_prefix="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  local arch_target="${build_config[arch]:-${configurations[arch]}}"
  local kernel_binary_file_name

  [[ -n "$kbuild_prefix" ]] && kbuild_prefix="${kbuild_prefix}/"

  # Try to find the latest generated kernel image
  kernel_binary_file_name=$(find "${kbuild_prefix}arch/${arch_target}/boot/" -name '*Image' \
    -printf '%T+ %p\n' 2> /dev/null | sort -r | head -1)
  kernel_binary_file_name=$(basename "$kernel_binary_file_name")

  [[ -z "$kernel_binary_file_name" ]] && return 125 # ECANCELED

  printf '%s' "$kernel_binary_file_name"
}

# When deploying a new kernel, we usually want to include the config file
# associated with the specific kernel. This function is responsible for finding
# and changing anything necessary to send the .config file to the target
# machine.
#
# @kernel_name: Kernel name set by the user.
# @cache_base_kw_pkg_store_path: Cache folder path.
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return
# In case of success return 0, otherwise return an error code.
function get_config_file_for_deploy()
{
  local kernel_name="$1"
  local cache_base_kw_pkg_store_path="$2"
  local flag="$3"
  local kbuild_output_prefix="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  local config_local_version
  local config_path='.config'

  flag=${flag:-'SILENT'}

  if [[ -z "$kernel_name" ]]; then
    return 22 # EINVAL
  fi

  # Check env
  if [[ -n "$kbuild_output_prefix" ]]; then
    config_path="${kbuild_output_prefix}/.config"
  fi

  if [[ -f "$config_path" ]]; then
    config_local_version=$(sed -nr '/CONFIG_LOCALVERSION=/s/CONFIG_LOCALVERSION="(.*)"/\1/p' "$config_path")

    if [[ "$kernel_name" =~ $config_local_version.*$ ]]; then
      cmd="cp ${config_path} ${cache_base_kw_pkg_store_path}/config-${kernel_name}"
      cmd_manager "$flag" "$cmd"
    fi

    return
  fi

  warning 'Undefined .config file for the target kernel.'
}

# Get the kernel image with the default name for the target architecture to be
# used in the deploy package. For example, x86 usually uses vmlinuz and ARM
# uses Image.
#
# @arch: Target architecture
# @kernel_name: Kernel name used for the binary image
# @kernel_binary_file_name: The actual binary name
# @base_kernel_image_path: Base bath to the kernel binary in the kernel tree
# @base_kw_deploy_store_path: Path to store the binary file to be deployed
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# In case of error return an errno code
function get_kernel_image_for_deploy()
{
  local arch="$1"
  local kernel_name="$2"
  local kernel_binary_file_name="$3"
  local base_kernel_image_path="$4"
  local base_kw_deploy_store_path="$5"
  local -n _final_kernel_binary_image_name="$6"
  local flag="$7"
  local kernel_name_arch
  local config_kernel_img_name="${build_config[kernel_img_name]:-${configurations[kernel_img_name]}}"
  local kbuild_output_prefix="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"

  flag=${flag:-'SILENT'}

  # Check env
  if [[ -n "$kbuild_output_prefix" ]]; then
    base_kernel_image_path="${kbuild_output_prefix}/${base_kernel_image_path}"
  fi

  # Check if kernel image exits
  if [[ ! -f ${base_kernel_image_path}/${kernel_binary_file_name} ]]; then
    return 2 # ENOENT
  fi

  case "$arch" in
    'arm' | 'arm64')
      _final_kernel_binary_image_name="${config_kernel_img_name}-${kernel_name}"
      ;;
    *)
      # X86 system usually uses vmlinuz
      _final_kernel_binary_image_name="vmlinuz-${kernel_name}"
      ;;
  esac

  cmd="cp ${base_kernel_image_path}/${kernel_binary_file_name}"
  cmd+=" ${base_kw_deploy_store_path}/${_final_kernel_binary_image_name}"
  cmd_manager "$flag" "$cmd"
}

# This function handles dtb files for a specific device and overlay.
#
# @arch: Target architecture
# @base_boot_path: Base bath to the kernel binary in the kernel tree
# @base_kw_deploy_store_path: Path to store the binary file to be deployed
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
function get_dts_and_dtb_files_for_deploy()
{
  local arch="$1"
  local base_boot_path="$2"
  local base_kw_deploy_store_path="$3"
  local flag="$4"
  local dts_base_path
  local copy_pattern
  local kbuild_output_prefix="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"

  flag=${flag:-'SILENT'}

  dts_base_path="${base_boot_path}/dts"

  # Check env
  if [[ -n "$kbuild_output_prefix" ]]; then
    dts_base_path="${kbuild_output_prefix}/${dts_base_path}"
  fi

  if [[ -d "$dts_base_path" ]]; then
    # Simple pattern, e.g., copy_pattern='broadcom/*'
    copy_pattern=$(compose_copy_source_parameter_for_dtb "$arch")
    cmd_manager "$flag" "cp ${copy_pattern} ${base_kw_deploy_store_path}/"

    if [[ -d "${dts_base_path}/overlays" ]]; then
      cmd_manager "$flag" "mkdir -p ${base_kw_deploy_store_path}/overlays"
      cmd_manager "$flag" "cp ${dts_base_path}/overlays/*.dtbo ${base_kw_deploy_store_path}/overlays"
    fi
  fi
}

# Create metadata file with basic info that could be use during deploy
#
# @arch: Target architecture
# @kernel_name: Kernel name used for the binary image
# @kernel_binary_file_name: The actual binary name
# @base_kw_deploy_store_path: Path to store the binary file to be deployed
function create_pkg_metadata_file_for_deploy()
{
  local arch="$1"
  local kernel_name="$2"
  local kernel_binary_file_name="$3"
  local base_kw_deploy_store_path="$4"
  local cache_pkg_metadata_file_path

  cache_pkg_metadata_file_path="${base_kw_deploy_store_path}/kw.pkg.info"

  printf 'kernel_name=%s\n' "$kernel_name" > "${cache_pkg_metadata_file_path}"
  printf 'kernel_binary_image_file=%s\n' "$kernel_binary_file_name" >> "${cache_pkg_metadata_file_path}"
  printf 'architecture=%s\n' "$arch" >> "${cache_pkg_metadata_file_path}"
}

# This function is responsible for putting all the required boot files in a
# single place (~/.cache/kw/to_deploy) to be deployed to the /boot folder
# later. This function checks if there are dtb/dtbo files; if so, it moves
# those files.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @kernel_img_name Kernel image file name, e.g., bzImage or Image.
# @name Kernel name used during the deploy
# @arch Target device architecture
function build_kw_kernel_package()
{
  local -n _return_tar_path="$1"
  local -n _kernel_binary_image_name="$2"
  local flag="$3"
  local final_kernel_binary_image_name
  local arch="${build_config[arch]:-${configurations[arch]}}"
  local config_kernel_img_name="${build_config[kernel_img_name]:-${configurations[kernel_img_name]}}"
  local kbuild_output_prefix="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  local cache_base_kw_pkg_store_path
  local kernel_tree_boot_folder_path
  local cache_kw_pkg_tar_file_path
  local cache_kw_pkg_modules_path
  local kernel_binary_file_name
  local config_local_version
  local cache_to_deploy_path
  local output_kbuild_path
  local compression_type
  local kernel_name

  flag=${flag:-'SILENT'}

  if [[ -n "$kbuild_output_prefix" ]]; then
    kbuild_output_prefix="${kbuild_output_prefix}/"
    output_kbuild_path=" O=${kbuild_output_prefix} --silent"
  fi

  # Preparing metadata
  kernel_binary_file_name=$(get_kernel_binary_name "$flag")
  if [[ "$?" != 0 ]]; then
    complain "We could not find a valid kernel image at arch/${arch}/boot"
    complain 'Please, check if your compilation successfully completed or'
    complain 'check your kworkflow.config'
    exit 125 # ECANCELED
  fi

  kernel_name=$(eval "make kernelrelease${output_kbuild_path}")
  compression_type="${deploy_config[deploy_default_compression]}"
  cache_to_deploy_path="${KW_CACHE_DIR}/${LOCAL_TO_DEPLOY_DIR}"
  kernel_tree_boot_folder_path="arch/${arch}/boot"

  # Build package paths
  cache_base_kw_pkg_store_path="${cache_to_deploy_path}/kw_pkg"
  cache_kw_pkg_modules_path="${cache_base_kw_pkg_store_path}/modules"
  cache_kw_pkg_tar_file_path="${cache_to_deploy_path}/${kernel_name}.kw.tar"

  # Ensure that we will not add anything else in the package
  if [[ -n "${KW_CACHE_DIR}" && -n "${LOCAL_TO_DEPLOY_DIR}" &&
    -x "${KW_CACHE_DIR}/${LOCAL_TO_DEPLOY_DIR}" ]]; then
    rm -rf "${cache_to_deploy_path:?}/*"
  fi

  # Centralizing kernel files in a single place
  mkdir -p "$cache_base_kw_pkg_store_path"
  mkdir -p "$cache_kw_pkg_modules_path"

  # 1. Prepare modules
  modules_install_to "${cache_kw_pkg_modules_path}" "$flag"

  # 2. Copying .config file, we don't want to mislead developers by deploying
  # the wrong config file.
  get_config_file_for_deploy "$kernel_name" "${cache_base_kw_pkg_store_path}"
  if [[ "$?" == 22 ]]; then
    complain 'Kernel name not specified for get_config_file_for_deploy'
    return 22 # EINVAL
  fi

  # 3. Copy kernel image
  get_kernel_image_for_deploy "$arch" "$kernel_name" "$kernel_binary_file_name" "$kernel_tree_boot_folder_path" "$cache_base_kw_pkg_store_path" final_kernel_binary_image_name
  if [[ "$?" == 2 ]]; then
    complain "Kernel image was not found at: ${kernel_tree_boot_folder_path}"
    return 2 # ENOENT
  fi
  _kernel_binary_image_name="$final_kernel_binary_image_name"
  # 4. If we have dtb files, let's copy it
  get_dts_and_dtb_files_for_deploy "$arch" "$kernel_tree_boot_folder_path" "$cache_base_kw_pkg_store_path"

  # 5. Build metadata file
  create_pkg_metadata_file_for_deploy "$arch" "$kernel_name" "$final_kernel_binary_image_name" \
    "$cache_base_kw_pkg_store_path"

  # 6. Generate tarball
  generate_tarball "${cache_to_deploy_path}" "$cache_kw_pkg_tar_file_path" \
    "$compression_type" 'kw_pkg' "$flag"

  _return_tar_path="$cache_kw_pkg_tar_file_path"
}

function human_install_kernel_message()
{
  local ret="$1"
  local flag="$2"

  case "$ret" in
    2) # ENOENT
      complain 'Failed to uncompress kw package in the target system'
      ;;
    22) # EINVAL
      complain 'Invalid kernel name in the kw package'
      ;;
    68) # EADV
      complain 'Unable to correctly uncompress kw package in the target system'
      ;;
    125) # ECANCELED
      complain 'VM is unmount'
      ;;
  esac

  return "$ret"
}

# This function behaves like a kernel installation manager. It handles some
# parameters, and it also prepares to deploy the new kernel in the target
# machine.
#
# @reboot If this value is equal 1, it means reboot machine after kernel
#         installation.
# @name Kernel name to be deployed.
#
# Note:
# * Take a look at the available kernel plugins at: src/plugins/kernel_install
# * This function supposes that prepare_host_deploy_dir and prepare_remote_dir
# were invoked before.
function run_kernel_install()
{
  local return_tar_path="$1"
  local kernel_binary_image_name="$2"
  local flag="$3"
  local distro='none'
  local arch_target="${build_config[arch]:-${configurations[arch]}}"
  local kbuild_prefix="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  local reboot="${options_values['REBOOT']}"
  local target="${options_values['TARGET']}"
  local user="${remote_parameters['REMOTE_USER']}"
  local kernel_binary_file_name
  local cmd_parameters
  local remote
  local port
  local cmd

  [[ -n "$kbuild_prefix" ]] && kbuild_prefix="${kbuild_prefix}/"

  # We have to guarantee some default values values
  flag=${flag:-'SILENT'}

  case "$target" in
    2) # LOCAL_TARGET
      distro=$(detect_distro '/')

      if [[ "$distro" =~ 'none' ]]; then
        complain 'Unfortunately, there is no support for the target distro'
        return 95 # ENOTSUP
      fi

      # Local Deploy
      if [[ $(id --user) == 0 ]]; then
        complain 'kw deploy --local should not be run as root'
        return 1 # EPERM
      fi

      include "${KW_PLUGINS_DIR}/kernel_install/${distro}.sh"
      include "${KW_PLUGINS_DIR}/kernel_install/utils.sh"
      update_deploy_variables # Ensure that we are using the right variable

      say '* Moving kernel package for local deploy'
      cmd_manager "$flag" "mv ${return_tar_path} ${KW_DEPLOY_TMP_FILE}"

      install_kernel "$distro" "$reboot" 'local' "$flag"
      human_install_kernel_message "$?"
      return "$?"
      ;;
    3) # REMOTE_TARGET
      distro_info=$(which_distro "$remote" "$port" "$user")
      distro=$(detect_distro '/' "$distro_info")
      release=$(basename "$return_tar_path")

      say "* Sending kernel package (${release}) to the remote"
      cp2remote "$flag" "$return_tar_path" "$KW_DEPLOY_TMP_FILE"

      # Deploy
      cmd_parameters="${distro} ${reboot} 'remote' ${flag}"
      cmd="$REMOTE_INTERACE_CMD_PREFIX"
      cmd+=" --kernel-update $cmd_parameters"

      cmd_remotely "$cmd" "$flag" "$remote" "$port"
      human_install_kernel_message "$?"
      return "$?"
      ;;
  esac
}

# This function gets raw data and based on that fill out the options values to
# be used in another function.
#
# @raw_options String with all user options
#
# Return:
# In case of successful return 0, otherwise, return 22.
#
function parse_deploy_options()
{
  local enable_collect_param=0
  local remote
  local options
  local long_options='remote:,local,reboot,no-reboot,modules,list,ls-line,uninstall:'
  long_options+=',list-all,force,setup,verbose,create-package,from-package:'
  local short_options='r,m,l,s,u:,a,f,v,p,F:'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw deploy' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']=''
  options_values['TEST_MODE']='SILENT'
  options_values['UNINSTALL']=''
  options_values['UNINSTALL_FORCE']=''
  options_values['MODULES']=0
  options_values['LS_LINE']=0
  options_values['LS']=0
  # 0: not specified in cmd options   1: --reboot   2: --no-reboot
  options_values['REBOOT']=0
  options_values['MENU_CONFIG']='nconfig'
  options_values['LS_ALL']=''
  options_values['SETUP']=''
  options_values['VERBOSE']=''
  options_values['CREATE_PACKAGE']=''
  options_values['FROM_PACKAGE']=''

  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_USER']=''

  # Set basic default values
  if [[ -n ${deploy_config[default_deploy_target]} ]]; then
    local config_file_deploy_target=${deploy_config[default_deploy_target]}
    options_values['TARGET']=${deploy_target_opt[$config_file_deploy_target]}
  else
    options_values['TARGET']="$REMOTE_TARGET"
  fi

  if [[ ${deploy_config[reboot_after_deploy]} == 'yes' ]]; then
    options_values['REBOOT']=1
  fi

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']="Invalid remote: $remote"
    return 22 # EINVAL
  fi

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --remote)
        populate_remote_info "$2"
        if [[ "$?" == 22 ]]; then
          options_values['ERROR']="Invalid remote: $2"
          return 22 # EINVAL
        fi
        options_values['TARGET']="$REMOTE_TARGET"
        shift 2
        ;;
      --local)
        options_values['TARGET']="$LOCAL_TARGET"
        shift
        ;;
      --reboot | -r)
        options_values['REBOOT']=1
        shift
        ;;
      --no-reboot)
        options_values['REBOOT']=0
        shift
        ;;
      --modules | -m)
        options_values['MODULES']=1
        shift
        ;;
      --list | -l)
        options_values['LS']=1
        shift
        ;;
      --list-all | -a)
        options_values['LS_ALL']=1
        shift
        ;;
      --ls-line | -s)
        options_values['LS_LINE']=1
        shift
        ;;
      --setup)
        options_values['SETUP']=1
        shift
        ;;
      --uninstall | -u)
        if [[ "$2" =~ ^-- ]]; then
          options_values['ERROR']='Uninstall requires a kernel name'
          return 22 # EINVAL
        fi
        options_values['UNINSTALL']+="$2"
        shift 2
        ;;
      --verbose | -v)
        options_values['VERBOSE']=1
        shift
        ;;
      --force | -f)
        options_values['UNINSTALL_FORCE']=1
        shift
        ;;
      --create-package | -p)
        options_values['CREATE_PACKAGE']=1
        shift
        ;;
      --from-package | -F)
        options_values['FROM_PACKAGE']+="$2"
        shift 2
        ;;
      --) # End of options, beginning of arguments
        shift
        ;;
      TEST_MODE)
        options_values['TEST_MODE']='TEST_MODE'
        shift
        ;;
      *)
        options_values['ERROR']="Unrecognized argument: $1"
        return 22 # EINVAL
        shift
        ;;
    esac
  done

  case "${options_values['TARGET']}" in
    1 | 2 | 3) ;;

    *)
      options_values['ERROR']="Invalid target value: ${options_values['TARGET']}"
      return 22 # EINVAL
      ;;
  esac
}

function deploy_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'deploy'
    return
  fi
  printf '%s\n' 'kw deploy:' \
    '  deploy - installs kernel and modules:' \
    '  deploy (--remote <remote>:<port> | --local) - choose target' \
    '  deploy (--reboot | -r) - reboot machine after deploy' \
    '  deploy (--no-reboot) - do not reboot machine after deploy' \
    '  deploy (--verbose | -v) - show a detailed output' \
    '  deploy (--setup) - set up target machine for deploy' \
    '  deploy (--modules | -m) - install only modules' \
    '  deploy (--uninstall | -u) [(--force | -f)] <kernel-name>,... - uninstall given kernels' \
    '  deploy (--list | -l) - list kernels' \
    '  deploy (--ls-line | -s) - list kernels separeted by commas' \
    '  deploy (--list-all | -a) - list all available kernels' \
    '  deploy (--create-package | -p) - Create kw package' \
    '  deploy (--from-package | -F) - Deploy from kw package'
}

load_build_config
load_deploy_config
load_kworkflow_config
load_notification_config
