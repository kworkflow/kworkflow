#!/bin/bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/grub.sh'
include './tests/utils.sh'

function test_grub()
{
  local output
  local expected_cmd

  output=$(run_bootloader_update 'TEST_MODE' 'local')
  expected_cmd='sudo -E grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Local update' "$LINENO" "$expected_cmd" "$output"

  output=$(run_bootloader_update 'TEST_MODE' 'remote')
  expected_cmd='grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Remote update' "$LINENO" "$expected_cmd" "$output"
}

invoke_shunit
