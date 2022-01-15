#!/bin/bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/arch.sh'
include './src/kwio.sh'
include './tests/utils.sh'

function setUp()
{
  mk_fake_boot "$SHUNIT_TMPDIR"

  export kw_path='/fake/remote/path'
  export KW_ETC_DIR='/fake/local/path'
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
}

function test_generate_arch_temporary_root_file_system()
{
  local name='xpto'
  local path_prefix=''
  local cmd=
  local sudo_cmd=''
  local qemu_mock_img="$SHUNIT_TMPDIR/mock_image"

  # Local
  sudo_cmd='sudo -E'
  declare -a cmd_sequence=(
    "sudo -E bash -c \"sed 's/NAME/$name/g' '$KW_ETC_DIR/template_mkinitcpio.preset' > /etc/mkinitcpio.d/$name.preset\""
    "$sudo_cmd depmod --all $name"
    "$sudo_cmd mkinitcpio --preset $name"
  )

  output=$(generate_arch_temporary_root_file_system "$name" 'local' 'TEST_MODE')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"

  # Remote
  declare -a cmd_sequence=(
    "bash -c \"sed 's/NAME/$name/g' '$kw_path/template_mkinitcpio.preset' > /etc/mkinitcpio.d/$name.preset\""
    "depmod --all $name"
    "mkinitcpio --preset $name"
  )

  output=$(generate_arch_temporary_root_file_system "$name" 'remote' 'TEST_MODE')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"

  # VM
  touch "$qemu_mock_img"
  configurations[qemu_path_image]="$qemu_mock_img"
  declare -a cmd_sequence=(
    "bash -c \"sed 's/NAME/$name/g' '$KW_ETC_DIR/template_mkinitcpio.preset' > something/etc/mkinitcpio.d/$name.preset\""
    "-> Generating rootfs $name on VM. This can take a few minutes."
    'sleep 0.5s'
    "guestfish --rw -a $qemu_mock_img run       : mount /dev/sda1 / : command 'dracut --regenerate-all -f'"
    'Done.'
  )

  output=$(generate_arch_temporary_root_file_system "$name" 'vm' 'TEST_MODE' 'something')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"
}

invoke_shunit
