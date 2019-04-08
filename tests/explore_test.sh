#!/bin/bash

. ./tests/utils --source-only
. ./src/explore.sh --source-only

function suite
{
  suite_addTest "testExplore"
}

function testExplore
{
  local MSG_OUT="GNU"
  local LOG_OUT="Initial commit"

  assertEquals "Expected an error message." "Expected path or 'log'" "$(explore)"
  assertEquals "$MSG_OUT nopath" "$(explore LICENSE | grep -m 1 "$MSG_OUT" | awk '{print $2}') nopath"
  assertEquals "$MSG_OUT path" "$(explore "$MSG_OUT" tests | grep "$MSG_OUT" | cut -d '"' -f2) path"
  assertEquals "$LOG_OUT" "$(explore log LICENSE | grep "Initial commit" | awk '{print $1, $2}')"
  true
}

invoke_shunit
