# In this file, you can find common operations used across different features.
# For example, the target machine setup operations are shared between deploy
# and get-device-info, hence those functions are located in this file.

include "${KW_LIB_DIR}/lib/remote.sh"
include "${KW_LIB_DIR}/lib/distros.sh"
include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

# To make the deploy to a remote machine straightforward, we create a directory
# on the host that will be used for centralizing files required for the new
# deploy.
declare -g REMOTE_KW_DEPLOY
declare -g KW_STATUS_BASE_PATH
declare -g KW_DEPLOY_TMP_FILE
declare -g REMOTE_INTERACE_CMD_PREFIX

# We now have a kw directory visible for users in the home directory, which is
# used for saving temporary files to be deployed in the target machine.
declare -g LOCAL_TO_DEPLOY_DIR
declare -g LOCAL_REMOTE_DIR

function update_deploy_global_variables()
{
  local kw_remote_path="${deploy_config[kw_files_remote_path]}"
  local kw_tmp_files="${deploy_config[deploy_temporary_files_path]}"

  REMOTE_KW_DEPLOY="${kw_remote_path:-$REMOTE_KW_DEPLOY}"
  KW_STATUS_BASE_PATH="${deploy_config[kw_status_base_path]}"
  KW_DEPLOY_TMP_FILE="${deploy_config[kw_deploy_tmp_file]}"
  LOCAL_TO_DEPLOY_DIR="${deploy_config[local_to_deploy_dir]}"
  LOCAL_REMOTE_DIR="${deploy_config[local_remote_dir]}"
  KW_DEPLOY_TMP_FILE="${kw_tmp_files:-$KW_DEPLOY_TMP_FILE}"

  # We should ensure that some of the global variables are empty. If any
  # variable is empty, we must provide a warning and set a default path.
  if [[ -z "$REMOTE_KW_DEPLOY" ]]; then
    REMOTE_KW_DEPLOY='/opt/kw'
  fi

  if [[ -z "$KW_DEPLOY_TMP_FILE" ]]; then
    KW_DEPLOY_TMP_FILE='/tmp/kw'
  fi

  REMOTE_INTERACE_CMD_PREFIX="bash ${REMOTE_KW_DEPLOY}/kw_remote_proxy_hub.sh"
  REMOTE_INTERACE_CMD_PREFIX+=" --kw-path '${REMOTE_KW_DEPLOY}' --kw-tmp-files '${KW_DEPLOY_TMP_FILE}'"
}

# This is the core of setting up a target machine to ensure it is ready for
# deploy. In a few words, this function will invoke ssh configuration, remote
# folder setup, distro-specific code, and update setup log. Notice that this
# function checks if the target machine needs to be set up or not.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# Return 0 in case of success, otherwise, it return a code error
function target_machine_setup()
{
  local target="$1"
  local flag="$2"
  local cmd
  local ret

  flag=${flag:-'SILENT'}

  update_deploy_global_variables

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

# This function is responsible for checking the latest status for the deploy
# setup. If it was already done, this function returns 0; otherwise, it will
# return another value that expresses the necessity of setting up the target
# machine.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# Return 0 if the setup was done before, or 2 if not.
function check_setup_status()
{
  local target="$1"
  local flag="$2"
  local cmd="test -f ${KW_STATUS_BASE_PATH}/kw_status"
  local ret

  flag=${flag:-'SILENT'}

  case "$target" in
    2) # LOCAL target
      cmd_manager "$flag" "$cmd"
      ret="$?"
      ;;
    3) # REMOTE_TARGET
      cmd_remotely "$flag" "$cmd"
      ret="$?"
      ;;
  esac

  if [[ "$ret" != 0 ]]; then
    return 2 # ENOENT
  fi
}


