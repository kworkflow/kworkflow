#!/bin/bash

include './src/upstream_patches_ui.sh'
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

function test_dashboard_entry_menu_check_valid_options()
{
  # Mock Register list
  # shellcheck disable=SC2317
  function create_menu_options()
  {
    menu_return_string=1
  }

  dashboard_entry_menu
  assert_equals_helper 'Expected register screen' "$LINENO" "${screen_sequence['SHOW_SCREEN']}" 'registered_mailing_list'

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

declare -ga patch_list_with_metadata=(
  'Joe DoeÆjoedoe@lala.comÆV1Æ1Ædrm/amd/pm: Enable bad memory page/channel recording support for smu v13_0_0Æhttp://something.la'
  'Juca PiramaÆjucapirama@xpto.comÆV1Æ255ÆDC Patches November 19, 2022Æhttp://anotherthing.la'
  'Machado de AssisÆmachado@literatura.comÆV2Æ1Ædrm/amdgpu: add drv_vram_usage_va for virt data exchangeÆhttp://machado.good.books.la'
  'Racionais McÆvidaloka@abc.comÆV2Æ1Ædrm/amdgpu: fix pci device refcount leakÆhttp://racionais.mc.vida.loka'
)

function test_show_series_details()
{
  local output
  local expected_result='Patch(es) info and actions'

  expected_result+=' \Zb\Z6Series:\ZnDC Patches November 19, 2022\n'
  expected_result+='\Zb\Z6Author:\ZnJuca Pirama\n\Zb\Z6Version:\ZnV1\n'
  expected_result+='\Zb\Z6Patches:\Zn255\n'
  expected_result+=' action_list'

  # Mock failed scenario
  # shellcheck disable=SC2317
  function create_simple_checklist()
  {
    local title="$1"
    local message_box="$2"
    local action="$3"

    printf '%s %s %s' "$title" "$message_box" "$action"
  }

  output=$(show_series_details 1 patch_list_with_metadata)
  assert_equals_helper 'Expected failure' "$LINENO" $"$output" $"$expected_result"
}

function test_show_bookmarked_series_details()
{
  local output
  local expected_result='Bookmarked Series info and actions'

  expected_result+=' \Zb\Z6Series:\ZnDC Patches November 19, 2022\n'
  expected_result+='\Zb\Z6Author:\ZnJuca Pirama\n\Zb\Z6Version:\ZnV1\n'
  expected_result+='\Zb\Z6Patches:\Zn255\n'
  expected_result+=' action_list'

  # shellcheck disable=SC2317
  function get_bookmarked_series_by_index()
  {
    if [[ "$1" == 2 ]]; then
      printf 'Juca PiramaÆjucapirama@xpto.comÆV1Æ255ÆDC Patches November 19, 2022Æhttp://anotherthing.la'
    fi
  }

  # Mock failed scenario
  # shellcheck disable=SC2317
  function create_simple_checklist()
  {
    local title="$1"
    local message_box="$2"
    local action="$3"

    printf '%s %s %s' "$title" "$message_box" "$action"
  }

  output=$(show_bookmarked_series_details 1)
  assert_equals_helper 'Expected failure' "$LINENO" $"$output" $"$expected_result"
}

function test_list_patches()
{
  # shellcheck disable=SC2317
  function create_menu_options()
  {
    menu_return_string='3'
  }

  list_patches 'Message test' 'patches_from_mailing_list' 'show_new_patches_in_the_mailing_list'
  assert_equals_helper 'Expected screen' "$LINENO" "${screen_sequence['SHOW_SCREEN']}" 'show_series_details'
  assert_equals_helper 'Expected screen' "$LINENO" "${screen_sequence['SHOW_SCREEN_PARAMETER']}" 2

  list_patches 'Message test' 'bookmarked_patches' 'bookmarked_patches'
  assert_equals_helper 'Expected screen' "$LINENO" "${screen_sequence['SHOW_SCREEN']}" 'show_bookmarked_series_details'
  assert_equals_helper 'Expected screen' "$LINENO" "${screen_sequence['SHOW_SCREEN_PARAMETER']}" 2
}

invoke_shunit
