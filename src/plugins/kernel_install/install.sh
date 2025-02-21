# This file centralizes all the steps to install a new kernel in the target
# machine. Keep in mind that those steps should work both remotely and locally.
# Also, this file uses many of the bootloader operations.

# kw package metadata
declare -gA kw_package_metadata
declare -g LIB_MODULES_PATH='/lib/modules'

# The install_kernel function works as a template for each step of the kernel
# installation. This function calls the specific bootloader and distro
# operations via abstractions previously loaded by other files (e.g.,
# src/deploy or kw_remote_proxy_hub.sh).
#
# @distro: Distro name
# @reboot: Set to 1 if user wants the system to be reboot.
# @target: Remote our Local.
# @force: If set, not questions are prompted.
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# If everything is alright, it returns 0. Otherwise it can return:
# - 2 (ENOENT) or 68 (EADV) for uncompression issues. Erros from uncompress
# function.
# - 22 (EINVAL) if the kernel name is empty
function install_kernel()
{
  local distro="$1"
  local reboot="$2"
  local target="$3"
  local force="$4"
  local flag="$5"
  local sudo_cmd=''
  local cmd=''
  local path_test=''
  local verbose_cp
  local ret

  flag=${flag:-'SILENT'}
  target=${target:-'remote'}

  [[ "$flag" == 'VERBOSE' ]] && verbose_cp='-v'
  [[ "$flag" == 'TEST_MODE' ]] && path_test="$PWD"

  if [[ "$target" == 'local' ]]; then
    sudo_cmd='sudo --preserve-env '
  fi

  # Uncompress kw package
  uncompress_kw_package "$flag"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    return "$ret"
  fi

  # Parser config metadata
  parse_kw_package_metadata ''

  name=${kw_package_metadata['kernel_name']}
  arch=${kw_package_metadata['architecture']}
  kernel_image_name=${kw_package_metadata['kernel_binary_image_file']}

  if [[ -z "$name" ]]; then
    printf '%s\n' 'Invalid name'
    return 22 # EINVAL
  fi

  install_modules "$target" "$flag"

  # Copy kernel image
  if [[ -f "${path_test}/boot/vmlinuz-${name}" && "${kw_package_metadata['previous_kernel_backup']}" == 'yes' ]]; then
    cmd="${sudo_cmd} cp ${path_test}/boot/vmlinuz-${name} ${path_test}/boot/vmlinuz-${name}.old"
    cmd_manager "$flag" "$cmd"
  fi

  # Copy kernel config
  cmd="${sudo_cmd}cp ${KW_DEPLOY_TMP_FILE}/kw_pkg/config-${name} /boot/"
  cmd_manager "$flag" "$cmd"

  # Update kernel image in the /boot
  cmd="${sudo_cmd}cp ${KW_DEPLOY_TMP_FILE}/kw_pkg/${kernel_image_name} /boot/"
  cmd_manager "$flag" "$cmd"

  # Each distro has their own way to update their bootloader
  update_bootloader "$flag" "$name" "$target" "$kernel_image_name" "$distro" "$path_test" '' "$force"
  ret="$?"

  if [[ "$ret" != 0 ]]; then
    printf 'kw was not able to update the target bootloader\n'
    exit "$ret"
  fi

  # Registering a new kernel
  # TODO: Drop me in the future
  migrate_old_kernel_list

  if [[ ! -f "$INSTALLED_KERNELS_PATH" ]]; then
    cmd_manager "$flag" "touch ${INSTALLED_KERNELS_PATH}"
  fi

  # See shellcheck warning SC2024: sudo doesn't affect redirects. That
  # is why we use tee. Also note that the stdin is passed to the eval
  # inside cmd_manager.
  cmd="${sudo_cmd}grep --fixed-strings --line-regexp --quiet ${name} ${INSTALLED_KERNELS_PATH}"
  cmd_manager "$flag" "$cmd"
  if [[ "$?" != 0 ]]; then
    cmd="${sudo_cmd} tee --append '${INSTALLED_KERNELS_PATH}' > /dev/null"
    printf '%s\n' "$name" | cmd_manager "$flag" "$cmd"
  fi

  # Reboot
  if [[ "$reboot" == '1' ]]; then
    cmd="${sudo_cmd} reboot"
    reboot_machine "$reboot" "$target" "$flag"
  fi
}

