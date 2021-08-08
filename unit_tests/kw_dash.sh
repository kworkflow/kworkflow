#!/bin/bash

include './unit_tests/utils.sh'

function test_check_dash_integration_with_kw()
{
  ./unit_tests/_kw_dash.dsh
  if [ $? -ne 0 ]; then
    fail "Dash was unable to find kw"
  fi
}

invoke_shunit
