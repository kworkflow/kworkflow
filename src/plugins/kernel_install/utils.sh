declare -g INSTALLED_KERNELS_PATH='/boot/INSTALLED_KERNELS'
declare -g AB_ROOTFS_PARTITION='/dev/disk/by-partsets/self/rootfs'

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
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @single_line If this option is set to 1 this function will display all
#   available kernels in a single line separated by commas. If it gets 0 it
#   will display each kernel name by line.
# @all List all available kernels, not only the ones installed by kw
# @prefix Set a base prefix for searching for kernels.
#
# Return:
# Return the total of kernel listed
function list_installed_kernels()
{
  local flag="$1"
  local single_line="$2"
  local all="$3"
  local prefix="$4"
  local target="$5"
  local -a available_kernels=()
  local file_system_type
  local sudo_cmd=''
  local cmd=''
  local ret=0

  [[ "$target" == 2 || "$target" == 'local' ]] && sudo_cmd='sudo '

  # TODO: Drop me in the future
  migrate_old_kernel_list

  file_system_type=$(detect_filesystem_type '')
  is_filesystem_writable "$file_system_type" "$flag"
  if [[ "$?" != 0 ]]; then
    printf '%s\n' 'WARNING: /boot is read-only. Consider run: kw deploy --setup'
    ret=30 # EROFS
  fi

  if [[ ! -f "${INSTALLED_KERNELS_PATH}" ]]; then
    [[ "$ret" != 30 ]] && cmd_manager "$flag" "${sudo_cmd}touch ${INSTALLED_KERNELS_PATH}"
  fi

  cmd_manager "$flag" "${sudo_cmd}mkdir --parents ${REMOTE_KW_DEPLOY}"

  if [[ -n "$all" ]]; then
    list_all_kernels "$prefix" available_kernels "$flag" "$sudo_cmd"
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

  return "${#available_kernels}"
}

# Check if bootctl is available and active
#
# Return:
# Return 0 if bootctl is valid and 22 otherwise.
function is_bootctl_the_default()
{
  local target="$1"
  local systemd_boot
  local systemd_product
  local sudo_cmd=''
  local cmd=''

  [[ "$target" == 2 || "$target" == 'local' ]] && sudo_cmd='sudo --preserve-env '

  # Check if it is a systemd-boot system
  if command_exists 'bootctl'; then
    cmd="${sudo_cmd}bootctl is-installed --graceful"
    systemd_boot=$(cmd_manager 'SILENT' "$cmd")
    if [[ "$systemd_boot" == 'yes' ]]; then
      # Systemd-boot may be installed but not active.
      cmd="${sudo_cmd}bootctl status | grep --ignore-case 'product' | cut --delimiter ':' --fields=2"
      systemd_product=$(cmd_manager 'SILENT' "$cmd")
      systemd_product=$(str_strip "$systemd_product")
      systemd_product=$(printf '%s' "$systemd_product" | cut --delimiter ' ' --fields=1)
      systemd_product=$(str_strip "$systemd_product")
      [[ "$systemd_product" == 'systemd-boot' ]] && return 0
    fi
  fi

  return 22 # EINVAL
}

function get_bootctl_version()
{
  local sudo_cmd="$1"
  local version
  local cmd

  cmd="${sudo_cmd}bootctl --version | head -1 | grep --only-matching --perl-regexp 'systemd \K\d*'"

  version=$(cmd_manager 'SILENT' "$cmd")
  printf '%s' "$version"
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
  local sudo_cmd="$4"
  local is_systemd_boot=0
  local cmd_get_kernels
  local output
  local index=0
  local extension
  local kernel_name
  local version
  declare -a raw_kernel_name_list

  [[ "$flag" == 'VERBOSE' ]] && printf '%s\n' "$cmd_get_kernels"

  is_bootctl_the_default "$target"
  ret="$?"
  if [[ "$ret" == 0 ]]; then
    cmd_get_kernels="${sudo_cmd}bootctl list --json=short | jq --raw-output '.[].version' | grep --invert null"

    # TODO: At some point, when LTS distros adopts bootctl newer then 257,
    # remove this.
    version=$(get_bootctl_version "$sudo_cmd")
    if [[ "$version" -le 257 ]]; then
      cmd_get_kernels="${sudo_cmd}bootctl list | grep --only-matching --perl-regexp 'version: \K.*'"
    fi

    # Process raw output from bootctl
    output=$(cmd_manager 'SILENT' "$cmd_get_kernels")
    is_systemd_boot=1
  else
    cmd_get_kernels="${sudo_cmd}find ${prefix}/boot/ -regextype posix-egrep -regex '.*(linuz|kernel).*' -printf '%f\n' | sort --dictionary"
    output=$(cmd_manager 'SILENT' "$cmd_get_kernels")
  fi

  readarray -t raw_kernel_name_list <<< "$output"

  for element in "${raw_kernel_name_list[@]}"; do
    extension="${element##*.}"
    [[ "$extension" == 'old' ]] && continue

    kernel_name="$element"
    # Remove kernel prefix (vmlinuz)
    if [[ "$is_systemd_boot" -eq 0 ]]; then
      kernel_name=$(printf '%s' "$element" | cut --delimiter='-' --fields=2-)
    fi

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
