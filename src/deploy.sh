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
include "$KW_LIB_DIR/vm.sh"
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

  if [[ "$list" == 1 || "$single_line" == 1 || "$list_all" == 1 ]]; then
    say 'Available kernels:'
    start=$(date +%s)
    run_list_installed_kernels "$flag" "$single_line" "$target" "$list_all"
    end=$(date +%s)

    runtime=$((end - start))
    statistics_manager 'list' "$runtime"
    exit "$?"
  fi

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  update_deploy_variables

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

  prepare_host_deploy_dir

  # If user request --setup, we don't need to do anything else
  if [[ -n "$setup" ]]; then
    [[ "$ret" == 0 ]] && success 'It looks like you are ready to use kw deploy.'
    return "$?"
  fi

  collect_target_info_for_deploy "$target" "$flag"

  if [[ -n "$uninstall" ]]; then
    start=$(date +%s)
    run_kernel_uninstall "$target" "$reboot" "$uninstall" "$flag" "$uninstall_force"
    end=$(date +%s)

    runtime=$((end - start))
    statistics_manager 'uninstall' "$runtime"
    return "$?"
  fi

  if ! is_kernel_root "$PWD"; then
    complain 'Execute this command in a kernel tree.'
    exit 125 # ECANCELED
  fi

  signal_manager 'cleanup' || warning 'Was not able to set signal handler'

  if [[ "$target" == "$VM_TARGET" ]]; then
    vm_mount
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      complain 'Please shutdown or umount your VM to continue.'
      exit "$ret"
    fi
  fi

  # NOTE: If we deploy a new kernel image that does not match with the modules,
  # we can break the boot. For security reason, every time we want to deploy a
  # new kernel version we also update all modules; maybe one day we can change
  # it, but for now this looks the safe option.
  start=$(date +%s)
  modules_install "$flag" "$target"
  modules_install_status="$?"
  end=$(date +%s)
  runtime=$((end - start))

  if [[ "$modules_install_status" != 0 ]]; then
    complain 'Something went wrong during the installation of the modules.'
    exit "$modules_install_status"
  fi

  if [[ "$modules" == 0 ]]; then
    start=$(date +%s)
    # Update name: release + alias
    name=$(make kernelrelease)

    run_kernel_install "$reboot" "$name" "$flag" "$target" '' "$build_and_deploy"
    end=$(date +%s)
    runtime=$((runtime + (end - start)))
    statistics_manager 'deploy' "$runtime"
  else
    statistics_manager 'Modules_deploy' "$runtime"
  fi

  if [[ "$target" == "$VM_TARGET" ]]; then
    # Umount VM if it remains mounted
    vm_umount
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
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
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
    1) # VM_TARGET
      printf 'TODO: VM: prepare_distro_for_deploy requires implementation\n'
      printf 'You might want to consider the remote option for your VM\n'
      ;;
    2) # LOCAL_TARGET
      distro=$(detect_distro '/')
      # Distro must be loaded first to ensure the right variables
      include "$KW_PLUGINS_DIR/kernel_install/$distro.sh"
      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"

      distro_deploy_setup "$flag"
      ;;
    3) # REMOTE_TARGET
      local cmd="$REMOTE_INTERACE_CMD_PREFIX"
      cmd+=" --deploy-setup $flag"

      cmd_remotely "$cmd" "$flag"
      ;;
  esac
}

# We want to avoid setting up the same thing repeatedly; for this reason, kw
# creates a log status file at the end of the setup. This function generates
# the status file with the target code, date, and time information.
#
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
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
    1)
      echo "TODO: update_status_log"
      ;;
    2) # VM and LOCAL_TARGET
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
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
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
    1 | 2) # VM and LOCAL target
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
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
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

  if [[ "$target" == "$VM_TARGET" ]]; then
    cmd="guestfish --rw -a ${vm_config[qemu_path_image]} run : \
      mount /dev/sda1 / : mkdir-p $REMOTE_KW_DEPLOY"
    cmd_manager "$flag" "$cmd"
  fi

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

