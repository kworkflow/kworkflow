#!/bin/bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/debian.sh'
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

function test_update_debian_boot_loader()
{
  output=$(generate_debian_temporary_root_file_system 'TEST_MODE' 'xpto' '' 'GRUB')
  cmd='update-initramfs -c -k xpto'
  assert_equals_helper 'Check simple flow' "$LINENO" "$cmd" "$output"

  output=$(generate_debian_temporary_root_file_system 'TEST_MODE' 'xpto' 'local' 'GRUB')
  cmd='sudo -E update-initramfs -c -k xpto'
  assert_equals_helper 'Check local deploy' "$LINENO" "$cmd" "$output"
}

invoke_shunit
