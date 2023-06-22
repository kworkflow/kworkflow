#!/bin/bash

include './src/upstream_patches_ui.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  export ORIGINAL_PATH="$PWD"
}

function setUp()
{
  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO) It was not possible to change to the temporary directory"
    return
  }
}

function tearDown()
{
  cd "${ORIGINAL_PATH}" || {
    fail "($LINENO) It was not possible change to back to the kw folder"
    return
  }
}

function test_parse_upstream_patches_ui_options()
{
  local expected
  local output

  expected="kw upstream-patches-ui: unrecognized option '--illegal-long-option'"
  unset options_values
  declare -A options_values
  parse_upstream_patches_ui_options '--illegal-long-option'
  assert_equals_helper 'Illegal long option should return 22' "$LINENO" 22 "$?"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "${options_values['ERROR']}"

  expected="kw upstream-patches-ui: invalid option -- 'i'"
  unset options_values
  declare -A options_values
  parse_upstream_patches_ui_options '-i'
  assert_equals_helper 'Illegal short option should return 22' "$LINENO" 22 "$?"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "${options_values['ERROR']}"
}

invoke_shunit
