#!/bin/bash

. ./tests/utils --source-only
. ./src/utils.sh --source-only

function suite
{
  suite_addTest "testHelp"
  suite_addTest "testExplore"
}

function testHelp
{
  HELP_OUTPUT=$(kworkflow-help | head -n 1)
  [[ $HELP_OUTPUT =~ Usage:\ kw.* ]]; assertTrue "Help text not displaying correctly." $?
}

MSG_OUT="GNU"
LOG_OUT="Initial commit"

function testExplore
{
  assertEquals "Expected an error message." "Expected path or 'log'" "$(explore)"
  assertEquals "$MSG_OUT nopath" "$(explore LICENSE | grep "$MSG_OUT" | awk '{print $2}') nopath"
  assertEquals "$MSG_OUT path" "$(explore "$MSG_OUT" tests | grep "$MSG_OUT" | cut -d '"' -f2) path"
  assertEquals "$LOG_OUT" "$(explore log LICENSE | grep "Initial commit" | awk '{print $1, $2}')"
  true
}

invoke_shunit
