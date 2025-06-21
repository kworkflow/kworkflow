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
  local specific_entry_path
  local esp_base_path
  local cmd

  flag=${flag:-'SILENT'}
  [[ "$target" == 'local' ]] && sudo_cmd='sudo '

  esp_base_path=$(get_esp_base_path "$target" "$flag")
  [[ "$?" == 95 ]] && return 95 # EOPNOTSUPP

  if [[ -z "$name" ]]; then
    return
  fi

  cmd="${sudo_cmd}find '${esp_base_path}/${LOADER_ENTRIES_PATH}' -name '*${name}.conf'"
  specific_entry_path=$(cmd_manager 'SILENT' "$cmd")
  # In some OSes, the kernel-install runs by default, while in others, it does
  # not. In the cases where kernel-install does not run, the new entry does get
  # created; kw leverages this behavior to check if it is necessary to run
  # kernel-install manually.
  if [[ -z "$specific_entry_path" ]]; then
    execute_systemd_kernel_install "$flag" "$target" "$name"
  fi

  # Setup systemd to boot the new kernel
  if [[ "$boot_into_new_kernel_once" == 1 ]]; then
    setup_systemd_reboot_for_new_kernel "$name" "$sudo_cmd" "$flag"
  fi
}

# Systemd uses kernel-install as the official tool for adding a new kernel.
# This function serves as a wrapper to call kernel-install when necessary.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @target: Remote our Local.
# @name Kernel name used during the deploy
#
# Return:
# Return 0 in case of success and 2 in case of failure.
function execute_systemd_kernel_install()
{
  local flag="$1"
  local target="$2"
  local name="$3"
  local prefix="$4"
  local cmd
  local initram_path

  flag=${flag:-'SILENT'}
  [[ "$target" == 'local' ]] && sudo_cmd='sudo '

  cmd="${sudo_cmd}find '${prefix}/boot/' -name 'init*${name}*'"
  initram_path=$(cmd_manager 'SILENT' "$cmd")

  if [[ -z "$initram_path" || ! -f "$initram_path" ]]; then
    printf '%s\n' "Error: kw did not find initramfs: path='${initram_path}'"
    return 2 # ENOENT
  fi
  cmd="${sudo_cmd}kernel-install add '${name}' '${prefix}/boot/vmlinuz-${name}' '${prefix}${initram_path}'"
  cmd_manager "$flag" "$cmd"
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
