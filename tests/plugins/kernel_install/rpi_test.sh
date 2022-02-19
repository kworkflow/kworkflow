#!/bin/bash

include './src/plugins/kernel_install/rpi_bootloader.sh'
include './tests/utils.sh'

function setUp()
{
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

function tearDown()
{
  cd "$ORIGINAL_PATH" || {
    fail "(TEARDOWN) It was not possible to cd to temporary directory"
    return
  }

  # shellcheck disable=SC2115
  [[ -d "${FAKE_RPI_PATH}" ]] && rm -rf "${FAKE_RPI_PATH}/*"
}

function get_kernel_from_config()
{
  grep '^kernel' 'config.txt' | cut -d '=' -f2
}

function test_add_new_image()
{
  local output

  run_bootloader_update 'TEST_MODE' '' "$KERNEL_NAME"
  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " "kernel-$KERNEL_NAME.img" "$output"
}

function test_add_same_kernel_multiple_times()
{
  local output

  run_bootloader_update 'TEST_MODE' '' "$KERNEL_NAME"
  run_bootloader_update 'TEST_MODE' '' "$KERNEL_NAME"

  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " "kernel-$KERNEL_NAME.img" "$output"
}

function test_add_two_different_kernels()
{
  local output

  touch "kernel-${KERNEL_NAME}-2"
  touch "kernel-${KERNEL_NAME}-42"

  run_bootloader_update 'TEST_MODE' '' "$KERNEL_NAME-2"
  run_bootloader_update 'TEST_MODE' '' "$KERNEL_NAME-42"

  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " "kernel-$KERNEL_NAME-42" "$output"
}

function test_other_files_with_similar_name()
{
  local output
  local kernel_name='CASUAL'

  touch "kernel-${kernel_name}-42"
  touch "config-${kernel_name}-42"
  run_bootloader_update 'TEST_MODE' '' "$kernel_name-42"

  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " "kernel-$kernel_name-42" "$output"
}

function test_remove_kernel()
{
  local output

  run_bootloader_update 'TEST_MODE' '' "$STD_KERNEL_NAME"

  output=$(get_kernel_from_config)
  assertEquals "($LINENO): " '' "$output"
}

invoke_shunit