# To deploy a new kernel or module, we have to prepare a directory in the
# remote machine that will accommodate a set of files that we need to update
# the kernel. This function checks if we support the target distribution and
# prepared the remote machine for receiving the new kernel. Finally, it creates
# a directory inside the remote machine (check "$REMOTE_KW_DEPLOY") and prepare
# it for deploy.
#
# @remote: IP address of the target machine (default from config file)
# @port: Destination for sending the file (default from config file)
# @user: User in the host machine. Default value is "root" (default from config file)
# @first_deploy: Force the use of scp instead of rsync. This is useful for the
#                first deploy since the target machine does not have any kw
#                file yet.
# @flag: How to display a command, default is SILENT
function prepare_remote_dir()
{
  local remote="${1:-${remote_parameters['REMOTE_IP']}}"
  local port="${2:-${remote_parameters['REMOTE_PORT']}}"
  local user="${3:-${remote_parameters['REMOTE_USER']}}"
  local first_deploy="$4"
  local flag="$5"
  local kw_deploy_cmd="mkdir --parents ${REMOTE_KW_DEPLOY}"
  local kernel_plugin_files="${KW_PLUGINS_DIR}/kernel_install/*"
  local kw_lib_files="${KW_SRC_LIB_DIR}"
  local distro=''
  local remote_file=${remote_parameters['REMOTE_FILE']}
  local remote_file_host=${remote_parameters['REMOTE_FILE_HOST']}
  local cmd_plugin
  local cmd_lib

  flag=${flag:-'SILENT'}

  distro=$(which_distro "$remote" "$port" "$user" "$flag")
  if [[ "$distro" =~ 'none' ]]; then
    complain "Unfortunately, there's no support for '${distro}'"
    exit 95 # ENOTSUP
  fi

  # Send required scripts for running the deploy inside the target machine
  # Note: --archive will force the creation of $REMOTE_KW_DEPLOY in case it
  # does not exits
  if [[ -z "$first_deploy" ]]; then
    cp2remote "$flag" "$kernel_plugin_files" "$REMOTE_KW_DEPLOY" '--archive' "$remote" "$port" "$user" 'quiet'
    cp2remote "$flag" "$kw_lib_files" "${REMOTE_KW_DEPLOY}" '--archive' "$remote" "$port" "$user" 'quiet'
  else
    # TODO: If we find a way to install rsync first, we could get rid of this
    # entire block.
    #
    # First deploy should use ssh since rsync might not be available
    say '* Sending kw to the remote'
    cmd_remotely "$flag" "mkdir --parents ${REMOTE_KW_DEPLOY}/lib"

    if [[ -n "$remote_file" && -n "$remote_file_host" ]]; then
      cmd_plugin="scp -q -F ${remote_file} ${kernel_plugin_files} ${remote_file_host}:${REMOTE_KW_DEPLOY}"
      cmd_lib="scp -r -q -F ${remote_file} ${kw_lib_files} ${remote_file_host}:${REMOTE_KW_DEPLOY}"
    else
      cmd_plugin="scp -q ${kernel_plugin_files} ${user}@${remote}:${REMOTE_KW_DEPLOY}"
      cmd_lib="scp -r -q ${kw_lib_files} ${user}@${remote}:${REMOTE_KW_DEPLOY}"
    fi

    cmd_manager "$flag" "$cmd_plugin"
    cmd_manager "$flag" "$cmd_lib"
  fi

  # Removes temporary directory if already existent
  cmd_remotely "$flag" "rm --preserve-root=all --recursive --force -- ${KW_DEPLOY_TMP_FILE}"
  # Create temporary folder
  cmd_remotely "$flag" "mkdir --parents ${KW_DEPLOY_TMP_FILE}"
}

# Create the temporary folder for local deploy.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
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

  # Create /opt/kw folder
  # TODO: Rename REMOTE_KW_DEPLOY to something more generic since it is used
  # for local or remote. Keep in mind that you'll need to replace
  # REMOTE_KW_DEPLOY in this file and in the plugins/kernel_install.
  cmd_manager "$flag" "sudo -E mkdir --parents ${REMOTE_KW_DEPLOY}"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    return 22 # EINVAL
  fi
}

# We want to avoid setting up the same thing repeatedly; for this reason, kw
# creates a log status file at the end of the setup. This function generates
# the status file with the target code, date, and time information.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
function update_status_log()
{
  local target="$1"
  local flag="$2"
  local cmd=''
  local log_date=''
  local metadata_string=''
  local kw_status_path=''

  flag=${flag:-'SILENT'}

  log_date=$(date +'%m/%d/%Y-%H:%M:%S')

  [[ "$flag" == 'TEST_MODE' ]] && log_date='TEST_MODE'

  metadata_string="printf '%s;%s\n' '${target}' '${log_date}'"
  kw_status_path="${KW_STATUS_BASE_PATH}/kw_status"

  case "$target" in
    2) # LOCAL_TARGET
      cmd="${metadata_string} | sudo -E tee --append ${kw_status_path}"
      cmd_manager "${flag}" "${cmd}"
      ;;
    3) # REMOTE_TARGET
      cmd="${metadata_string} >> ${kw_status_path}"
      cmd_remotely "$flag" "$cmd"
      ;;
  esac
}

# Every distro family has its specific idiosyncrasy; for this reason, in the
# plugin folder, we have a code per distro supported by kw. This function is
# the entry point to call the specific code for the target distro.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
function prepare_distro_for_deploy()
{
  local target="$1"
  local flag="$2"
  local distro
  local cmd

  flag=${flag:-'SILENT'}

  say '-> Basic distro set up'$'\n'

  case "$target" in
    2) # LOCAL_TARGET
      distro=$(detect_distro '/')
      # Distro must be loaded first to ensure the right variables
      include "${KW_PLUGINS_DIR}/kernel_install/${distro}.sh"
      include "${KW_PLUGINS_DIR}/kernel_install/utils.sh"

      distro_deploy_setup "$flag" "${target}"
      ;;
    3) # REMOTE_TARGET
      cmd="$REMOTE_INTERACE_CMD_PREFIX"
      cmd+=" --deploy-setup ${flag} ${target}"

      cmd_remotely "$flag" "$cmd"
      ;;
  esac
}

