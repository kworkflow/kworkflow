#!/bin/bash

. ./tests/utils --source-only

function suite
{
  suite_addTest "check_dash_integration_with_kw_Test"
}

function check_dash_integration_with_kw_Test
{
  ./tests/_kw_dash.dsh
  if [ $? -ne 0 ]; then
    fail "Dash was unable to find kw"
  fi
}

invoke_shunit
