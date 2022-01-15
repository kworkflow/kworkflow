#!/bin/bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/grub.sh'
include './src/kwio.sh'
include './tests/utils.sh'

function setUp()
{
  FAKE_VM_IMG="$SHUNIT_TMPDIR/fake_vm"
  touch "$FAKE_VM_IMG"
}

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

function test_run_bootloader_for_vm()
{
  local name='xpto'
  local output
  local cmd_grub="$DEFAULT_GRUB_CMD_UPDATE"
  local mount_root=': mount /dev/sda1 /'
  local mkdir_grub=': mkdir-p /boot/grub'
  local setup_grub=": write /boot/grub/device.map '(hd0,1) /dev/sda'"
  local grub_install='grub-install --directory=/usr/lib/grub/i386-pc --target=i386-pc --boot-directory=/boot --recheck --debug /dev/sda'
  local guest_fish_cmd

  # No vm
  output=$(run_bootloader_for_vm 'TEST_MODE')
  assertEquals "($LINENO)" 125 "$?"

  # Normal flow
  configurations[qemu_path_image]="$FAKE_VM_IMG"

  # Let's replace vm_umount function
  function vm_umount()
  {
    printf 'vm_umount'
  }

  guest_fish_cmd="guestfish --rw -a ${configurations[qemu_path_image]} run \
      $mount_root \
      $mkdir_grub $setup_grub : command '$grub_install' \
      : command '$cmd_grub'"

  declare -a cmd_sequence=(
    "-> Updating grub for $name on VM. This can take a few minutes."
    'sleep 0.5s'
    "$guest_fish_cmd"
    'Done.'
  )

  output=$(run_bootloader_for_vm 'TEST_MODE')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"
}

invoke_shunit
