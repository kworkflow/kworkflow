#!/bin/bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/debian.sh'
include './src/kwio.sh'
include './tests/utils.sh'

function setUp()
{
  FAKE_VM_IMG="$SHUNIT_TMPDIR/fake_vm"

  mk_fake_boot "$SHUNIT_TMPDIR"

  touch "$FAKE_VM_IMG"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
}

function test_update_debian_boot_loader()
{
  output=$(generate_debian_temporary_root_file_system 'TEST_MODE' 'xpto' '' 'GRUB')
  cmd='update-initramfs -c -k xpto'
  assert_equals_helper 'Check simple flow' "$LINENO" "$cmd" "$output"

  output=$(generate_debian_temporary_root_file_system 'TEST_MODE' 'xpto' 'local' 'GRUB')
  cmd='sudo -E update-initramfs -c -k xpto'
  assert_equals_helper 'Check local deploy' "$LINENO" "$cmd" "$output"
}

function test_generate_rootfs_with_libguestfs()
{
  local name='xpto'
  local qemu_mock_img="$SHUNIT_TMPDIR/mock_image"
  local mount_root=': mount /dev/sda1 /'
  local cmd_init="update-initramfs -c -k $name"
  local guest_fish_cmd

  # No vm
  output=$(generate_rootfs_with_libguestfs 'TEST_MODE' "$name")
  assertEquals "($LINENO)" 125 "$?"

  # Normal flow
  configurations[qemu_path_image]="$FAKE_VM_IMG"
  guest_fish_cmd="guestfish --rw -a ${configurations[qemu_path_image]} run \
      $mount_root : command '$cmd_init'"

  declare -a cmd_sequence=(
    "-> Generating rootfs $name on VM. This can take a few minutes."
    'sleep 0.5s'
    "$guest_fish_cmd"
    'Done.'
  )

  # Let's replace vm_umount function
  function vm_umount()
  {
    printf 'vm_umount'
  }

  output=$(generate_rootfs_with_libguestfs 'TEST_MODE' "$name")
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
}

invoke_shunit
