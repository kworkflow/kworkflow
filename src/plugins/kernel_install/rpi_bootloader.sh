# This file is specific to the raspberry pi bootloader, and since it is part
# of kw, it follows the bootloader API. In other words, we have two entry
# point functions:
# 1. run_bootloader_update: Update GRUB in a local and remote machine.
# 2. run_bootloader_for_vm: Update GRUB in a virtual machine.

BOOT_PATH='/boot'
RPI_CONFIG_TXT_PATH="${BOOT_PATH}/config.txt"

# Update raspberry bootloader in a target machine.
# The standard Raspberry Pi
# bootloader is configured via config.txt file, and this function is dedicated
# to handling this file from the kernel image perspective. If a new kernel is
# installed, this function adds it to the config.txt and comments on the
# previous kernel. If there is an entry to a kernel image that does not exist,
# this function removes it.
function run_bootloader_update()
{
  local flag="$1"
  local target="$2"
  local name="$3"
  local find_target
  local sudo_cmd

  [[ "$target" == 'local' ]] && sudo_cmd='sudo'

  # Find kernel name
  find_target=$(find "$BOOT_PATH" -name "*${name}*" -not -name '*.old' -not -name 'config-*' -not -name 'initrd*')
  find_target=$(basename "$find_target")

  # Check if the kernel name were already added to config.txt
  grep --quiet --extended-regexp "^kernel=*.${find_target}" "$RPI_CONFIG_TXT_PATH"
  if [[ "$?" == 0 && -n "$find_target" ]]; then
    return
  fi

  # If we find a kernel name in the config file, and no kernel image we
  # want to remove that reference.
  if [[ -z "$find_target" ]]; then
    cmd="${sudo_cmd} sed -i '/${name}/d' ${RPI_CONFIG_TXT_PATH}"
    cmd_manager "$flag" "$cmd"
    return
  fi

  # Comment all kernel= entrance
  cmd="${sudo_cmd} sed -i '/^kernel=/s/^/#/' ${RPI_CONFIG_TXT_PATH}"
  cmd_manager "$flag" "$cmd"

  # If the target kernel is commented in the file, let's remove it and add it
  # to the end of the file (easier to debug).
  grep --quiet --extended-regexp "#kernel=*.${find_target}" "$RPI_CONFIG_TXT_PATH"
  if [[ "$?" == 0 ]]; then
    cmd="${sudo_cmd} sed -i '/#kernel=*.${find_target}/d' ${RPI_CONFIG_TXT_PATH}"
    cmd_manager "$flag" "$cmd"
  fi

  # Add new kernel to the config file
  cmd="printf \"%s\n\" kernel=${find_target} >> ${RPI_CONFIG_TXT_PATH}"
  if [[ "$target" == 'local' ]]; then
    # Since we have a redirect, we need sh -c
    cmd="${sudo_cmd} sh -c '${cmd}'"
  fi

  cmd_manager "$flag" "$cmd"
}
