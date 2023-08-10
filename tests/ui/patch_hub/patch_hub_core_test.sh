#!/bin/bash

include './src/ui/patch_hub/patch_hub_core.sh'
include './tests/utils.sh'

function setUp()
{
  screen_sequence['SHOW_SCREEN']=''

  export ORIGINAL_PATH="$PWD"
  export BOOKMARKED_SERIES_PATH="${SHUNIT_TMPDIR}/lore_bookmarked_series"

  touch "$BOOKMARKED_SERIES_PATH"

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

function test_dashboard_entry_menu_check_valid_options()
{
  # Mock Register list
  # shellcheck disable=SC2317
  function create_menu_options()
  {
    menu_return_string=1
  }

  dashboard_entry_menu
  assert_equals_helper 'Expected register screen' "$LINENO" "${screen_sequence['SHOW_SCREEN']}" 'registered_mailing_lists'

  # Mock bookmarked
  # shellcheck disable=SC2317
  function create_menu_options()
  {
    menu_return_string=2
  }

  dashboard_entry_menu
  assert_equals_helper 'Expected register screen' "$LINENO" "${screen_sequence['SHOW_SCREEN']}" 'bookmarked_patches'
}

function test_dashboard_entry_menu_check_failed()
{
  local output

  # Mock failed scenario
  # shellcheck disable=SC2317
  function create_menu_options()
  {
    return 22
  }

  output=$(dashboard_entry_menu)
  assert_equals_helper 'Expected failure' "$LINENO" "$?" 22
}

function test_list_patches_with_patches()
{
  local -a patchsets_metadata_array
  declare -ag list_of_mailinglist_patches

  # shellcheck disable=SC2317
  function create_menu_options()
  {
    menu_return_string='3'
  }

  patchsets_metadata_array=(
    'some_patch_metadata'
    'some_other_patch_metadata'
    'more_patches_metadata'
  )

  list_of_mailinglist_patches=(
    'some_patch_raw_data'
    'some_other_patch_raw_data'
    'more_patches_raw_data'
  )

  screen_sequence['SHOW_SCREEN']='latest_patchsets_from_mailing_list'
  list_patches 'Message test' list_of_mailinglist_patches ''
  assert_equals_helper 'Wrong screen set' "$LINENO" 'patchset_details_and_actions' "${screen_sequence['SHOW_SCREEN']}"
  assert_equals_helper 'Wrong screen parameter' "$LINENO" 'more_patches_raw_data' "${screen_sequence['SHOW_SCREEN_PARAMETER']}"

  printf 'some_patch_raw_data\nsome_other_patch_raw_data\nmore_patches_raw_data' > "$BOOKMARKED_SERIES_PATH"

  screen_sequence['SHOW_SCREEN']='bookmarked_patches'
  list_patches 'Message test' patchsets_metadata_array ''
  assert_equals_helper 'Wrong screen set' "$LINENO" 'patchset_details_and_actions' "${screen_sequence['SHOW_SCREEN']}"
  assert_equals_helper 'Wrong screen parameter' "$LINENO" 'more_patches_raw_data' "${screen_sequence['SHOW_SCREEN_PARAMETER']}"
}

function test_list_patches_without_patches()
{
  local -a target_array_list

  # shellcheck disable=SC2317
  function create_message_box()
  {
    return
  }

  target_array_list=()

  list_patches 'Message test' target_array_list 'show_new_patches_in_the_mailing_list' ''
  assert_equals_helper 'Expected screen' "$LINENO" "${screen_sequence['SHOW_SCREEN']}" 'dashboard'

  list_patches 'Message test' target_array_list 'bookmarked_patches' ''
  assert_equals_helper 'Expected screen' "$LINENO" "${screen_sequence['SHOW_SCREEN']}" 'dashboard'
}

invoke_shunit
