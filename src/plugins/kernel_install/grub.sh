# This file is specific to the GRUB bootloader, and since it is part of kw, it
# follows the bootloader API. In other words, we have one entry point
# functions: run_bootloader_update: Update GRUB in a local and remote machine.

declare -g GRUB_CFG_PATH='/boot/grub/grub.cfg'
declare -g DEFAULT_GRUB_CMD_UPDATE='grub-mkconfig --output=/boot/grub/grub.cfg'

# Some distributions, such as Fedora, use GRUB2 as the default bootloader. On
# those systems, grub-mkconfig command is replaced by grub2-mkconfig. This function
# checks if the grub-mkconfig command exists and if doesn't, the default grub
# update command is set to grub2-mkconfig.
#
# Returns:
# 0 if a grub update command exists and 2 otherwise.
function define_grub_cmd_update()
{
  local grub_cmd='grub-mkconfig'
  local grub2_cmd='grub2-mkconfig'

  if command_exists 'update-grub'; then
    DEFAULT_GRUB_CMD_UPDATE='update-grub'
    return 0
  fi

  if ! command_exists "$grub_cmd"; then
    if ! command_exists "$grub2_cmd"; then
      return 2 # ENOENT
    fi
    DEFAULT_GRUB_CMD_UPDATE="grub2-mkconfig --output=/boot/grub2/grub.cfg"
  fi

  return 0
}

# Update grub bootloader in a target machine.
function run_bootloader_update()
{
  local flag="$1"
  local target="$2"
  local name="$3"
  local kernel_image_name="$4"
  local boot_into_new_kernel_once="$5"
  local cmd_grub
  local cmd_sudo
  local total_count

  flag=${flag:-'SILENT'}

  if [[ "$target" == 'local' ]]; then
    cmd_sudo='sudo --preserve-env '
    cmd_grub+="$cmd_sudo"
  fi

  define_grub_cmd_update
  if [[ "$?" -gt 0 ]]; then
    complain "There is no grub-mkconfig command in the system."
    return 125 # ECANCELED
  fi

  cmd_grub+="$DEFAULT_GRUB_CMD_UPDATE"

  cmd_manager "$flag" "$cmd_grub"

  # Setup grub to boot the new kernel
  if [[ "$boot_into_new_kernel_once" == 1 ]]; then
    setup_grub_reboot_for_new_kernel "$name" "$kernel_image_name" "$cmd_sudo" "$flag"
  fi
}

function get_grub_cfg_path()
{
  local grub_cfg_path="${GRUB_CFG_PATH}"

  if [[ -f "$grub_cfg_path" ]]; then
    printf '%s\n' "$grub_cfg_path"
    return 0
  fi

  # Check in the /efi folder
  grub_cfg_path=$(find '/efi/' -name 'grub.cfg')
  if [[ -f "$grub_cfg_path" ]]; then
    printf '%s\n' "$grub_cfg_path"
    return 0
  fi

  # Check in the /efi folder
  grub_cfg_path=$(find '/boot/' -name 'grub.cfg')
  if [[ -f "$grub_cfg_path" ]]; then
    printf '%s\n' "$grub_cfg_path"
    return 0
  fi

  return 2 # ENOENT
}

# Setup grub reboot.a
# This function was created inspired by:
#   https://wiki.debian.org/GrubReboot
#
# @name: Kernel name used during the deploy.
# @kernel_img_name: Kernel image file name, it usually has an intersection with the kernel name.
# @flag: How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`.
#
# Return:
# Return 22 in case of invalid option
function setup_grub_reboot_for_new_kernel()
{
  local name="$1"
  local kernel_image_name="$2"
  local cmd_sudo="$3"
  local flag="$4"
  local grub_file_raw
  local submenu
  local menuentry
  local kernel_line_position
  local submenu_line_position
  local grub_cfg_path

  grub_cfg_path=$(get_grub_cfg_path)
  if [[ "$?" == 2 ]]; then
    printf 'kw did not find grub.cfg\n'
    return 2
  fi

  grub_file_raw=$(cmd_manager 'SILENT' "${sudo_cmd}cat ${grub_cfg_path}")

  [[ -z "$grub_file_raw" ]] && return 22

  # Process menu entry
  menuentry=$(printf '%s' "$grub_file_raw" | grep --line-number --ignore-case ".*menuentry.*${name}")
  menuentry=$(printf '%s' "$menuentry" | grep --invert-match 'recovery')
  kernel_line_position=$(printf '%s' "$menuentry" | cut --delimiter=':' --fields=1)
  menuentry=$(printf '%s' "$menuentry" | sed "s/^[^']*'\([^']*\)'.*/\1/")

  # grub-reboot 'Advanced options for Arch Linux>Arch Linux, with Linux 6.12.0-TEST-AMD-CONFIG2+
  submenu_raw=$(printf '%s' "$grub_file_raw" | grep --line-number --ignore-case 'submenu')
  submenu="$submenu_raw"

  while IFS= read -r line; do
    submenu_line_position=$(printf '%s' "$line" | cut --delimiter=':' --fields=1)
    # We don't care about submenus after the kernel match
    [[ "$submenu_line_position" -gt "$kernel_line_position" ]] && break
    submenu="$line"
  done <<< "$submenu_raw"

  submenu=$(printf '%s' "$submenu" | sed "s/^[^']*'\([^']*\)'.*/\1/")

  if [[ -n "$submenu" ]]; then
    submenu="${submenu}>"
  fi

  cmd_manager "$flag" "${cmd_sudo}grub-reboot '${submenu}${menuentry}'"
}

function total_of_installed_kernels()
{
  local flag="$1"
  local target="$2"
  local total_count
  local find_cmd="find /boot -name 'vmlinuz*' | wc --lines"

  [[ "$target" == 'local' ]] && find_cmd="sudo --preserve-env ${find_cmd}"

  [[ "$flag" != 'TEST_MODE' ]] && total_count=$(eval "$find_cmd")
  total_count=$((total_count * 2 + 7))

  printf '%d' "$total_count"
}