# We can include plugin scripts when dealing with local or VM deploy, which
# will override some path variables. Since this will be a common task, this
# function is intended to centralize these required updates.
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
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
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
    1) # VM_TARGET
      vm_mount

      if [ "$?" != 0 ]; then
        complain 'Did you check if your VM is running?'
        return 125 # ECANCELED
      fi

      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      list_installed_kernels "$flag" "$single_line" "$all" "${vm_config[mount_point]}"

      vm_umount
      ;;
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
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
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
    1) # VM_TARGET
      include "$KW_PLUGINS_DIR/kernel_install/bootloader_utils.sh"
      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      data=$(collect_deploy_info "$flag" "$target" "${vm_config[mount_point]}/")
      ;;
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
# @target Target machine Target machine Target machine Target machine
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
    1) # VM_TARGET
      printf '%s\n' 'UNINSTALL VM'
      ;;
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
# @target Target machine
#
# Note:
# This function supposes that prepare_host_deploy_dir and prepare_remote_dir
# were invoked before.
function modules_install()
{
  local flag="$1"
  local target="$2"
  local remote
  local port
  local distro
  local cmd
  local compression_type="${deploy_config[deploy_default_compression]}"
  local tarball_for_deploy_path

  flag=${flag:-'SILENT'}

  case "$target" in
    1) # VM_TARGET
      modules_install_to "${vm_config[mount_point]}" "$flag"
      ;;
    2) # LOCAL_TARGET
      modules_install_to '/lib/modules' "$flag" 'local'
      ;;
    3) # REMOTE_TARGET
      # 2. Send files modules
      modules_install_to "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR/" "$flag"

      release=$(get_kernel_release "$flag")
      generate_tarball "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR/lib/modules/" \
        "$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/$release.tar" \
        "$compression_type" "$release" "$flag"

      tarball_for_deploy_path="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/$release.tar"
      say "* Sending kernel modules ($release) to the remote"
      cp2remote "$flag" "$tarball_for_deploy_path" "$KW_DEPLOY_TMP_FILE"

      # 3. Deploy: Execute script
      cmd="$REMOTE_INTERACE_CMD_PREFIX"
      cmd+=" --modules $release.tar"
      cmd_remotely "$cmd" "$flag"
      ;;
  esac
}

