#!/bin/bash

include './tests/unit/utils.sh'
include './src/help.sh'

function test_kworkflow_help()
{
  HELP_OUTPUT=$(kworkflow_help | head -n 1)
  [[ $HELP_OUTPUT =~ Usage:\ kw.* ]]
  assertTrue "Help text not displaying correctly." $?
}

function test_kworkflow_man()
{
  export KW_MAN_DIR="$SHUNIT_TMPDIR"
  touch "$SHUNIT_TMPDIR/kw.1"
  expect="man -l $SHUNIT_TMPDIR/kw.1"
  output=$(kworkflow_man '' 'TEST_MODE')
  assertEquals "($LINENO) We expected kw general man." "$expect" "$output"
  rm "$SHUNIT_TMPDIR/kw.1"

  touch "$SHUNIT_TMPDIR/kw-feature.1"
  expect="man -l $SHUNIT_TMPDIR/kw-feature.1"
  output=$(kworkflow_man 'feature' 'TEST_MODE')
  assertEquals "($LINENO) We expected feature specific man." "$expect" "$output"
  rm "$SHUNIT_TMPDIR/feature.1"

  expect="Couldn't find the man page for kw-error!"
  output=$(kworkflow_man 'error' 'TEST_MODE')
  ret="$?"
  assertEquals "($LINENO) We expected an error." "$ret" 2
  assertEquals "($LINENO) We expected an error message." "$expect" "$output"
}

invoke_shunit
