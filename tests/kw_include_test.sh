#!/bin/bash

include './tests/utils'

function suite()
{
  suite_addTest 'include_Test'
  suite_addTest 'include_twice_Test'
  suite_addTest 'include_wrong_path_Test'
}

function include_Test()
{
  include ./src/kwio.sh
  output="$KWIO_IMPORTED"
  assertEquals "($LINENO)" 1 "$output"
}

function include_twice_Test()
{
  include ./src/kwlib.sh
  include ./src/kwlib.sh
  ret="$?"
  assertEquals "($LINENO)" 0 "$ret"
}

function include_wrong_path_Test()
{
  output=$(include ./src/batata.sh)
  ret="$?"
  assertEquals "($LINENO)" 2 "$ret"
}

invoke_shunit
