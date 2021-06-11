#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./src/plugins/kernel_install/arch.sh --source-only
. ./src/kwio.sh --source-only
. ./tests/utils --source-only

function suite()
{
  suite_addTest 'update_arch_boot_loader_Test'
  suite_addTest 'generate_arch_temporary_root_file_system_Test'
}

function setUp()
{
  rm -rf "$TMP_TEST_DIR"

  mk_fake_boot "$TMP_TEST_DIR"
}

function tearDown()
{
  rm -rf "$TMP_TEST_DIR"
}

function update_arch_boot_loader_Test()
{
  output=$(update_arch_boot_loader 'xpto' '' 'TEST_MODE')
  cmd=' grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check simple flow' "$LINENO" "$cmd" "$output"

  output=$(update_arch_boot_loader 'xpto' 'local' 'TEST_MODE')
  cmd='sudo -E grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check local deploy' "$LINENO" "$cmd" "$output"
}

function generate_arch_temporary_root_file_system_Test()
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
