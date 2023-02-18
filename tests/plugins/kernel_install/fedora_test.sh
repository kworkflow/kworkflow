#!/bin/bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/fedora.sh'
include './src/kwio.sh'
include './tests/utils.sh'

function setUp()
{
  mk_fake_boot "$SHUNIT_TMPDIR"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
}

function test_update_fedora_boot_loader()
{

  declare -a cmd_sequence=(
    'grub2-editenv - unset menu_auto_hide'
    'sed -i -e '\'s/GRUB_ENABLE_BLSCFG=true/GRUB_ENABLE_BLSCFG=false/g\'' /etc/default/grub'
    'dracut --force --kver xpto'
  )

  output=$(generate_fedora_temporary_root_file_system 'TEST_MODE' 'xpto' '' 'GRUB')
  compare_command_sequence 'Check simple flow' "$LINENO" 'cmd_sequence' "$output"

  declare -a cmd_sequence=(
    'sudo -E grub2-editenv - unset menu_auto_hide'
    'sudo -E sed -i -e '\'s/GRUB_ENABLE_BLSCFG=true/GRUB_ENABLE_BLSCFG=false/g\'' /etc/default/grub'
    'sudo -E dracut --force --kver xpto'
  )

  output=$(generate_fedora_temporary_root_file_system 'TEST_MODE' 'xpto' 'local' 'GRUB')
  compare_command_sequence 'Check local deploy' "$LINENO" 'cmd_sequence' "$output"
}

invoke_shunit
