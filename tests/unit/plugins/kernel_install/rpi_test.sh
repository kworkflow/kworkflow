#!/usr/bin/env bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/rpi_bootloader.sh'
include './tests/unit/utils.sh'
include './src/lib/kwlib.sh'

function setUp()
{
  KERNEL_NAME='rpi-kw-5.13.0+'
  FAKE_FW_PATH="${SHUNIT_TMPDIR}/boot/firmware"
  FAKE_RPI_PATH="${FAKE_FW_PATH}/config.txt"
  ORIGINAL_PATH="$PWD"
  STD_KERNEL_NAME='kernel-rpi-config.img'
  KERNEL_IMAGE_NAME="kernel-${KERNEL_NAME}.img"
  INITRAMFS="initrd.img-${KERNEL_NAME}"

  # Overwrite boot path
  BOOT_PATH="${SHUNIT_TMPDIR}/boot"
  BOOT_FIRMWARE_PATH="${BOOT_PATH}/firmware"
  RPI_CONFIG_TXT_PATH="${BOOT_PATH}/firmware/config.txt"

  mkdir --parent "$FAKE_FW_PATH"

  touch "${FAKE_FW_PATH}/${KERNEL_IMAGE_NAME}"
  touch "${FAKE_FW_PATH}/${KERNEL_IMAGE_NAME}.old"
  touch "${FAKE_FW_PATH}/${INITRAMFS}"
  cp "${SAMPLES_DIR}/rpi/config.txt" "$RPI_CONFIG_TXT_PATH"

  # Generate extra kernels/initrd to ensure
  touch "${FAKE_FW_PATH}/kernel-rpi-5.15.img"
  touch "${FAKE_FW_PATH}/initrd.img-rpi-5.15"

  touch "${FAKE_FW_PATH}/kernel-rpi-4.17.img"
  touch "${FAKE_FW_PATH}/initrd.img-rpi-4.17"

  touch "${SHUNIT_TMPDIR}/boot/kernel-rpi-7.17.img"
  touch "${SHUNIT_TMPDIR}/boot/initrd.img-rpi-7.17"

  cd "$SHUNIT_TMPDIR" || {
    fail "(SETUP) It was not possible to cd to temporary directory"
    return
  }
}

function tearDown()
{
  # shellcheck disable=SC2115
  if [[ -d "${FAKE_FW_PATH}" ]]; then
    find "${FAKE_FW_PATH}" -type f -name "*" -exec rm -f {} \;
  fi

  cd "$ORIGINAL_PATH" || {
    fail "(TEARDOWN) It was not possible to cd to temporary directory"
    return
  }
}

function get_kernel_from_config()
{
  grep '^kernel' "${RPI_CONFIG_TXT_PATH}" | cut --delimiter='=' --field=2
}

function test_remote_add_new_image()
{
  local output

  update_config_txt_file 'SILENT' 'remote' "$KERNEL_NAME" "$KERNEL_IMAGE_NAME"
  output=$(get_kernel_from_config)
  assertEquals "(${LINENO}): " "kernel-${KERNEL_NAME}.img" "$output"
}

function test_remote_add_same_kernel_multiple_times()
{
  local output

  update_config_txt_file 'SILENT' 'remote' "$KERNEL_NAME" "$KERNEL_IMAGE_NAME"

  output=$(get_kernel_from_config)
  assertEquals "(${LINENO}): " "kernel-${KERNEL_NAME}.img" "$output"
}

function test_remote_add_two_different_kernels()
{
  local output
  local kernel_image_name_1="kernel-${KERNEL_NAME}-2"
  local kernel_image_name_2="kernel-${KERNEL_NAME}-42"

  touch "${FAKE_FW_PATH}/${kernel_image_name_1}"
  touch "${FAKE_FW_PATH}/${kernel_image_name_2}"

  update_config_txt_file 'SILENT' 'remote' "${KERNEL_NAME}-2" "$kernel_image_name_1"
  update_config_txt_file 'SILENT' 'remote' "${KERNEL_NAME}-42" "$kernel_image_name_2"

  output=$(get_kernel_from_config)
  assertEquals "(${LINENO}): " "kernel-${KERNEL_NAME}-42" "$output"
}

function test_remote_other_files_with_similar_name()
{
  local output
  local kernel_name='CASUAL'
  local kernel_image_name="kernel-${kernel_name}-42"

  touch "${FAKE_FW_PATH}/${kernel_image_name}"
  touch "${FAKE_FW_PATH}/config-${kernel_name}-42"
  update_config_txt_file 'SILENT' 'remote' "${kernel_name}-42" "$kernel_image_name"

  output=$(get_kernel_from_config)
  assertEquals "(${LINENO}): " "kernel-${kernel_name}-42" "$output"
}

function test_remote_add_the_same_kernel_twice()
{
  local output
  local kernel_name='CASUAL'
  local kernel_image_name_1="kernel-${kernel_name}-42"
  local kernel_image_name_2="kernel-${kernel_name}-41"

  touch "${FAKE_FW_PATH}/kernel-${kernel_name}-42"
  touch "${FAKE_FW_PATH}/config-${kernel_name}-42"
  touch "${FAKE_FW_PATH}/kernel-${kernel_name}-41"
  touch "${FAKE_FW_PATH}/config-${kernel_name}-41"

  update_config_txt_file 'SILENT' 'remote' "${kernel_name}-42" "$kernel_image_name_1"
  update_config_txt_file 'SILENT' 'remote' "${kernel_name}-41" "$kernel_image_name_2"
  update_config_txt_file 'SILENT' 'remote' "${kernel_name}-42" "$kernel_image_name_1"
  output=$(get_kernel_from_config)
  assertEquals "(${LINENO}): " "kernel-${kernel_name}-42" "$output"

  output=$(grep "#kernel=kernel-${kernel_name}-42" "${FAKE_RPI_PATH}")
  assertEquals "(${LINENO}): " "" "$output"
}

function test_remote_remove_kernel()
{
  local output

  update_config_txt_file 'SILENT' 'remote' 'rpi-config' "$STD_KERNEL_NAME"

  output=$(get_kernel_from_config)
  assertEquals "(${LINENO}): " '' "$output"
}

function test_remote_remove_kernel_check_around_kernel()
{
  local after
  local before

  # Just confirm match before test
  before=$(grep '^kernel' "${RPI_CONFIG_TXT_PATH}" --after-context=2 --before-context=1)

  update_config_txt_file 'SILENT' 'remote' 'rpi-config' "$STD_KERNEL_NAME"

  after=$(grep '^kernel' "${RPI_CONFIG_TXT_PATH}" --after-context=2 --before-context=1)

  assertNotEquals 'The config.txt was not cleaned correctly' "$after" "$before"
}

function test_local_remove_kernel_coomand_sequence()
{
  local output

  output=$(update_config_txt_file 'TEST_MODE' 'local' "$KERNEL_NAME" "$KERNEL_IMAGE_NAME" 1)

  declare -a expected_cmd=(
    "sudo sed --in-place '80s/^\[all\]/#\[all\]/' ${FAKE_FW_PATH}/config.txt"
    "sudo sed --in-place '/^kernel=/s/^/#/' ${FAKE_FW_PATH}/config.txt"
    "sudo sed --in-place '/^initramfs=/s/^/#/' ${FAKE_FW_PATH}/config.txt"
    "sudo sh -c 'printf \"\n%s\n%s\n%s\n\" '[all]' 'kernel=kernel-${KERNEL_NAME}.img' 'initramfs=${INITRAMFS}' >> ${FAKE_FW_PATH}/config.txt'"
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

invoke_shunit
