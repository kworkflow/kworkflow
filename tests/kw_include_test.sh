#!/bin/bash

include './tests/utils.sh'

function oneTimeSetUp()
{
  KW_LIB_DIR="$PWD/src"
}

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

function test_include_same_name()
{
  local test1_output
  local test2_output
  local test1_expected
  local test2_expected

  include 'tests/samples/include_test'
  include 'tests/samples/include_test_dir/include_test'

  test1_output=$(test1)
  test2_output=$(test2)
  test1_expected='output of test1'
  test2_expected='output of test2'

  assertEquals "($LINENO)" "${test1_output}" "${test1_expected}"
  assertEquals "($LINENO)" "${test2_output}" "${test2_expected}"
}

invoke_shunit
