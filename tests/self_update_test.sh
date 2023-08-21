#!/bin/bash

include './src/self_update.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  export TEST_PATH="${SHUNIT_TMPDIR}/test_path"
  export original_dir="$PWD"
  export fake_dir_path="${SHUNIT_TMPDIR}/fake_dir"
}

function setUp()
{
  mkdir -p "${fake_dir_path}" || {
    fail "($LINENO) It was not possible to create the fake directory"
    return
  }

  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
}

function tearDown()
{
  rm -rf "${fake_dir_path}" || {
    fail "($LINENO) It was not possible to remove the fake directory"
    return
  }

  cd "${original_dir}" || {
    fail "($LINENO) It was not possible to back to the kw folder"
    return
  }
}

function test_update_from_official_repo_based_on_master()
{
  update_from_official_repo 'master' "${fake_dir_path}" 'TEST_MODE' > /dev/null 2>&1
  assertEquals "($LINENO) It should be able to update based on the master." 0 "$?"
}

function test_update_from_official_repo_based_on_unstable()
{
  update_from_official_repo 'unstable' "${fake_dir_path}" 'TEST_MODE' > /dev/null 2>&1
  assertEquals "($LINENO) It should be able to update based on the unstable." 0 "$?"
}

function test_update_from_official_repo_root_as_tmp_dir()
{
  update_from_official_repo 'unstable' '/' 'TEST_MODE' > /dev/null 2>&1
  assertEquals "($LINENO) It should be abort the update." 1 "$?"
}

function test_parse_self_update_options()
{
  local expected_output=''
  local output=''

  unset options_values
  declare -gA options_values
  parse_self_update_options '--unstable'
  assertEquals "($LINENO) UNSTABLE could not be set" 1 "${options_values['UNSTABLE']}"

  unset options_values
  declare -gA options_values
  parse_self_update_options '--verbose'
  assertEquals "($LINENO) VERBOSE could not be set" 1 "${options_values['VERBOSE']}"

  unset options_values
  declare -gA options_values
  parse_self_update_options '-u'
  assertEquals "($LINENO) UNSTABLE could not be set" 1 "${options_values['UNSTABLE']}"

  expected_output='kw self-update:'$'\n'
  expected_output+='  kw self-update - Update kw based on the master branch'$'\n'
  expected_output+='  kw self-update (-u | --unstable) - Update kw based on the unstable branch'$'\n'
  expected_output+='  kw self-update --help - Show the man page for kw self-update'
  output=$(parse_self_update_options '-h')
  assertEquals "($LINENO) Should show help" "${expected_output}" "$output"
}

invoke_shunit