function is_sign_module_enabled()
{
  grep --quiet --fixed-strings --line-regexp 'CONFIG_MODULE_SIG=y' "${PWD}/.config"
  [[ "$?" != 0 ]] && return 1
  return 0
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
  local sign_extra_line=1

  flag=${flag:-'SILENT'}

  if is_sign_module_enabled; then
    sign_extra_line=2
  fi

  if [[ ${deploy_config[strip_modules_debug_option]} == 'no' ]]; then
    strip_modules_debug=''
    grep --quiet --fixed-strings --line-regexp 'CONFIG_DEBUG_INFO=y' "${PWD}/.config"
    if [[ "$?" == 0 ]]; then
      load_module_text "${KW_ETC_DIR}/strings/deploy.txt"
      warning "${module_text_dictionary[large_initramfs_warning]}"
    fi
  fi

  if [[ "$local_deploy" == 'local' ]]; then
    cmd="sudo true && sudo -E make ${strip_modules_debug}modules_install"
  else
    cmd="make ${strip_modules_debug}INSTALL_MOD_PATH=$install_to modules_install"
  fi

  if [[ "$flag" != 'VERBOSE' && -f './modules.order' ]]; then
    total_lines=$(wc -l < './modules.order')
    # Multiply by two because we have the driver name and the signing line
    total_lines=$((total_lines * "$sign_extra_line"))
    cmd+=" | pv -p --line-mode --size $total_lines > /dev/null"
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

  copy_pattern="${deploy_config[dtb_copy_pattern]}"
  dts_base_path="arch/$arch_target/boot/dts"

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

# This function is responsible for putting all the required boot files in a
# single place (~/.cache/kw/to_deploy) to be deployed to the /boot folder
# later. This function checks if there are dtb/dtbo files; if so, it moves
# those files.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
# @kernel_img_name Kernel image file name, e.g., bzImage or Image.
# @name Kernel name used during the deploy
# @arch Target device architecture
function pack_kernel_files_and_send()
{
  local flag="$1"
  local target="$2"
  local kernel_binary_file_name="$3"
  local kernel_name="$4"
  arch_fallback="${build_config[arch]:-${configurations[arch]}}"
  local arch=${5:-$arch_fallback}
  local build_and_deploy="$6"
  local config_kernel_img_name="${build_config[kernel_img_name]:-${configurations[kernel_img_name]}}"
  local base_boot_path
  local config_path
  local config_local_version
  local cache_boot_files_path
  local compression_type
  local cache_to_deploy_path
  local dts_base_path
  local tar_file_path
  local kernel_name_arch

  config_path='.config'
  compression_type="${deploy_config[deploy_default_compression]}"
  cache_to_deploy_path="${KW_CACHE_DIR}/${LOCAL_TO_DEPLOY_DIR}"
  cache_boot_files_path="${cache_to_deploy_path}/boot"
  tar_file_path="${cache_to_deploy_path}/${name}_boot.tar"

  base_boot_path="arch/$arch/boot"
  dts_base_path="${base_boot_path}/dts"

  [[ -z "$config_kernel_img_name" ]] && config_kernel_img_name='kernel'

  # Centralizing kernel files in a single place
  mkdir -p "$cache_boot_files_path"

  # 1. Copying .config file, we don't want to mislead developers by deploying
  # the wrong config file.
  if [[ ! -f "$config_path" ]]; then
    warning 'Undefined .config file for the target kernel. Consider using kw bd'
  else
    config_local_version=$(sed -nr '/CONFIG_LOCALVERSION=/s/CONFIG_LOCALVERSION="(.*)"/\1/p' "$config_path")

    if [[ -n "$build_and_deploy" || "$kernel_name" =~ $config_local_version.*$ ]]; then
      cmd="cp $config_path ${cache_boot_files_path}/config-$kernel_name"
      cmd_manager "$flag" "$cmd"
    fi
  fi

  # 2. Copy kernel image
  case "$arch" in
    'arm' | 'arm64')
      kernel_name_arch="${config_kernel_img_name}-${kernel_name}"
      ;;
    *)
      # X86 system usually uses vmlinuz
      kernel_name_arch="vmlinuz-${kernel_name}"
      ;;
  esac

  cmd="cp ${base_boot_path}/${kernel_binary_file_name}"
  cmd+=" ${cache_boot_files_path}/${kernel_name_arch}"
  cmd_manager "$flag" "$cmd"

  # 3. If we have dtb files, let's copy it
  if [[ -d "$dts_base_path" ]]; then
    # Simple patter, e.g., copy_pattern='broadcom/*'
    copy_pattern=$(compose_copy_source_parameter_for_dtb "$arch")
    cmd_manager "$flag" "cp ${copy_pattern} ${cache_boot_files_path}/"

    if [[ -d "${dts_base_path}/overlays" ]]; then
      cmd_manager "$flag" "mkdir -p ${cache_boot_files_path}/overlays"
      cmd_manager "$flag" "cp ${dts_base_path}/overlays/*.dtbo ${cache_boot_files_path}/overlays"
    fi
  fi

  case "$target" in
    1) # VM_TARGET
      cmd="cp -r ${cache_to_deploy_path}/boot/* ${vm_config[mount_point]}/boot/"
      cmd_manager "$flag" "$cmd"
      ;;
    2) # LOCAL_TARGET
      cmd="sudo cp -r ${cache_to_deploy_path}/boot/* /boot/"
      cmd_manager "$flag" "$cmd"
      ;;
    3) # REMOTE_TARGET
      generate_tarball "${cache_to_deploy_path}" \
        "$tar_file_path" "$compression_type" 'boot' "$flag"

      cp2remote "$flag" "$tar_file_path" "$KW_DEPLOY_TMP_FILE"
      ;;
  esac
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
  local reboot="$1"
  local name="$2"
  local flag="$3"
  local target="$4"
  local user="${5:-${remote_parameters['REMOTE_USER']}}"
  local build_and_deploy="$6"
  local distro='none'
  local kernel_name="${build_config[kernel_name]:-${configurations[kernel_name]}}"
  local mkinitcpio_name="${configurations[mkinitcpio_name]}"
  local arch_target="${build_config[arch]:-${configurations[arch]}}"
  local kernel_img_name="${build_config[kernel_img_name]:-${configurations[kernel_img_name]}}"
  local kernel_binary_file_name
  local remote
  local port
  local config_local_version
  local cmd
  local cmd_parameters

  # We have to guarantee some default values values
  kernel_name=${kernel_img_name:-'nothing'}
  mkinitcpio_name=${mkinitcpio_name:-'nothing'}
  name=${name:-'kw'}
  flag=${flag:-'SILENT'}

  # Try to find the latest generated kernel image
  kernel_binary_file_name=$(find "arch/$arch_target/boot/" -name '*Image' \
    -printf '%T+ %p\n' 2> /dev/null | sort -r | head -1)
  kernel_binary_file_name=$(basename "$kernel_binary_file_name")
  if [[ -z "$kernel_binary_file_name" ]]; then
    complain "We could not find a valid kernel image at arch/$arch_target/boot"
    complain 'Please, check if your compilation successfully completed or'
    complain 'check your kworkflow.config'
    exit 125 # ECANCELED
  fi

  say '* Sending kernel boot files'
  pack_kernel_files_and_send "$flag" "$target" "$kernel_binary_file_name" \
    "$name" "$arch_target" "$build_and_deploy"

  case "$target" in
    1) # VM_TARGET
      distro=$(detect_distro "${vm_config[mount_point]}/")

      if [[ "$distro" =~ 'none' ]]; then
        complain 'Unfortunately, there is no support for the target distro'
        vm_umount
        exit 95 # ENOTSUP
      fi

      include "$KW_PLUGINS_DIR/kernel_install/$distro.sh"
      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      update_deploy_variables # Make sure we use the right variable values
      install_kernel "$name" "$distro" "$kernel_binary_file_name" "$reboot" "$arch_target" 'vm' "$flag"
      return "$?"
      ;;
    2) # LOCAL_TARGET
      distro=$(detect_distro '/')

      if [[ "$distro" =~ 'none' ]]; then
        complain 'Unfortunately, there is no support for the target distro'
        exit 95 # ENOTSUP
      fi

      # Local Deploy
      if [[ $(id -u) == 0 ]]; then
        complain 'kw deploy --local should not be run as root'
        exit 1 # EPERM
      fi

      include "$KW_PLUGINS_DIR/kernel_install/$distro.sh"
      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      update_deploy_variables # Ensure that we are using the right variable

      install_kernel "$name" "$distro" "$kernel_binary_file_name" "$reboot" "$arch_target" 'local' "$flag"
      return "$?"
      ;;
    3) # REMOTE_TARGET
      distro_info=$(which_distro "$remote" "$port" "$user")
      distro=$(detect_distro '/' "$distro_info")

      # Deploy
      cmd_parameters="$name $distro $kernel_binary_file_name $reboot $arch_target 'remote' $flag"
      cmd="$REMOTE_INTERACE_CMD_PREFIX"
      cmd+=" --kernel-update $cmd_parameters"

      cmd_remotely "$cmd" "$flag" "$remote" "$port"
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
  local long_options='remote:,local,vm,reboot,no-reboot,modules,list,ls-line,uninstall:'
  long_options+=',list-all,force,setup,verbose'
  local short_options='r,m,l,s,u:,a,f,v'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw deploy' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

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

  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_USER']=''

  # Set basic default values
  if [[ -n ${deploy_config[default_deploy_target]} ]]; then
    local config_file_deploy_target=${deploy_config[default_deploy_target]}
    options_values['TARGET']=${deploy_target_opt[$config_file_deploy_target]}
  else
    options_values['TARGET']="$VM_TARGET"
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
      --vm)
        options_values['TARGET']="$VM_TARGET"
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
    '  deploy (--remote <remote>:<port> | --local | --vm) - choose target' \
    '  deploy (--reboot | -r) - reboot machine after deploy' \
    '  deploy (--no-reboot) - do not reboot machine after deploy' \
    '  deploy (--verbose | -v) - show a detailed output' \
    '  deploy (--setup) - set up target machine for deploy' \
    '  deploy (--modules | -m) - install only modules' \
    '  deploy (--uninstall | -u) [(--force | -f)] <kernel-name>,... - uninstall given kernels' \
    '  deploy (--list | -l) - list kernels' \
    '  deploy (--ls-line | -s) - list kernels separeted by commas' \
    '  deploy (--list-all | -a) - list all available kernels'
}

load_vm_config
load_build_config
load_deploy_config
load_kworkflow_config
load_notification_config
