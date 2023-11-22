#!/bin/bash

include './src/ui/patch_hub/search_string_in_lore.sh'
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

function test_show_search_string_in_lore()
{
  local output
  local expected

  # shellcheck disable=SC2317
  function create_inputbox_screen()
  {
    menu_return_string=''
    return 0
  }

  # shellcheck disable=SC2317
  function create_message_box()
  {
    printf '%s %s' "$1" "$2"
    return 0
  }

  output=$(show_search_string_in_lore)
  expected='Error Inputted string should not be empty.'
  assert_equals_helper 'An empty string should output an error message' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Wrong screen set' "$LINENO" '' "${screen_sequence['SHOW_SCREEN']}"
  assert_equals_helper 'Wrong screen parameter' "$LINENO" '' "${screen_sequence['SHOW_SCREEN_PARAMETER']}"

  # shellcheck disable=SC2317
  function create_inputbox_screen()
  {
    menu_return_string='query-string'
    return 0
  }

  show_search_string_in_lore
  assert_equals_helper 'Wrong screen set' "$LINENO" 'latest_patchsets_from_mailing_list' "${screen_sequence['SHOW_SCREEN']}"
  assert_equals_helper 'Wrong screen parameter' "$LINENO" 'query-string' "${screen_sequence['SHOW_SCREEN_PARAMETER']}"
  assert_equals_helper 'Wrong current list' "$LINENO" 'all' "$current_mailing_list"

  # shellcheck disable=SC2317
  function create_inputbox_screen()
  {
    return 3
  }

  screen_sequence['SHOW_SCREEN_PARAMETER']='query-string'
  show_search_string_in_lore
  assert_equals_helper 'Wrong screen set' "$LINENO" 'dashboard' "${screen_sequence['SHOW_SCREEN']}"
  assert_equals_helper 'Wrong screen parameter' "$LINENO" '' "${screen_sequence['SHOW_SCREEN_PARAMETER']}"
  assert_equals_helper 'Wrong current list' "$LINENO" 'all' "$current_mailing_list"
}

function test_search_string_in_lore()
{
  local output
  local expected

  # shellcheck disable=SC2317
  function create_message_box()
  {
    printf '%s %s' "$1" "$2"
    return 0
  }

  output=$(search_string_in_lore '')
  expected='Error Inputted string should not be empty.'
  assert_equals_helper 'An empty string should output an error message' "$LINENO" "$expected" "$output"

  search_string_in_lore 'query-string'
  assert_equals_helper 'Wrong screen set' "$LINENO" 'latest_patchsets_from_mailing_list' "${screen_sequence['SHOW_SCREEN']}"
  assert_equals_helper 'Wrong screen parameter' "$LINENO" 'query-string' "${screen_sequence['SHOW_SCREEN_PARAMETER']}"
  assert_equals_helper 'Wrong current list' "$LINENO" 'all' "$current_mailing_list"

  search_string_in_lore 'Robson Cruzoé'
  assert_equals_helper 'Wrong screen set' "$LINENO" 'latest_patchsets_from_mailing_list' "${screen_sequence['SHOW_SCREEN']}"
  assert_equals_helper 'Wrong screen parameter' "$LINENO" 'Robson%20Cruzo%C3%A9' "${screen_sequence['SHOW_SCREEN_PARAMETER']}"
  assert_equals_helper 'Wrong current list' "$LINENO" 'all' "$current_mailing_list"
}

invoke_shunit
