#!/usr/bin/env bash

include './src/ui/patch_hub/lore_mailing_lists.sh'
include './tests/unit/utils.sh'

function setUp()
{
  export ORIGINAL_PATH="$PWD"

  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO): setUp(): It was not possible to move into ${SHUNIT_TMPDIR}"
    return
  }
}

function tearDown()
{
  cd "${ORIGINAL_PATH}" || {
    fail "($LINENO): tearDown(): It was not possible to move into ${ORIGINAL_PATH}"
    return
  }
}

function test_convert_available_lore_mailing_lists_to_array()
{
  declare -A available_lore_mailing_lists=(
    ['A']='Description E'
    ['B']='Description A'
    ['C']='Description C'
    ['D']='Description D'
    ['E']='Description B'
  )
  local -a available_lore_mailing_lists_array
  local -a expected_array=('A' 'B' 'C' 'D' 'E')
  local test_fail_message

  convert_available_lore_mailing_lists_to_array 'available_lore_mailing_lists' 'available_lore_mailing_lists_array'
  test_fail_message='Arrays are different:'$'\n'"${expected_array[*]}"$'\n'"${available_lore_mailing_lists_array[*]}"
  [[ "${expected_array[*]}" == "${available_lore_mailing_lists_array[*]}" ]]
  assert_equals_helper "$test_fail_message" "$LINENO" 0 "$?"
}

function test_get_lists_check_status()
{
  local -a lists=('List1' 'List2' 'List3' 'List4' 'List5')
  local -a lists_check_status
  local registered_lists_string='List2,List5'
  local -a expected_array=(0 1 0 0 1)
  local test_fail_message

  get_lists_check_status 'lists' 'lists_check_status' "$registered_lists_string"
  test_fail_message='Arrays are different:'$'\n'"${expected_array[*]}"$'\n'"${lists_check_status[*]}"
  [[ "${expected_array[*]}" == "${lists_check_status[*]}" ]]
  assert_equals_helper "$test_fail_message" "$LINENO" 0 "$?"
}

invoke_shunit
