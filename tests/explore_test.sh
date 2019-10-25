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
  MSG_OUT="camel_case(void)"
  assertEquals "$MSG_OUT" "$(explore "camel_case" tests/samples | cut -d ' ' -f2 | sed -n -e 2p)"
  assertEquals "$LOG_OUT" "$(explore log LICENSE | grep "Initial commit" | awk '{print $1, $2}')"
  true
}

invoke_shunit
