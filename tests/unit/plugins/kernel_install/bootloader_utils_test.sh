#!/usr/bin/env bash

include './src/plugins/kernel_install/bootloader.sh'
include './src/plugins/kernel_install/utils.sh'
include './src/lib/kwlib.sh'
include './tests/unit/utils.sh'

declare -r TEST_ROOT_PATH="$PWD"

declare -a fake_dev

function setUp()
{
  local count=0
  local bootloader_file=''

  # Let's create a fake /dev path
  mkdir -p "${SHUNIT_TMPDIR}/dev"

  # SSD, NVME, HD, SD card
  for dev_path in "${fake_dev[@]}"; do
    touch "$dev_path"
  done

  # Add some noise to the /dev file
  mkdir -p "${SHUNIT_TMPDIR}/dev/sdh"
  mkdir -p "${SHUNIT_TMPDIR}/dev/hdz"

  export DEV_PATH="${SHUNIT_TMPDIR}/dev"

  # Create fake grub path
  bootloader_file="${SHUNIT_TMPDIR}/GRUB_FILES"
  mkdir -p "$bootloader_file"
  for file in "${GRUB[@]}"; do
    file="${bootloader_file}/${file}"
    mkdir -p "${file%/*}" && touch "$file"

    [[ "$count" -lt 5 ]] && break
    ((count++))
  done

  # Create fake syslinux path
  bootloader_file="${SHUNIT_TMPDIR}/SYSLINUX_FILES"
  mkdir -p "$bootloader_file"
  count=0
  for file in "${SYSLINUX[@]}"; do
    file="${bootloader_file}/${file}"
    mkdir -p "${file%/*}" && touch "$file"
    [[ "$count" -lt 3 ]] && break
    ((count++))
  done

  # Create fake rpi path
  bootloader_file="${SHUNIT_TMPDIR}/RPI_FILES"
  mkdir -p "$bootloader_file"
  for file in "${RPI_BOOTLOADER[@]}"; do
    file="${bootloader_file}/${file}"
    mkdir -p "${file%/*}" && touch "$file"
  done
}

function create_binary_file()
{
  local input="$1"
  local save_to="$2"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
}

function test_identify_bootloader()
{
  local output

  output="$(
    function bootctl()
    {
      printf 'no\n'
    }
    identify_bootloader ${SHUNIT_TMPDIR}/GRUB_FILES
  )"
  assertEquals "(${LINENO}): Expected Grub" 'GRUB' "$output"

  output="$(
    function bootctl()
    {
      printf 'no\n'
    }

    identify_bootloader ${SHUNIT_TMPDIR}/SYSLINUX_FILES
  )"
  assertEquals "(${LINENO}): Expected Syslinux" 'SYSLINUX' "$output"

  output="$(
    function bootctl()
    {
      printf 'no\n'
    }

    identify_bootloader ${SHUNIT_TMPDIR}/RPI_FILES
  )"
  assertEquals "(${LINENO}): Expected Raspberry Pi" 'RPI_BOOTLOADER' "$output"

  output="$(
    function bootctl()
    {
      printf 'yes\n'
    }

    function is_bootctl_the_default()
    {
      return 0
    }

    identify_bootloader ${SHUNIT_TMPDIR}
  )"
  assertEquals "(${LINENO}): Expected systemd-boot" 'SYSTEMD_BOOT' "$output"
}

function test_get_esp_base_path_call_bootctl_command()
{
  local output
  local expected_cmd='bootctl --print-esp-path'

  output="$(
    function is_bootctl_the_default()
    {
      return 0
    }

    get_esp_base_path 'remote' 'TEST_MODE'
  )"

  assertEquals "(${LINENO}): Expected bootctl command" "$expected_cmd" "$output"
}

function test_get_esp_base_path_not_supported()
{
  local output
  local expected_cmd='bootctl --print-esp-path'

  output="$(
    function is_bootctl_the_default()
    {
      return 22
    }

    get_esp_base_path 'remote' 'TEST_MODE'
  )"

  assertEquals "(${LINENO}): It should be unsupported" "$?" 95
}

invoke_shunit
