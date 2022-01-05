#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./src/plugins/kernel_install/arch.sh --source-only
. ./src/kwio.sh --source-only
. ./tests/utils.sh --source-only

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
  configurations[qemu_path_image]='path/image'
  declare -a cmd_sequence=(
    "bash -c \"sed 's/NAME/$name/g' '$KW_ETC_DIR/template_mkinitcpio.preset' > something/etc/mkinitcpio.d/$name.preset\""
    "-> Generating rootfs $name on VM. This can take a few minutes."
    'sleep 0.5s'
    "guestfish --rw -a path/image run       : mount /dev/sda1 / : command 'dracut --regenerate-all -f'"
    'Done.'
  )

  output=$(generate_arch_temporary_root_file_system "$name" 'vm' 'TEST_MODE' 'something')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"
}

invoke_shunit
