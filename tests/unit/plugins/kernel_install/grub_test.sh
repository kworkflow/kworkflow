#!/usr/bin/env bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/grub.sh'
include './src/lib/kwlib.sh'
include './src/lib/kwio.sh'
include './tests/unit/utils.sh'

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

    if [[ "$command" == 'grub-mkconfig' ]]; then
      return 0
    fi

    return 22 # EINVAL
  }

  output=$(run_bootloader_update 'TEST_MODE' 'local')
  expected_cmd='sudo --preserve-env grub-mkconfig --output=/boot/grub/grub.cfg'

  assert_equals_helper 'Local update' "$LINENO" "$expected_cmd" "$output"

  output=$(run_bootloader_update 'TEST_MODE' 'remote')
  expected_cmd='grub-mkconfig --output=/boot/grub/grub.cfg'

  assert_equals_helper 'Remote update' "$LINENO" "$expected_cmd" "$output"

  function command_exists()
  {
    local command="$1"
    local package=${command%% *}

    if [[ "$command" == 'grub2-mkconfig' ]]; then
      return 0
    fi

    return 22 # EINVAL
  }

  output=$(run_bootloader_update 'TEST_MODE' 'local')
  expected_cmd='sudo --preserve-env grub2-mkconfig --output=/boot/grub2/grub.cfg'

  assert_equals_helper 'Local update' "$LINENO" "$expected_cmd" "$output"

  output=$(run_bootloader_update 'TEST_MODE' 'remote')
  expected_cmd='grub2-mkconfig --output=/boot/grub2/grub.cfg'

  assert_equals_helper 'Remote update' "$LINENO" "$expected_cmd" "$output"
}

function test_setup_grub_reboot_for_new_kernel_grub_with_submenus()
{
  local grub_cfg_submenu_path="${SAMPLES_DIR}/grub/grub_cfg_submenus.cfg"
  local kernel_name='6.12.0-GRUB-REBOOT-CHECK+'
  local kernel_image_name="vmlinuz-${kernel_name}"
  local submenu_title='Advanced options for Arch Linux'
  local kernel_entry_title="Arch Linux, with Linux ${kernel_name}"
  local expected_output
  local output

  GRUB_CFG_PATH="$grub_cfg_submenu_path"

  expected_output="grub-reboot '${submenu_title}>${kernel_entry_title}'"
  output=$(setup_grub_reboot_for_new_kernel "$kernel_name" "$kernel_image_name" '' 'TEST_MODE')

  assert_equals_helper 'Grub reboot is wrong' "$LINENO" "$expected_output" "$output"
}

function test_setup_grub_reboot_for_new_kernel_grub_without_submenus()
{
  local grub_cfg_submenu_path="${SAMPLES_DIR}/grub/grub_cfg_no_submenus.cfg"
  local kernel_name='6.12.0-GRUB-REBOOT-CHECK+'
  local kernel_image_name="vmlinuz-${kernel_name}"
  local kernel_entry_title="Arch Linux, with Linux ${kernel_name}"
  local expected_output
  local output

  GRUB_CFG_PATH="$grub_cfg_submenu_path"

  expected_output="grub-reboot '${kernel_entry_title}'"
  output=$(setup_grub_reboot_for_new_kernel "$kernel_name" "$kernel_image_name" '' 'TEST_MODE')

  assert_equals_helper 'Grub reboot is wrong' "$LINENO" "$expected_output" "$output"
}

function test_setup_grub_reboot_for_new_kernel_with_dual_ubuntu_installed()
{
  local grub_cfg_submenu_path="${SAMPLES_DIR}/grub/grub_cfg_dual_ubuntu.cfg"
  local kernel_name='6.14.0-00150-gd1cf3dd25f0c'
  local kernel_image_name="vmlinuz-${kernel_name}"
  local submenu_title='Advanced options for Ubuntu'
  local kernel_entry_title="Ubuntu, with Linux ${kernel_name}"
  local expected_output
  local output

  GRUB_CFG_PATH="$grub_cfg_submenu_path"
  expected_output="grub-reboot '${submenu_title}>${kernel_entry_title}'"
  output=$(setup_grub_reboot_for_new_kernel "$kernel_name" "$kernel_image_name" '' 'TEST_MODE')

  assert_equals_helper 'Grub reboot is wrong' "$LINENO" "$expected_output" "$output"
}

invoke_shunit