# Uncompress kw package
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# In case of failure, return an errno code:
# - ENOENT (2): kw package was not find
# - EADV (68): Failed to uncompress
function uncompress_kw_package()
{
  local flag="$1"
  local kw_pkg_tar_path="${KW_DEPLOY_TMP_FILE}"
  local kw_pkg_modules_path="${KW_DEPLOY_TMP_FILE}/kw_pkg/modules/lib/modules"
  local kw_package_file_name
  local cmd
  local ret

  flag=${flag:-'SILENT'}

  kw_package_file_name=$(find "${KW_DEPLOY_TMP_FILE}" -name '*.kw.tar')
  kw_package_file_name=$(basename "$kw_package_file_name")
  kw_pkg_tar_path+="/${kw_package_file_name}"

  if [[ ! -f "$kw_pkg_tar_path" ]]; then
    return 2 # ENOENT
  fi

  # Clean target folder
  if [[ -d ${KW_DEPLOY_TMP_FILE}/kw_pkg ]]; then
    cmd_manager "$flag" "rm --recursive --force ${KW_DEPLOY_TMP_FILE}/kw_pkg"
  fi

  cmd="tar --touch --auto-compress --extract --file='${kw_pkg_tar_path}' --directory='${KW_DEPLOY_TMP_FILE}' --no-same-owner"
  cmd_manager "$flag" "$cmd"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    printf 'Warning (%d): Could not extract module archive.\n' "$ret"
    return 68 # EADV
  fi
}

# This function read the configuration file and make the parser of the data on
# it. For more information about the configuration file, take a look at
# "etc/kworkflow.config" in the kworkflow directory.
#
# @parameter: This function expects a path to the configuration file.
#
# Return:
# Return an errno code in case of failure.
function parse_kw_package_metadata()
{
  local config_path="$1"
  local config_array='kw_package_metadata'
  local value

  if [[ -z "$config_path" ]]; then
    config_path="${KW_DEPLOY_TMP_FILE}/kw_pkg/kw.pkg.info"
    if [[ ! -f "$config_path" ]]; then
      return 22 # EINVAL
    fi
  fi

  if [ ! -f "$config_path" ]; then
    return 22 # EINVAL
  fi

  # shellcheck disable=SC2162
  while read line; do
    # Line started with # or that are blank should be ignored
    [[ "$line" =~ ^# || "$line" =~ ^$ ]] && continue

    if grep -qF = <<< "$line"; then
      varname="$(cut --delimiter='=' --fields=1 <<< "$line" | tr --delete '[:space:]')"
      value="$(cut --delimiter='=' --fields=2- <<< "${line%#*}")"
      value="$(sed --expression='s/^[[:space:]]*//' --expression='s/[[:space:]]*$//' <<< "$value")"

      eval "${config_array}"'["$varname"]="$value"'
    fi
  done < "$config_path"
}

# Synchronize new modules files in the target machine
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# In case of failure, return an errno code.
function install_modules()
{
  local target="$1"
  local flag="$2"
  local uncompressed_kw_pkg="${KW_DEPLOY_TMP_FILE}/kw_pkg"
  local kw_pkg_modules_path="${KW_DEPLOY_TMP_FILE}/kw_pkg/modules/lib/modules"
  local sudo_cmd
  local cmd
  local ret

  flag=${flag:-'SILENT'}

  if [[ "$target" == 'local' ]]; then
    sudo_cmd='sudo --preserve-env '
  fi

  # 1. If kw package was not extracted yet, do it now
  if [[ ! -d "$uncompressed_kw_pkg" ]]; then
    uncompress_kw_package "$flag"
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      return "$ret" # ENOENT
    fi
  fi

  # 2. Move new modules to the right place
  cmd="${sudo_cmd}rsync --archive ${kw_pkg_modules_path}/* ${LIB_MODULES_PATH}"
  cmd_manager "$flag" "$cmd"
}
