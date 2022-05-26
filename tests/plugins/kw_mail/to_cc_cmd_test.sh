#!/bin/bash

include './tests/utils.sh'

function oneTimeSetUp()
{
  declare -gr ORIGINAL_DIR="$PWD"
  declare -gr FAKE_CACHE="${SHUNIT_TMPDIR}/cache"
  declare -gr PATCH_CACHE="${FAKE_CACHE}/patches"

  declare -gr TO_LIST=$'to@one.com\nto@two.com\nto@three.com'

  declare -gr CC_LIST=$'cc@one.com\ncc@two.com'

  mkdir -p "${PATCH_CACHE}/to/" "${PATCH_CACHE}/cc/"

  printf '%s\n' "$TO_LIST" > "${PATCH_CACHE}/to/to_list"
  printf '%s\n' "$CC_LIST" > "${PATCH_CACHE}/cc/cc_list"

  printf '%s\n' "$TO_LIST" > "${PATCH_CACHE}/to/cover-letter"
  printf '%s\n' "$CC_LIST" >> "${PATCH_CACHE}/to/cover-letter"
}

function oneTimeTearDown()
{
  rm -rf "$FAKE_CACHE"
}

function test_to_cc_main()
{
  local to_cc_cmd="${ORIGINAL_DIR}/src/plugins/kw_mail/to_cc_cmd.sh"
  local expected
  local output
  local ret

  bash "$to_cc_cmd" "$FAKE_CACHE" 'to' ''
  ret="$?"
  assert_equals_helper 'Empty patch path should return an error' "$LINENO" "$ret" 22

  bash "$to_cc_cmd" "$FAKE_CACHE" '' 'to_list'
  ret="$?"
  assert_equals_helper 'Empty to_cc should return an error' "$LINENO" "$ret" 22

  output="$(bash "$to_cc_cmd" "$FAKE_CACHE" to to_list)"
  expected="$TO_LIST"
  multilineAssertEquals "($LINENO) Testing to_cc_cmd to output" "$expected" "$output"

  output="$(bash "$to_cc_cmd" "$FAKE_CACHE" to longer/path/to_list)"
  expected="$TO_LIST"
  multilineAssertEquals "($LINENO) Testing to_cc_cmd to output" "$expected" "$output"

  output="$(bash "$to_cc_cmd" "$FAKE_CACHE" cc cc_list)"
  expected="$CC_LIST"
  multilineAssertEquals "($LINENO) Testing to_cc_cmd cc output" "$expected" "$output"

  output="$(bash "$to_cc_cmd" "$FAKE_CACHE" cc longer/path/cc_list)"
  expected="$CC_LIST"
  multilineAssertEquals "($LINENO) Testing to_cc_cmd cc output" "$expected" "$output"

  output="$(bash "$to_cc_cmd" "$FAKE_CACHE" to cover-letter)"
  expected="$TO_LIST"$'\n'"$CC_LIST"
  multilineAssertEquals "($LINENO) Testing to_cc_cmd cover-letter output" "$expected" "$output"
}

invoke_shunit
