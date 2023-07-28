#!/bin/bash

include './src/ui/patch_hub/settings.sh'
include './tests/utils.sh'

function setUp()
{
  screen_sequence['SHOW_SCREEN']=''

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

function test_show_settings_screen()
{
  declare -A screen_sequence=(['SHOW_SCREEN']='')

  # shellcheck disable=SC2317
  function create_menu_options()
  {
    # 'Settings' sub-menu chosen
    menu_return_string=1
  }

  show_settings_screen
  assert_equals_helper 'Should set next screen to "lore_mailing_lists"' "$LINENO" 'lore_mailing_lists' "${screen_sequence['SHOW_SCREEN']}"
}

invoke_shunit
