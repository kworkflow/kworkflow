#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "human_list_installed_kernels_Test"
  suite_addTest "comman_list_installed_kernels_Test"
}

FAKE_BOOT="tests/.tmp"

function setUp
{
  rm -rf "$FAKE_BOOT"

  mk_fake_boot "$FAKE_BOOT"
}

function tearDown()
{
  rm -rf "$FAKE_BOOT"
}

function human_list_installed_kernels_Test
{
  local count=0

  declare -a expected_out=(
    "" # Extra espace in the beginning
    "5.5.0-rc2-VKMS+"
    "5.6.0-rc2-AMDGPU+"
    "linux"
  )

  output=$(list_installed_kernels "0" "$FAKE_BOOT")
  while read out; do
    assertEquals "$count - Expected kernel list" "${expected_out[$count]}" "$out"
    ((count++))
  done <<< "$output"
}

function comman_list_installed_kernels_Test
{
  local count=0

  declare -a expected_out=(
    "" # Extra espace in the beginning
    "5.5.0-rc2-VKMS+,5.6.0-rc2-AMDGPU+,linux"
  )

  output=$(list_installed_kernels "1" "$FAKE_BOOT")
  while read out; do
    assertEquals "$count - Expected kernel list" "${expected_out[$count]}" "$out"
    ((count++))
  done <<< "$output"

}

invoke_shunit
