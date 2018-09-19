#!/bin/bash

. ./tests/utils --source-only
. ./src/utils.sh --source-only

function suite
{
  suite_addTest "testHelp"
}

function testHelp
{
  HELP_OUTPUT=$(kworkflow-help | head -n 1)
  [[ $HELP_OUTPUT =~ Usage:\ kw.* ]]; assertTrue "Help text not displaying correctly." $?
}

invoke_shunit
