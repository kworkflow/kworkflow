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

  # FIXME: PopOS workaround
  grep --quiet --ignore-case 'name="pop!_os"' /etc/os-release
  if [[ "$?" == 0 ]]; then
    execute_popos_workaround "$flag" "$target" "$name"
  fi

  # Setup systemd to boot the new kernel
  if [[ "$boot_into_new_kernel_once" == 1 ]]; then
    setup_systemd_reboot_for_new_kernel "$name" "$sudo_cmd" "$flag"
  fi
}

# PopOS uses Kernelstub instead of kernel-install. Additionally, this OS
# features a partition system with A and B partitions, where any newly deployed
# kernel becomes the default kernel, and the old kernel remains in the boot
# system. The problem with this approach is that multiple deploys will
# eventually cause the distro kernel to be lost from the boot. I did not find
# any good solution that respects the PopOS way of doing things. To mitigate
# part of this problem, kw still uses kernel-install in PopOS (even though this
# is not the recommended way) and does one manual change to the entry file to
# make the new kernel visible in the systemd-boot menu. This approach does not
# mess with the A and B partition systems used by PopOs.
#
# This workaround has 3 steps:
# 1) Update the new entry file to use the custom kernel name.
# 2) Identify the latest generic kernel.
# 3) Ensure that the generic kernel is the main one.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @target: Remote our Local.
# @name: Kernel name used during the deploy.
function execute_popos_workaround()
{
  local flag="$1"
  local target="$2"
  local name="$3"
  local prefix="$4"
  local esp_base_path=''
  local loader_entries_path=''
  local target_entry_path=''
  local current_kernel=''
  local vmlinuz_path=''
  local initrd_path=''
  local cmd=''
  local sudo_cmd

  [[ "$target" == 'local' ]] && sudo_cmd='sudo '

  esp_base_path=$(get_esp_base_path "$target" 'SILENT')
  loader_entries_path="${esp_base_path}${LOADER_ENTRIES_PATH}"

  cmd="${sudo_cmd}find '$loader_entries_path' -name '*${name}.conf'"
  [[ "$flag" == 'VERBOSE' ]] && printf '%s\n' "$cmd"
  target_entry_path=$(cmd_manager 'SILENT' "$cmd")
  cmd="${sudo_cmd}sed --in-place 's/^title .*$/title ${name}/' '$target_entry_path'"
  [[ "$flag" == 'VERBOSE' ]] && printf '%s\n' "$cmd"
  cmd_manager 'SILENT' "$cmd"

  current_kernel=$(uname --kernel-release)
  printf '%s' "$current_kernel" | grep --quiet --ignore-case '\-generic$'
  if [[ "$?" != 0 ]]; then
    # TODO: Can we find a better way to handle this?
    cmd="${sudo_cmd}find ${prefix}/boot/ -name 'vmlinuz*-generic' | "
    cmd+='sort --version-sort --reverse | head -1 | '
    # \K is a fascinating trick from Perl, in a few words, it gets the match
    # output from the \K onword. For example, without \K, the output would be
    # vmlinuz-6.12.10-76061203-generic; however, with \K, we get
    # 6.12.10-76061203-generic.
    # Ref:
    # https://perldoc.perl.org/perlre#%5CK
    cmd+="grep --only-matching --perl-regexp 'vmlinuz-\K.*-generic$'"
    current_kernel=$(cmd_manager 'SILENT' "$cmd")
  fi

  vmlinuz_path="${prefix}/boot/vmlinuz-${current_kernel}"
  initrd_path="${prefix}/boot/initrd.img-${current_kernel}"

  if [[ -z "$current_kernel" ]]; then
    vmlinuz_path='<PATH TO GENERIC KERNEL>'
    initrd_path='<PATH TO GENERIC INITRD>'
  fi

  cmd="${sudo_cmd}kernelstub --kernel-path ${vmlinuz_path} --initrd-path ${initrd_path}"

  if [[ -z "$current_kernel" ]]; then
    printf 'WARNING: kw was not able to identify the generic kernel. Consider run:'
    printf '%s\n' "$cmd"
    return 22 # EINVAL
  fi

  cmd_manager "$flag" "$cmd"

  printf '%s\n' 'WARNING: Due to some limitations in supporting PopOS, the after-reboot feature may not working as expected.'
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
  local target="$4"
  local target_id
  local cmd_bootctl_oneshot="${cmd_sudo}bootctl set-oneshot "
  local cmd_bootctl_id="${cmd_sudo}bootctl list --json=short | jq --raw-output '.[].id'"
  local version

  # It looks like that the json option was only available from v257
  # (https://github.com/systemd/systemd/releases/tag/v257) onward, and popos
  # still in version 249.
  version=$(get_bootctl_version "$cmd_sudo")
  if [[ "$version" -le 257 ]]; then
    printf 'WARNING: bootctl version %s is old.\n' "$version"
    cmd_bootctl_id="${cmd_sudo}bootctl list | grep --only-matching --perl-regexp 'id: \K.*.conf'"
  fi

  cmd_bootctl_id+=" | grep --ignore-case ${name}.conf"

  [[ "$flag" == 'VERBOSE' ]] && printf '%s\n' "$cmd_bootctl_id"
  target_id=$(cmd_manager 'SILENT' "$cmd_bootctl_id")
  if [[ "$?" -ne 0 ]]; then
    printf 'WARNING: Unable to identify kernel ID. "%s" failed.\n' "$cmd_bootctl_id"
  fi

  cmd_bootctl_oneshot+="$target_id"
  cmd_manager "$flag" "${sudo_cmd}${cmd_bootctl_oneshot}"
}
