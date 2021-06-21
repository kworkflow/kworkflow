#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./src/plugins/kernel_install/arch.sh --source-only
. ./src/kwio.sh --source-only
. ./tests/utils.sh --source-only

function setUp()
{
  mk_fake_boot "$SHUNIT_TMPDIR"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
}

function test_update_arch_boot_loader()
{
  output=$(update_arch_boot_loader 'xpto' '' 'TEST_MODE')
  cmd=' grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check simple flow' "$LINENO" "$cmd" "$output"

  output=$(update_arch_boot_loader 'xpto' 'local' 'TEST_MODE')
  cmd='sudo -E grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check local deploy' "$LINENO" "$cmd" "$output"
}

function test_generate_arch_temporary_root_file_system()
{
  local name='xpto'
  local path_prefix=''
  local cmd=
  local sudo_cmd=''
  local LOCAL_KW_ETC="$KW_ETC_DIR/template_mkinitcpio.preset"

  # Local
  sudo_cmd='sudo -E'
  declare -a cmd_sequence=(
    "$sudo_cmd cp -v $LOCAL_KW_ETC $path_prefix/etc/mkinitcpio.d/$name.preset"
    "$sudo_cmd sed -i -e \"s/NAME/$name/g\" \"$path_prefix/etc/mkinitcpio.d/$name.preset\""
    "$sudo_cmd mkinitcpio -p $name"
  )

  output=$(generate_arch_temporary_root_file_system "$name" 'local' 'TEST_MODE' '')
  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"

  # Remote
  declare -a cmd_sequence=(
    "cp -v $name.preset $path_prefix/etc/mkinitcpio.d/"
    "mkinitcpio -p $name"
  )

  output=$(generate_arch_temporary_root_file_system "$name" 'remote' 'TEST_MODE' '')
  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"

  # VM
  sudo_cmd=''
  declare -a cmd_sequence=(
    "cp -v $LOCAL_KW_ETC $path_prefix/etc/mkinitcpio.d/$name.preset"
    "sed -i -e \"s/NAME/$name/g\" \"$path_prefix/etc/mkinitcpio.d/$name.preset\""
  )

  output=$(generate_arch_temporary_root_file_system "$name" 'vm' 'TEST_MODE' '')
  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"
}

invoke_shunit
