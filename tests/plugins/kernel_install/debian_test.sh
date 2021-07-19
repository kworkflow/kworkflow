#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./src/plugins/kernel_install/debian.sh --source-only
. ./src/kwio.sh --source-only
. ./tests/utils.sh --source-only

function setUp()
{
  mk_fake_boot "$SHUNIT_TMPDIR"
  # parse_configuration "$KW_CONFIG_SAMPLE"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
}

function test_update_debian_boot_loader()
{
  output=$(update_debian_boot_loader 'xpto' '' 'TEST_MODE')
  cmd='grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check simple flow' "$LINENO" "$cmd" "$output"

  output=$(update_debian_boot_loader 'xpto' 'local' 'TEST_MODE')
  cmd='sudo -E grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check local deploy' "$LINENO" "$cmd" "$output"
}

invoke_shunit
