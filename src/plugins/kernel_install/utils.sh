declare -g INSTALLED_KERNELS_PATH='/boot/INSTALLED_KERNELS'
declare -g AB_ROOTFS_PARTITION='/dev/disk/by-partsets/self/rootfs'
declare -g LIB_MODULES_PATH='/lib/modules'

# kw package metadata
declare -gA kw_package_metadata

# Identify partition type
#
# @target_path By default, it is / but developers can set any path.
#
# Return:
# Return filesystem type
function detect_filesystem_type()
{
  local target_path=${1:-'/'}
  local file_system

  file_system=$(findmnt --first-only --noheadings --output FSTYPE "$target_path")

  printf '%s' "$file_system"
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

# Check if the partition that will receive the new kernel is writable. This is
# especially important for OSes that block the write to the / path, such as
# SteamOS and ChromeOS.
#
# Return
# An error code in case of failure or 0 in case of success.
function is_filesystem_writable()
{
  local file_system_type="$1"
  local flag="$2"
  local cmd=''
  local file_system_type

  case "$file_system_type" in
    ext4)
      # Is this A/b partition?
      if [[ -f "$AB_ROOTFS_PARTITION" ]]; then
        cmd="tune2fs -l '${AB_ROOTFS_PARTITION}' | grep --quiet '^Filesystem features: .*read-only.*$'"
      fi
      ;;
    btrfs)
      cmd='btrfs property get / ro | grep "ro=false" --silent'
      ;;
    *)
      return 95 # EOPNOTSUPP
      ;;
  esac

  # We don't need to do anything else here
  [[ -z "$cmd" ]] && return 0

  cmd_manager "$flag" "$cmd"
  return "$?"
}

# If the target partition is not in the writable mode, this function enables it
# to write.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
function make_root_partition_writable()
{
  local flag="$1"
  local file_system_type

  file_system_type=$(detect_filesystem_type '')
  is_filesystem_writable "$file_system_type"

  if [[ "$?" != 0 ]]; then
    case "$file_system_type" in
      ext4)
        cmd_manager "$flag" "tune2fs -O ^read-only ${AB_ROOTFS_PARTITION}"
        cmd_manager "$flag" 'mount --options remount,rw /'
        ;;
      btrfs)
        cmd_manager "$flag" 'mount --options remount,rw /'
        cmd_manager "$flag" 'btrfs property set / ro false'
        ;;
    esac
  fi
}

