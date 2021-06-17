#!/bin/bash

include './tests/utils.sh'

function test_include()
{
  include ./src/kwio.sh
  output="$KWIO_IMPORTED"
  assertEquals "($LINENO)" 1 "$output"
}

function test_include_twice()
{
  include ./src/kwlib.sh
  include ./src/kwlib.sh
  ret="$?"
  assertEquals "($LINENO)" 0 "$ret"
}

function test_include_wrong_path()
{
  output=$(include ./src/batata.sh)
  ret="$?"
  assertEquals "($LINENO)" 2 "$ret"
}

invoke_shunit
