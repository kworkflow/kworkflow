#!/bin/bash

include './unit_tests/utils.sh'
include './src/help.sh'

function test_kworkflow_help()
{
  HELP_OUTPUT=$(kworkflow_help | head -n 1)
  [[ $HELP_OUTPUT =~ Usage:\ kw.* ]]
  assertTrue "Help text not displaying correctly." $?
}

invoke_shunit
