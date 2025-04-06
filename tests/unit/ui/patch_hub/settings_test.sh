#!/usr/bin/env bash

include './src/ui/patch_hub/settings.sh'
include './tests/unit/utils.sh'

function setUp() {
  screen_sequence['SHOW_SCREEN']=''

  export ORIGINAL_PATH="$PWD"
  export lore_config_path="${SHUNIT_TMPDIR}/lore.config"

  touch "$lore_config_path"

  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO): setUp(): It was not possible to move into ${SHUNIT_TMPDIR}"
    return
  }
}

function tearDown() {
  rm "$lore_config_path"

  cd "${ORIGINAL_PATH}" || {
    fail "($LINENO): tearDown(): It was not possible to move into ${ORIGINAL_PATH}"
    return
  }
}

function test_show_settings_screen() {
  declare -A screen_sequence=(['SHOW_SCREEN']='')

  # shellcheck disable=SC2317
  function create_menu_options() {
    # 'Settings' sub-menu chosen
    menu_return_string=0
  }

  show_settings_screen
  assert_equals_helper 'Should set next screen to "lore_mailing_lists"' "$LINENO" 'lore_mailing_lists' "${screen_sequence['SHOW_SCREEN']}"
}

function test_change_patchsets_per_page_setting() {
  local output
  local expected

  # shellcheck disable=SC2317
  function create_choice_list_screen() {
    # 'Settings' sub-menu chosen
    menu_return_string=60
    return 0
  }

  printf 'patchsets_per_page=30' > "$lore_config_path"

  change_patchsets_per_page_setting "$lore_config_path"
  output=$(< "$lore_config_path")
  expected='patchsets_per_page=60'
  assert_equals_helper 'Wrong value in config file' "$LINENO" "$expected" "$output"
}

function test_change_lore_requests_timeframe_setting() {
  local output
  local expected

  # shellcheck disable=SC2317
  function create_choice_list_screen() {
    # 'Settings' sub-menu chosen
    menu_return_string=180
    return 0
  }

  printf 'lore_requests_timeframe=180' > "$lore_config_path"

  change_lore_requests_timeframe_setting "$lore_config_path"
  output=$(< "$lore_config_path")
  expected='lore_requests_timeframe=180'
  assert_equals_helper 'Wrong value in config file' "$LINENO" "$expected" "$output"
}

invoke_shunit
