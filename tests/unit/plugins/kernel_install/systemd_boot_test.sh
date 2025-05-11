#!/usr/bin/env bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/systemd_boot.sh'
include './src/lib/kwio.sh'
include './src/lib/kwlib.sh'
include './src/lib/kw_string.sh'
include './tests/unit/utils.sh'

function test_setup_systemd_reboot_for_new_kernel()
{
  local output
  local expected_output='bootctl set-oneshot CUSTOM-KERNEL+.conf'

  output="$(
    function bootctl()
    {
      return
    }

    function jq()
    {
      printf 'CUSTOM-KERNEL+.conf\n'
    }

    setup_systemd_reboot_for_new_kernel 'CUSTOM-KERNEL+' '' 'TEST_MODE'
  )"

  assert_equals_helper 'set-oneshot is wrong' "(${LINENO})" "$expected_output" "$output"
}

invoke_shunit