function collect_deploy_info()
{
  local flag="$1"
  local target="$2"
  local prefix="$3"
  local distro
  local bootloader

  # Let's include the bootloader_utils in the remote, and local should
  # include themselves
  # XXX: We must remove the numeric value of target because this is not the
  # default here. i.e., if [["$target" == 'remote' ]]; ...
  if [[ "$target" == 3 || "$target" == 'remote' ]]; then
    include "${REMOTE_KW_DEPLOY}/bootloader_utils.sh"
  fi

  bootloader=$(identify_bootloader_from_files "$prefix" "$target")
  bootloader="[bootloader]=${bootloader}"

  # Get distro
  distro=$(cat /etc/*-release | grep --word-regexp 'ID\(_LIKE\)\?' | cut --delimiter='=' --fields=2 | xargs printf '%s ')
  distro="${distro::-1}"
  distro="[distro]='${distro}'"

  # Build associative array data
  printf '%s' "${bootloader} ${distro}"
}

# This function is responsible for running a basic setup for the target machine
# based on its specific distro. Notice that this function works as a generic
# API that depends on the distro-specific file; for this reason, it is
# mandatory to load the distro code before calling this function.
#
# Note: the array "required_packages" is in the distro specific file and
# it must be load before invoke this function
function distro_deploy_setup()
{
  local flag="$1"
  local target="$2"
  local package_list
  local install_package_cmd

  # Make sure that / is writable
  make_root_partition_writable "$flag"

  # Hook that allow some distro to do some specific pre-setup
  distro_pre_setup "$flag" "$target"

  # Install required packages
  printf -v package_list '%s ' "${required_packages[@]}"

  install_package_cmd="${package_manager_cmd} ${package_list}"

  if [[ "$target" == 2 ]]; then
    install_package_cmd="sudo --preserve-env ${install_package_cmd}"
  fi

  cmd_manager "$flag" "$install_package_cmd"
}

# A/B partition system distros usually replace the entire /boot folder but
# preserve the content in the /opt folder, creating inconsistencies with kw
# after a distro update since the kw list will point to kernels that no longer
# exist. To handle this case, we moved the INSTALLED_KERNEL list to the /boot
# folder, but some old versions of the kw will be affected by this change; for
# this reason, this function migrates those old files to the new scheme. At
# some point, we can safely remove this migration function.
#
# TODO: Drop me in the future
function migrate_old_kernel_list()
{
  local old_installed_location='/opt/kw/INSTALLED_KERNELS'

  [[ -f "$old_installed_location" ]] && mv "$old_installed_location" '/boot/'
}

# List available kernels
# @single_line If this option is set to 1 this function will display all
#   available kernels in a single line separated by commas. If it gets 0 it
#   will display each kernel name by line.
# @prefix Set a base prefix for searching for kernels.
# @all List all available kernels, not only the ones installed by kw
function list_installed_kernels()
{
  local flag="$1"
  local single_line="$2"
  local all="$3"
  local prefix="$4"
  local -a available_kernels=()
  local cmd
  local file_system_type
  local ret=0

  # TODO: Drop me in the future
  migrate_old_kernel_list

  file_system_type=$(detect_filesystem_type '')
  is_filesystem_writable "$file_system_type" "$flag"
  if [[ "$?" != 0 ]]; then
    printf '%s\n' 'WARNING: /boot is read-only. Consider run: kw deploy --setup'
    ret=30 # EROFS
  fi

  if [[ ! -f "${INSTALLED_KERNELS_PATH}" ]]; then
    [[ "$ret" != 30 ]] && cmd_manager "$flag" "sudo touch ${INSTALLED_KERNELS_PATH}"
  fi

  cmd_manager "$flag" "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"

  if [[ -n "$all" ]]; then
    list_all_kernels "$prefix" available_kernels "$flag"
  else
    readarray -t available_kernels < "$INSTALLED_KERNELS_PATH"
    if [[ "${#available_kernels[@]}" -eq 0 ]]; then
      printf '%s\n' 'None of the installed kernels are managed by kw.' \
        'Pass --list-all|-a to see all installed kernels.'
      return 0
    fi
  fi

  if [[ "$single_line" != 1 ]]; then
    printf '%s\n' "${available_kernels[@]}"
  else
    local IFS=','
    printf '%s\n' "${available_kernels[*]}"
  fi

  return 0
}

# Based on  the kernel name pattern (vmlinuz), list all installed kernels.
#
# @prefix: Set a base prefix for searching for kernels.
# @_available_kernels: Array reference to be fill out with the kernel names
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
function list_all_kernels()
{
  local prefix="$1"
  local -n _available_kernels="$2"
  local flag="$3"
  local cmd_get_kernels
  local output
  local index=0
  local extension
  local kernel_name
  declare -a raw_kernel_name_list

  [[ "$flag" == 'VERBOSE' ]] && printf '%s\n' "$cmd_get_kernels"

  cmd_get_kernels="find ${prefix}/boot/ -name '*linuz*' -printf '%f\n' | sort --dictionary"

  output=$(cmd_manager 'SILENT' "$cmd_get_kernels")
  readarray -t raw_kernel_name_list <<< "$output"

  for element in "${raw_kernel_name_list[@]}"; do
    extension="${element##*.}"
    [[ "$extension" == 'old' ]] && continue

    # Remove kernel prefix (vmlinuz)
    kernel_name=$(printf '%s' "$element" | cut --delimiter='-' --fields=2-)

    _available_kernels["$index"]="$kernel_name"
    ((index++))
  done
}

function reboot_machine()
{
  local reboot="$1"
  local local="$2"
  local flag="$3"

  [[ "$local" == 'local' ]] && sudo_cmd='sudo --preserve-env '

  if [[ "$reboot" == '1' ]]; then
    cmd="${sudo_cmd}"'reboot'
    cmd_manager "$flag" "$cmd"
  fi
}

# Uncompress kw package
#
# @kw_pkg_tar_name Expected full kw package name
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

# Synchronize new modules files in the target machine
#
# @kw_pkg_tar_name Expected full kw package name
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

# Update bootloader API
# This function behaves like the template pattern, which means that we have a
# generic function name that will be called in a specific order to update the
# bootloader in the target machine. The trick here consists of first loading
# the target bootloader and specific distro script and executing the required
# update. Also notice that in some cases we need to update the initramfs.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @name Kernel name used during the deploy
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @kernel_image_name Kernel binary file name
# @distro Target distro (e.g., arch or debian)
# @prefix Set a base prefix for searching for kernels.
function update_bootloader()
{
  local flag="$1"
  local name="$2"
  local target="$3"
  local kernel_image_name="$4"
  local distro="$5"
  local prefix="$6"
  local root_file_system="$7"
  local force="$8"
  local deploy_data_string
  local bootloader_path_prefix="${REMOTE_KW_DEPLOY}/"
  local ret
  local generate_initram=0

  [[ -n "$distro" ]] && generate_initram=1
  [[ -z "$prefix" ]] && prefix='/'

  if [[ "$target" == 'local' || "$flag" == 'TEST_MODE' ]]; then
    bootloader_path_prefix="${KW_PLUGINS_DIR}/kernel_install/"
  fi

  deploy_data_string=$(collect_deploy_info "$flag" "$target" "$prefix")

  declare -A deploy_data="(${deploy_data_string})"

  case "${deploy_data['bootloader']}" in
    GRUB)
      bootloader_path_prefix+='grub.sh'
      ;;
    RPI_BOOTLOADER)
      bootloader_path_prefix+='rpi_bootloader.sh'
      ;;
    *)
      return 95 # ENOTSUP
      ;;
  esac

  # Load specific bootloader action
  include "$bootloader_path_prefix"

  # Each distro has their own way to generate their temporary root file system.
  if [[ "$generate_initram" == 1 ]]; then
    # For example, Debian uses update-initramfs, Arch uses mkinitcpio, etc
    cmd="generate_${distro}_temporary_root_file_system"
    cmd+=" ${flag} ${name} ${target} ${deploy_data['bootloader']} ${path_prefix} ${root_file_system}"

    cmd_manager "$flag" "$cmd"
    ret="$?"
    # If the generate root fs function returns 2, it means we don't have
    # initramfs; hence, stop deploying.
    if [[ "$ret" == 2 ]]; then
      printf 'The initramfs were not generated, which will cause boot issues.\n'
      printf 'Stop the deploy.\n'
      return "$ret"
    fi

    # We have an error, but it may not be fatal. Let the user decide.
    if [[ "$ret" == 68 ]]; then
      printf '\n\t kw identified possible non-fatal errors in the generated initramfs.\n'
      if [[ "$force" == 0 ]]; then

        ask_yN 'There are some errors in the generated initramfs. Do you want to proceed with the installation?'
        if [[ "$?" != 1 ]]; then
          printf '%s\n' "Kernel ${kernel_image_name} installation canceled"
          exit 124 # ECANCELED
        fi
      fi
    fi
  fi

  # Update bootloader
  run_bootloader_update "$flag" "$target" "$name" "$kernel_image_name"
  ret="$?"

  return "$ret"
}

function do_uninstall()
{
  local target="$1"
  local kernel_name="$2"
  local prefix="$3"
  local flag="$4"
  local sudo_cmd=''
  local modules_lib_path="${prefix}/lib/modules/${kernel_name}"
  local -a files_to_be_removed=(
    "${prefix}/etc/mkinitcpio.d/${kernel_name}.preset"
    "${prefix}/var/lib/initramfs-tools/${kernel_name}"
  )

  if [[ "$target" == 'local' ]]; then
    sudo_cmd='sudo --preserve-env '
  fi

  if [[ -z "$kernel_name" ]]; then
    printf '%s\n' 'No parameter, nothing to do'
    exit 22 # EINVAL
  fi

  to_remove_from_boot=$(find "${prefix}/boot/" -name "*${kernel_name}*" | sort)
  # shellcheck disable=SC2068
  for element in ${to_remove_from_boot[@]}; do
    if [[ -f "$element" ]]; then
      printf ' %s\n' "Removing: ${element}"
      cmd_manager "$flag" "${sudo_cmd}rm ${element}"
    else
      printf ' %s\n' "Can't find ${element}"
    fi
  done

  for del_file in "${files_to_be_removed[@]}"; do
    if [[ -f "$del_file" ]]; then
      printf ' %s\n' "Removing: ${del_file}"
      cmd_manager "$flag" "${sudo_cmd}rm ${del_file}"
    else
      printf ' %s\n' "Can't find ${del_file}"
    fi
  done

  if [[ -d "$modules_lib_path" && "$modules_lib_path" != '/lib/modules' ]]; then
    printf ' %s\n' "Removing: ${modules_lib_path}"
    cmd_manager "$flag" "${sudo_cmd}rm --recursive --force ${modules_lib_path}"
  else
    printf ' %s\n' "Can't find ${modules_lib_path}"
  fi
}

# Checks if an element is contained in a given array.
#
# @target_element: Target element to check
# @_array: Indexed array reference to target array
#
# Return:
# Returns 0 if `@target_element` is in `@_array` and 1 otherwise.
function is_in_array()
{
  local target_element="$1"
  local -n _array="$2"

  for element in "${_array[@]}"; do
    [[ "$element" == "$target_element" ]] && return 0
  done
  return 1
}

# Returns an unique list of names for the available kernels.
#
# @all_kernels: List all available kernels if set, besides those managed kw
# @prefix: Base prefix for searching available kernels
# @_processsed_installed_kernels: Indexed array reference where the list will be
#    stored. The indexed array will be cleared prior to the storing.
#
# Return:
# Returns array containing available kernels in `@_processed_installed_kernels`.
function process_installed_kernels()
{
  local all_kernels="$1"
  local prefix="$2"
  local -n _processed_installed_kernels="$3"
  local kernels

  _processed_installed_kernels=()
  kernels=$(list_installed_kernels 'SILENT' 1 "$all_kernels" "$prefix")
  IFS=, read -r -a available_kernels <<< "$kernels"
  mapfile -t _processed_installed_kernels <<< "$(printf "%s\n" "${available_kernels[@]}" | sort --unique)"
}

function kernel_uninstall()
{
  local reboot="$1"
  local target="$2"
  local kernel_list_string_or_regex="$3"
  local flag="$4"
  local force="$5"
  local prefix="$6"
  local update_grub=0
  local -a all_installed_kernels
  local -a kw_managed_kernels
  local prefix_for_regex='regex:'
  local regex_expression
  declare -A kernel_names

  if [[ -z "$kernel_list_string_or_regex" ]]; then
    printf '%s\n' 'Invalid argument'
    exit 22 #EINVAL
  fi

  # TODO: Drop me in the future
  migrate_old_kernel_list

  cmd_manager "$flag" "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
  cmd_manager "$flag" "sudo touch '${INSTALLED_KERNELS_PATH}'"

  process_installed_kernels 1 "$prefix" 'all_installed_kernels'
  process_installed_kernels '' "$prefix" 'kw_managed_kernels'

  IFS=', ' read -r -a kernel_names_array <<< "$kernel_list_string_or_regex"

  for input_string in "${kernel_names_array[@]}"; do
    for installed_kernel in "${all_installed_kernels[@]}"; do
      if [[ "$input_string" =~ ^$prefix_for_regex ]]; then
        regex_expression=^${input_string#"$prefix_for_regex"}$
        [[ "$installed_kernel" =~ $regex_expression ]] && kernel_names["$installed_kernel"]=1
      else
        [[ "$installed_kernel" == "$input_string" ]] && kernel_names["$installed_kernel"]=1
      fi
    done
  done

  for kernel in "${!kernel_names[@]}"; do
    is_in_array "$kernel" 'kw_managed_kernels'
    if [[ "$?" != 0 && -z "$force" ]]; then
      printf '%s\n' "${kernel} not managed by kw. Use --force/-f to uninstall anyway."
      continue # EINVAL
    fi

    printf '%s\n' "Removing: ${kernel}"
    do_uninstall "$target" "$kernel" "$prefix" "$flag"

    # Clean from the log
    cmd_manager "$flag" "sudo sed --in-place '/${kernel}/d' '${INSTALLED_KERNELS_PATH}'"
    ((update_grub++))
  done

  # Each distro script should implement update_bootloader
  if [[ "$update_grub" -gt 0 ]]; then
    #printf '%s\n' "update_bootloader $kernel $target $flag"
    update_bootloader "$flag" "$kernel" "$target" "$kernel_image_name" '' "$path_prefix" '' "$force"

    # Reboot
    reboot_machine "$reboot" "$target" "$flag"
  fi
}

# Install kernel
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
    return 22
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
