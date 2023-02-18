#!/bin/bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/grub.sh'
include './src/kwio.sh'
include './tests/utils.sh'

function test_grub()
{
  local output
  local expected_cmd

  function command_exists()
  {
    local command="$1"
    local package=${command%% *}

    return 22 # EINVAL
  }

  output=$(run_bootloader_update 'TEST_MODE' 'local')
  ret="$?"
  assert_equals_helper 'Local update' "$LINENO" '125' "$ret"

  output=$(run_bootloader_update 'TEST_MODE' 'remote')
  ret="$?"
  assert_equals_helper 'Remote update' "$LINENO" '125' "$ret"

  function command_exists()
  {
    local command="$1"
    local package=${command%% *}

    if [[ $command == 'grub-mkconfig' ]]; then
      return 0
    fi

    return 22 # EINVAL
  }

  output=$(run_bootloader_update 'TEST_MODE' 'local')
  expected_cmd='sudo -E grub-mkconfig -o /boot/grub/grub.cfg'

  assert_equals_helper 'Local update' "$LINENO" "$expected_cmd" "$output"

  output=$(run_bootloader_update 'TEST_MODE' 'remote')
  expected_cmd='grub-mkconfig -o /boot/grub/grub.cfg'

  assert_equals_helper 'Remote update' "$LINENO" "$expected_cmd" "$output"

  function command_exists()
  {
    local command="$1"
    local package=${command%% *}

    if [[ $command == 'grub2-mkconfig' ]]; then
      return 0
    fi

    return 22 # EINVAL
  }

  output=$(run_bootloader_update 'TEST_MODE' 'local')
  expected_cmd='sudo -E grub2-mkconfig -o /boot/grub2/grub.cfg'

  assert_equals_helper 'Local update' "$LINENO" "$expected_cmd" "$output"

  output=$(run_bootloader_update 'TEST_MODE' 'remote')
  expected_cmd='grub2-mkconfig -o /boot/grub2/grub.cfg'

  assert_equals_helper 'Remote update' "$LINENO" "$expected_cmd" "$output"
}

invoke_shunit
