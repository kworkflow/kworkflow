# This file is dedicated to handle systemd-boot, and since it is part of kw, it
# follows the bootloader API.

# Generic path to loader that must be concatenated with the esp folder.
declare -gr LOADER_ENTRIES_PATH='/loader/entries'

function run_bootloader_update()
{
  local flag="$1"
  local target="$2"
  local name="$3"
  local kernel_image_name="$4"
  local boot_into_new_kernel_once="$5"

  flag=${flag:-'SILENT'}
  [[ "$target" == 'local' ]] && sudo_cmd='sudo '

  # Setup systemd to boot the new kernel
  if [[ "$boot_into_new_kernel_once" == 1 ]]; then
    setup_systemd_reboot_for_new_kernel "$name" "$sudo_cmd" "$flag"
  fi
}

# Setup systemd to boot in the new kernel.
#
# @name: Kernel name used during the deploy.
# @kernel_img_name: Kernel image file name, it usually has an intersection with the kernel name.
# @cmd_sudo: Sudo command
# @flag: How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`.
function setup_systemd_reboot_for_new_kernel()
{
  local name="$1"
  local cmd_sudo="$2"
  local flag="$3"
  local target_id
  local cmd_bootctl_oneshot="${cmd_sudo}bootctl set-oneshot "
  local cmd_bootctl_id="${cmd_sudo}bootctl list --json=short | jq --raw-output '.[].id' | grep --ignore-case ${name}.conf"

  [[ "$flag" == 'VERBOSE' ]] && printf '%s\n' "$cmd_bootctl_id"
  target_id=$(cmd_manager 'SILENT' "$cmd_bootctl_id")
  if [[ "$?" -ne 0 ]]; then
    printf 'WARNING: Unable to identify kernel ID. "%s" failed.\n' "$cmd_bootctl_id"
  fi

  cmd_bootctl_oneshot+="$target_id"
  cmd_manager "$flag" "${sudo_cmd}${cmd_bootctl_oneshot}"
}
