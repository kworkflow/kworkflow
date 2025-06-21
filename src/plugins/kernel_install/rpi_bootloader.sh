# This file is specific to the raspberry pi bootloader, and since it is part
# of kw, it follows the bootloader API. In other words, we have two entry
# point functions:
# 1. run_bootloader_update: Update GRUB in a local and remote machine.
# 2. run_bootloader_for_vm: Update GRUB in a virtual machine.

BOOT_PATH='/boot'
BOOT_FIRMWARE_PATH="${BOOT_PATH}/firmware"
RPI_CONFIG_TXT_PATH="${BOOT_PATH}/firmware/config.txt"

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
  local kernel_image_name="$4"
  local find_target
  local sudo_cmd

  [[ "$target" == 'local' ]] && sudo_cmd='sudo'

  if [[ -z "$name" ]]; then
    return
  fi

  move_kernel_files_to_firmware_folder "$kernel_image_name" "$BOOT_FIRMWARE_PATH" "$name" "$sudo_cmd" '/boot' "$flag"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    return "$ret"
  fi

  update_config_txt_file "$flag" "$target" "$name" "$kernel_image_name" "$sudo_cmd"
}

# This function manages kernel addition, removal, and update from the
# config.txt file. Notice that addition and removal depend on the existence of
# the kernel file; for example, if the kernel name specified does not have a
# correspondent binary file and is present in the config.txt, this function
# will remove it from the config.txt.
#
# @flag: How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @name: Kernel name used during the deploy
# @kernel_img_name: Kernel image file name, e.g., bzImage or Image.
# @sudo_cmd: If the deploy is for local, this parameter should be set to any value.
function update_config_txt_file()
{
  local flag="$1"
  local target="$2"
  local name="$3"
  local kernel_image_name="$4"
  local sudo_cmd="$5"
  local kernel_name
  local label_line_number
  local ret

  if [[ -n "$sudo_cmd" ]]; then
    sudo_cmd='sudo '
  fi

  # Find kernel && initrd
  kernel_name=$(find "$BOOT_PATH" -name "*${kernel_image_name}*" -not -name '*.old' -not -name 'config-*' -not -name 'initrd*')
  kernel_name=$(basename "$kernel_name")

  init_name=$(find_initramfs "$BOOT_FIRMWARE_PATH" "$name")

  # Check if the kernel name were already added to config.txt
  grep --quiet --extended-regexp "^kernel=*.${kernel_name}" "$RPI_CONFIG_TXT_PATH"
  if [[ "$?" == 0 && -n "$kernel_name" ]]; then
    return
  fi

  label_line_number=$(get_the_all_tag_position_in_the_file)
  ret="$?"

  # If we find a kernel name in the config file, and no kernel image we
  # want to remove that reference.
  if [[ -z "$kernel_name" ]]; then
    # Remove the extra [all] label
    if [[ "$ret" == 0 ]]; then
      cmd="${sudo_cmd}sed --in-place '${label_line_number}d' ${RPI_CONFIG_TXT_PATH}"
      cmd_manager "$flag" "$cmd"
    fi

    # Remove kernel/initramfs entries
    cmd="${sudo_cmd}sed --in-place '/${name}/d' ${RPI_CONFIG_TXT_PATH}"
    cmd_manager "$flag" "$cmd"
    return
  fi

  # Comment the [all] label
  if [[ "$ret" == 0 ]]; then
    cmd="${sudo_cmd}sed --in-place '${label_line_number}s/^\[all\]/#\[all\]/' ${RPI_CONFIG_TXT_PATH}"
    cmd_manager "$flag" "$cmd"
  fi

  # Comment all kernel= entrance
  cmd="${sudo_cmd}sed --in-place '/^kernel=/s/^/#/' ${RPI_CONFIG_TXT_PATH}"
  cmd_manager "$flag" "$cmd"

  # Comment all initramfs= entrance
  cmd="${sudo_cmd}sed --in-place '/^initramfs=/s/^/#/' ${RPI_CONFIG_TXT_PATH}"
  cmd_manager "$flag" "$cmd"

  # If the target kernel/initramfs is commented in the file, let's remove it
  # and add it to the end of the file (easier to debug).
  grep --quiet --extended-regexp "#kernel=*.${kernel_name}" "$RPI_CONFIG_TXT_PATH"
  if [[ "$?" == 0 ]]; then
    cmd="${sudo_cmd}sed --in-place '/#kernel=*.${find_target}/d' ${RPI_CONFIG_TXT_PATH}"
    cmd_manager "$flag" "$cmd"
  fi

  grep --quiet --extended-regexp "#initramfs=*.${init_name}" "$RPI_CONFIG_TXT_PATH"
  if [[ "$?" == 0 ]]; then
    cmd="${sudo_cmd}sed --in-place '/#initramfs=*.${init_name}/d' $RPI_CONFIG_TXT_PATH"
    cmd_manager "$flag" "$cmd"
  fi

  # Add new kernel/initramfs to the config file
  cmd="printf \"\n%s\n%s\n%s\n\" '[all]' 'kernel=${kernel_name}' 'initramfs=${init_name}' >> ${RPI_CONFIG_TXT_PATH}"
  if [[ "$target" == 'local' ]]; then
    # Since we have a redirect, we need sh -c
    cmd="${sudo_cmd}sh -c '${cmd}'"
  fi

  cmd_manager "$flag" "$cmd"
}

