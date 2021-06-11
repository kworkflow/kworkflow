#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./src/plugins/kernel_install/debian.sh --source-only
. ./src/kwio.sh --source-only
. ./tests/utils --source-only

function suite()
{
  suite_addTest 'update_debian_boot_loader_Test'
}

function setUp()
{
  rm -rf "$TMP_TEST_DIR"

  mk_fake_boot "$TMP_TEST_DIR"
  # parse_configuration "$KW_CONFIG_SAMPLE"
}

function tearDown()
{
  rm -rf "$TMP_TEST_DIR"
}

function update_debian_boot_loader_Test()
{
  output=$(update_debian_boot_loader 'xpto' '' 'TEST_MODE')
  cmd=' grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check simple flow' "$LINENO" "$cmd" "$output"

  output=$(update_debian_boot_loader 'xpto' 'local' 'TEST_MODE')
  cmd='sudo -E grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check local deploy' "$LINENO" "$cmd" "$output"
}

invoke_shunit
