#!/bin/bash

include './tests/utils.sh'

function oneTimeSetUp()
{
  # specifies where to source the lib
  KW_LIB_DIR="$PWD/src"

  # this test file can be empty, as we're only testing the created varname
  test_files=(
    "$SHUNIT_TMPDIR/.hidden spaced-dashed include.sh"
    "$SHUNIT_TMPDIR/include_hash"
  )

  touch "${test_files[@]}"

  # the next files will be checked for name collisions
  printf "%s\n" "function test1(){ printf '%s\n' 'output of test1';}" > \
    "$SHUNIT_TMPDIR/include_test_similar_path.sh"

  mkdir "$SHUNIT_TMPDIR/include_test"

  printf "%s\n" "function test2(){ printf '%s\n' 'output of test2';}" > \
    "$SHUNIT_TMPDIR/include_test/similar_path.sh"
}

function oneTimeTearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
  mkdir -p "$SHUNIT_TMPDIR"
}

function test_include()
{
  local fullpath
  local output
  local relpath

  relpath='./src/lib/kwio.sh'
  include "$relpath"

  fullpath="$(realpath "$relpath")"

  output="${KW_INCLUDED_PATHS["$fullpath"]}"
  assertEquals "($LINENO)" 1 "$output"
}

function test_include_twice()
{
  include ./src/lib/kwlib.sh
  include ./src/lib/kwlib.sh
  assertEquals "($LINENO)" 0 "$?"
}

function test_include_wrong_path()
{
  output=$(include ./src/batata.sh)
  assertEquals "($LINENO)" 2 "$?"
}

function test_include_unusual_path()
{
  include "$SHUNIT_TMPDIR/.hidden spaced-dashed include.sh"
  assertEquals "($LINENO)" 0 "$?"
}

function test_include_similar_paths()
{
  local test1_output
  local test2_output
  local test1_expected
  local test2_expected

  include "$SHUNIT_TMPDIR/include_test_similar_path.sh"
  include "$SHUNIT_TMPDIR/include_test/similar_path.sh"

  test1_output=$(test1)
  test2_output=$(test2)
  test1_expected='output of test1'
  test2_expected='output of test2'

  assertEquals "($LINENO)" "$test1_output" "$test1_expected"
  assertEquals "($LINENO)" "$test2_output" "$test2_expected"
}

invoke_shunit
