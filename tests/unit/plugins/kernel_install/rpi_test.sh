#!/usr/bin/env bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/rpi_bootloader.sh'
include './tests/unit/utils.sh'

function setUp() {
  KERNEL_NAME='rpi-kw-5.13.0+'
  FAKE_RPI_PATH="$SHUNIT_TMPDIR"
  ORIGINAL_PATH="$PWD"
  RPI_CONFIG_TXT_PATH="${FAKE_RPI_PATH}/config.txt"
  BOOT_PATH="$FAKE_RPI_PATH"
  STD_KERNEL_NAME='kernel-rpi-config.img'

  touch "${FAKE_RPI_PATH}/kernel-${KERNEL_NAME}.img"
  touch "${FAKE_RPI_PATH}/kernel-${KERNEL_NAME}.img.old"
  cp "$SAMPLES_DIR/rpi/config.txt" "$FAKE_RPI_PATH"

  cd "$FAKE_RPI_PATH" || {
    fail "(SETUP) It was not possible to cd to temporary directory"
    return
  }
}

function tearDown() {
  # shellcheck disable=SC2115
  if [[ -d "${FAKE_RPI_PATH}" ]]; then
    find "${FAKE_RPI_PATH}" -type f -name "*" -exec rm -f {} \;
  fi

  cd "$ORIGINAL_PATH" || {
    fail "(TEARDOWN) It was not possible to cd to temporary directory"
    return
  }
}

function get_kernel_from_config() {
  grep '^kernel' 'config.txt' | cut -d '=' -f2
}

function test_remote_add_new_image() {
  local output

  run_bootloader_update 'SILENT' 'remote' "$KERNEL_NAME"
  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " "kernel-$KERNEL_NAME.img" "$output"
}

function test_remote_add_same_kernel_multiple_times() {
  local output

  run_bootloader_update 'SILENT' 'remote' "$KERNEL_NAME"
  run_bootloader_update 'SILENT' 'remote' "$KERNEL_NAME"

  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " "kernel-$KERNEL_NAME.img" "$output"
}

function test_remote_add_two_different_kernels() {
  local output

  touch "kernel-${KERNEL_NAME}-2"
  touch "kernel-${KERNEL_NAME}-42"

  run_bootloader_update 'SILENT' 'remote' "$KERNEL_NAME-2"
  run_bootloader_update 'SILENT' 'remote' "$KERNEL_NAME-42"

  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " "kernel-$KERNEL_NAME-42" "$output"
}

function test_remote_other_files_with_similar_name() {
  local output
  local kernel_name='CASUAL'

  touch "kernel-${kernel_name}-42"
  touch "config-${kernel_name}-42"
  run_bootloader_update 'SILENT' 'remote' "$kernel_name-42"

  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " "kernel-$kernel_name-42" "$output"
}

function test_remote_add_the_same_kernel_twice() {
  local output
  local kernel_name='CASUAL'

  touch "kernel-${kernel_name}-42"
  touch "config-${kernel_name}-42"

  touch "kernel-${kernel_name}-41"
  touch "config-${kernel_name}-41"

  run_bootloader_update 'SILENT' 'remote' "$kernel_name-42"
  run_bootloader_update 'SILENT' 'remote' "$kernel_name-41"
  run_bootloader_update 'SILENT' 'remote' "$kernel_name-42"

  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " "kernel-$kernel_name-42" "$output"

  output=$(grep "#kernel=kernel-$kernel_name-42" 'config.txt')
  assertEquals "($LINENO): " "" "$output"
}

function test_remote_remove_kernel() {
  local output

  run_bootloader_update 'SILENT' 'remote' "$STD_KERNEL_NAME"

  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " '' "$output"
}

function test_local_remove_kernel() {
  local output

  output=$(run_bootloader_update 'TEST_MODE' 'local' "$KERNEL_NAME")

  declare -a expected_cmd=(
    "sudo sed -i '/^kernel=/s/^/#/' ${FAKE_RPI_PATH}/config.txt"
    "sudo sh -c 'printf \"%s\n\" kernel=kernel-${KERNEL_NAME}.img >> ${FAKE_RPI_PATH}/config.txt'"
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

invoke_shunit
