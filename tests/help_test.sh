#!/bin/bash

include './tests/utils'
include './src/help.sh'

function suite
{
  suite_addTest "kworkflow_help_Test"
}

function kworkflow_help_Test
{
  HELP_OUTPUT=$(kworkflow_help | head -n 1)
  [[ $HELP_OUTPUT =~ Usage:\ kw.* ]]; assertTrue "Help text not displaying correctly." $?
}

invoke_shunit
