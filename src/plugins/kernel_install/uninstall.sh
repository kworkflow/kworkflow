# This file centralizes all the steps to uninstall kernels in the target
# machine. Keep in mind that those steps should work both remotely and locally.
# Also, this file uses many of the bootloader operations and some of the
# functions available in the utils.sh.

# The kernel_uninstall it is the entry point for the kernel removal operation.
#
# @reboot: Set to 1 if user wants the system to be reboot.
# @target: Remote our Local.
# @kernel_list_string_or_regex: String with the kernel names to be removed or a
#   string with the 'regex:' prefix.
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @force: Force kernel removal that are not directly controlled by kw.
# @prefix: Add a prefix for the boot folder.
function kernel_uninstall()
{
  local distro="$1"
  local reboot="$2"
  local target="$3"
  local kernel_list_string_or_regex="$4"
  local flag="$5"
  local force="$6"
  local prefix="$7"
  local update_grub=0
  local index=0
  local cmd=''
  local -a all_installed_kernels
  local -a kw_managed_kernels
  local total_of_kw_kernels
  local regex_expression
  local total_kernels_managed_by_kw
  local deploy_data_string
  local ret
  # From user request, this array keeps the list of kernels to be removed
  declare -a kernel_to_remove

  if [[ -z "$kernel_list_string_or_regex" ]]; then
    printf '%s\n' 'Invalid argument'
    exit 22 #EINVAL
  fi

  # TODO: Drop me in the future
  migrate_old_kernel_list

  cmd_manager "$flag" "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
  cmd_manager "$flag" "sudo touch '${INSTALLED_KERNELS_PATH}'"
  process_installed_kernels 1 "$prefix" 'all_installed_kernels' "$target"
  process_installed_kernels '' "$prefix" 'kw_managed_kernels' "$target"
  total_kernels_managed_by_kw="$?"

  IFS=', ' read -r -a kernel_names_array <<< "$kernel_list_string_or_regex"

  if [[ "$kernel_list_string_or_regex" != "''" ]]; then
    kernel_to_be_removed_based_on_user_input 'kernel_names_array' 'all_installed_kernels' 'kernel_to_remove'
    ret="$?"
  # If user does not provide any input, remove the first kernel managed by kw
  else
    kernel_to_remove[0]="${kw_managed_kernels[0]}"
    if [[ "$total_kernels_managed_by_kw" -eq 0 ]]; then
      printf '%s\n' 'There is no kernel managed by kw.'
      return 0 # There is no kernel managed by kw, in this case ignore -u with no parameter
    fi
  fi

  for kernel in "${kernel_to_remove[@]}"; do
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

  deploy_data_string=$(collect_deploy_info "$flag" "$target" "$prefix")

  declare -A deploy_data="(${deploy_data_string})"

  # Reboot
  if [[ "$reboot" == '1' ]]; then
    cmd="${sudo_cmd} reboot"
    reboot_machine "$reboot" "$target" "$flag"
  fi
}

# Matches the user input with available kernels to be removed.
#
# @_kernel_names_array: Array with kernel names maintained by kw.
# @_all_installed_kernels: Array with all kernels available.
# @_kernel_to_remove: Array to be returned with all the kernels that can be removed.
#
# Return:
# Return the total of kernels to be removed, and fill out the _kernel_to_remove
# array with all kernels that must be removed.
function kernel_to_be_removed_based_on_user_input()
{
  local -n _kernel_names_array="$1"
  local -n _all_installed_kernels="$2"
  local -n _kernel_to_remove="$3"
  local input_string
  local index=0

  for input_string in "${_kernel_names_array[@]}"; do
    input_string=$(str_remove_char_from_string "$input_string" "'")
    for installed_kernel in "${_all_installed_kernels[@]}"; do
      # Note: the prefix 'regex:' is mandatory if the user want to use regex
      if [[ "$input_string" =~ ^regex: ]]; then
        regex_expression=^${input_string#'regex:'}$
        if [[ "$installed_kernel" =~ $regex_expression ]]; then
          _kernel_to_remove["$index"]="$installed_kernel"
          ((index++))
        fi
      else
        if [[ "$installed_kernel" == "$input_string" ]]; then
          _kernel_to_remove["$index"]="$installed_kernel"
          ((index++))
        fi
      fi
    done
  done

  return "$index"
}

# Checks if an element is contained in a given array.
#
# TODO: Move this function to src/lib/kwlib.sh
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
# Returns array containing available kernels in `@_processed_installed_kernels`
# and the total of installed kernels.
function process_installed_kernels()
{
  local all_kernels="$1"
  local prefix="$2"
  local -n _processed_installed_kernels="$3"
  local target="$4"
  local kernels
  local total_kernels

  _processed_installed_kernels=()
  kernels=$(list_installed_kernels 'SILENT' 1 "$all_kernels" "$prefix" "$target")
  total_kernels="$?"

  IFS=, read -r -a available_kernels <<< "$kernels"
  mapfile -t _processed_installed_kernels <<< "$(printf "%s\n" "${available_kernels[@]}" | sort --unique)"

  return "$total_kernels"
}

# Remove systemd-boot files for the custom kernel
#
# @target: Remote our Local.
# @kernel_name: Kernel name set by the user.
#
# Return:
# Return 0 in case of success or 22 otherwise
function remove_systemd_kernel_files()
{
  local target="$1"
  local kernel_name="$2"
  local flag="$3"
  local sudo_cmd
  local cmd

  if [[ -z "${kernel_name}" || "${#kernel_name}" -lt 3 ]]; then
    printf '%s\n' "ERROR: The '${kernel_name}' is invalid (empty) or too small."
    return 22 # EINVAL
  fi

  [[ "$target" == 'local' ]] && sudo_cmd='sudo --preserve-env '

  # Remove all the main files
  cmd="kernel-install remove '${kernel_name}'"
  cmd_manager "$flag" "${sudo_cmd}${cmd}"
}

function remove_kernel_files_from_boot()
{
  local kernel_name="$1"
  local prefix="$2"
  local flag="$3"
  local sudo_cmd=''
  local element=''
  local to_remove_from_boot=''

  if [[ "$target" == 'local' ]]; then
    sudo_cmd='sudo --preserve-env '
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
}

# Do the actual removal of kernel files.
#
# @target: Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @kernel_name: Kernel name set by the user.
# @prefix: Add a prefix for the boot folder.
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# Return 0 if everything is working as expected, or 22 in case of other issues.
function do_uninstall()
{
  local target="$1"
  local kernel_name="$2"
  local prefix="$3"
  local flag="$4"
  local sudo_cmd=''
  local to_remove_from_boot
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

  is_bootctl_the_default "$target"
  if [[ "$?" == 0 ]]; then
    remove_systemd_kernel_files "$target" "$kernel_name" "$flag"
    if [[ "$?" != 0 ]]; then
      printf 'ERROR: Something went wrong when trying to get the ESP base path.\n'
      return 22 # EINVAL
    fi
  else
    remove_kernel_files_from_boot "$kernel_name" "$prefix" "$flag"
  fi

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
