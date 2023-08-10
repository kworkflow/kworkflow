#!/bin/bash

include './src/ui/patch_hub/latest_patchsets_from_mailing_list.sh'
include './tests/utils.sh'

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

function test_show_new_patches_in_the_mailing_list_title()
{
  declare current_mailing_list=''

  # shellcheck disable=SC2317
  function create_loading_screen_notification()
  {
    return
  }
  # shellcheck disable=SC2317
  function get_patches_from_mailing_list()
  {
    return
  }
  # shellcheck disable=SC2317
  function list_patches()
  {
    return
  }

  # Not returning from a (supposed) series detail screen should set "$current_mailing_list" global variable to "$1"
  screen_sequence['RETURNING']=''
  show_new_patches_in_the_mailing_list 'amd-gfx'
  assert_equals_helper 'Wrong "current_mailing_list" value' "$LINENO" 'amd-gfx' "$current_mailing_list"

  # Returning from a (supposed) series detail screen should use the old "$current_mailing_list" value
  screen_sequence['RETURNING']=1
  show_new_patches_in_the_mailing_list 'arbitrary-value'
  assert_equals_helper 'Wrong "current_mailing_list" value' "$LINENO" 'amd-gfx' "$current_mailing_list"
}

invoke_shunit
