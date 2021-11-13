#!/bin/bash

include './tests/utils.sh'

function oneTimeSetUp()
{
  # specifies where to source the lib
  KW_LIB_DIR="$PWD/src"

  # we'll use these folders to run our tests
  KW_INC_TEST_PATH="$SHUNIT_TMPDIR/inc_test"
  KW_INC_TEST_SPACED_PATH="$SHUNIT_TMPDIR/inc test"
  KW_INC_TEST_HIDDEN_PATH="$SHUNIT_TMPDIR/.inc_test"
  mkdir "$KW_INC_TEST_PATH" \
    "$KW_INC_TEST_SPACED_PATH" \
    "$KW_INC_TEST_HIDDEN_PATH"

  # those test files can be empty, as we're only testing the created varname
  test_files=(
    "$KW_INC_TEST_HIDDEN_PATH/include_hidden.sh"
    "$KW_INC_TEST_HIDDEN_PATH/include_test.sh"
    "$KW_INC_TEST_SPACED_PATH/include_spaced.sh"
    "$KW_INC_TEST_PATH/include_test.sh"
    "$KW_INC_TEST_PATH/include-dashed.sh"
  )

  touch "${test_files[@]}"

  # the next files will be checked for name collisions
  printf "%s\n" "function test1(){ printf '%s\n' 'output of test1';}" > \
    "$SHUNIT_TMPDIR/include_test_same_name"

  printf "%s\n" "function test2(){ printf '%s\n' 'output of test2';}" > \
    "$KW_INC_TEST_PATH/include_test_same_name"

  printf "%s\n" "function test3(){ printf '%s\n' 'output of test3';}" > \
    "$KW_INC_TEST_PATH/include_test_similar_path.sh"

  printf "%s\n" "function test4(){ printf '%s\n' 'output of test4';}" > \
    "$KW_INC_TEST_HIDDEN_PATH/include_test_similar_path.sh"
}

function oneTimeTearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
  mkdir -p "$SHUNIT_TMPDIR"
}

function test_include()
{
  include ./src/kwio.sh
  output="$KWIO_SH_IMPORTED"
  assertEquals "($LINENO)" 1 "$output"
}

function test_include_twice()
{
  include ./src/kwlib.sh
  include ./src/kwlib.sh
  assertEquals "($LINENO)" 0 "$?"
}

function test_include_wrong_path()
{
  output=$(include ./src/batata.sh)
  assertEquals "($LINENO)" 2 "$?"
}

function test_include_same_name()
{
  local test1_output
  local test2_output
  local test1_expected
  local test2_expected

  include "$SHUNIT_TMPDIR/include_test_same_name"
  include "$KW_INC_TEST_PATH/include_test_same_name"

  test1_output=$(test1)
  test2_output=$(test2)
  test1_expected='output of test1'
  test2_expected='output of test2'

  assertEquals "($LINENO)" "$test1_output" "$test1_expected"
  assertEquals "($LINENO)" "$test2_output" "$test2_expected"
}

function test_include_hidden_files()
{
  include "$KW_INC_TEST_HIDDEN_PATH/include_hidden.sh"
  assertEquals "($LINENO)" 0 "$?"
}

function test_include_spaced_path()
{
  include "$KW_INC_TEST_SPACED_PATH/include_spaced.sh"
  assertEquals "($LINENO)" 0 "$?"
}

function test_include_dashed_path()
{
  include "$KW_INC_TEST_PATH/include-dashed.sh"
  assertEquals "($LINENO)" 0 "$?"
}

function test_include_similar_hidden_path()
{
  local test3_output
  local test4_output
  local test3_expected
  local test4_expected

  include "$KW_INC_TEST_PATH/include_test_similar_path.sh"
  include "$KW_INC_TEST_HIDDEN_PATH/include_test_similar_path.sh"

  test3_output=$(test3)
  test4_output=$(test4)
  test3_expected='output of test3'
  test4_expected='output of test4'

  assertEquals "($LINENO)" "$test3_output" "$test3_expected"
  assertEquals "($LINENO)" "$test4_output" "$test4_expected"
}

invoke_shunit