function get_the_all_tag_position_in_the_file()
{
  local output

  # Output should looks likes this:
  # 80-[all]
  # 81:kernel=kernel-rpi-config.img
  output=$(grep --line-number "^kernel=" "${RPI_CONFIG_TXT_PATH}" --before-context=1)
  [[ "$?" != 0 ]] && return 21 # EINVAL

  # Collect the line number for the label
  output=$(printf '%s\n' "$output" | grep --ignore-case '\[all\]' | cut --delimiter='-' --fields=1)
  [[ "$?" != 0 ]] && return 22 # EINVAL

  # Check if output is a number
  if [[ "$output" =~ ^[-]?[0-9]+$ ]]; then
    printf '%s' "$output"
    return 0
  fi
  return 24 # EINVAL
}

function find_initramfs()
{
  local base_src_path="$1"
  local name="$2"
  local init_name

  init_name=$(find ${base_src_path} -maxdepth 1 -name "init*-${name}*" -printf '%f\n')
  [[ ! -f "${base_src_path}/${init_name}" ]] && return 2 # ENOENT

  printf '%s' "$init_name"
}

function move_kernel_files_to_firmware_folder()
{
  local kernel_image_name="$1"
  local kernel_target_folder="$2"
  local name="$3"
  local sudo_cmd="$4"
  local base_src_path="$5"
  local flag="$6"
  local cmd
  local init_name
  local error=0
  local dtb_files

  flag=${flag:-'SILENT'}

  # Before take any action, let's first run some checks
  if [[ ! -d ${kernel_target_folder} ]]; then
    printf '\t%s\n' "ERROR: The requested folder to store the kernel files does not exists: ${kernel_target_folder}"
    error=1
  fi

  if [[ ! -f "${base_src_path}/${kernel_image_name}" ]]; then
    printf '\t%s\n' "ERROR: failed to find kernel image: ${base_src_path}/${kernel_image_name}"
    error=1
  fi

  init_name=$(find_initramfs "$base_src_path" "$name")
  if [[ "$?" != 0 ]]; then
    printf '\t%s\n' "ERROR: failed to find kernel initrd: ${base_src_path}/${init_name}"
    error=1
  fi

  if [[ ! -f "${base_src_path}/config-${name}" ]]; then
    printf '\t%s\n' "WARNING: failed to find kernel config file: ${base_src_path}/config-${name}"
  fi

  if [[ "$error" == 1 ]]; then
    return 2 # ENOENT
  fi

  # Copy dtbs to /boot if exist
  dtb_files=$(find "${KW_DEPLOY_TMP_FILE}/kw_pkg" -type f -name '*.dtb')
  if [[ -n "$dtb_files" ]]; then
    cmd="${sudo_cmd}cp ${KW_DEPLOY_TMP_FILE}/kw_pkg/*.dtb ${BOOT_FIRMWARE_PATH}"
    cmd_manager "$flag" "$cmd"
  fi

  # If there is no errors, move files to the right place
  cmd="${sudo_cmd}mv ${base_src_path}/${kernel_image_name} ${kernel_target_folder}/${kernel_image_name}"
  cmd_manager "$flag" "$cmd"

  cmd="${sudo_cmd}mv ${base_src_path}/${init_name} ${kernel_target_folder}/${init_name}"
  cmd_manager "$flag" "$cmd"

  if [[ -f "${base_src_path}/config-${name}" ]]; then
    cmd="${sudo_cmd}mv ${base_src_path}/config-${name} ${kernel_target_folder}/config-${name}"
    cmd_manager "$flag" "$cmd"
  fi
}
