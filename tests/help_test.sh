#!/bin/bash

. ./tests/utils --source-only
. ./src/help.sh --source-only

function suite
{
  suite_addTest "kworkflow-help_Test"
}

function kworkflow-help_Test
{
  HELP_OUTPUT=$(kworkflow-help | head -n 1)
  [[ $HELP_OUTPUT =~ Usage:\ kw.* ]]; assertTrue "Help text not displaying correctly." $?
}

invoke_shunit
