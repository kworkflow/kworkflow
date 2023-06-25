#!/bin/bash

include './src/ui/patch_hub/series_details.sh'
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

function test_show_series_details_of_not_bookmarked_patchset()
{
  local output
  local expected_result='Patchset info and actions'

  declare -ga patch_list_with_metadata=(
    'Joe DoeÆjoedoe@lala.comÆV1Æ1Ædrm/amd/pm: Enable bad memory page/channel recording support for smu v13_0_0Æhttp://something.la'
    'Juca PiramaÆjucapirama@xpto.comÆV1Æ255ÆDC Patches November 19, 2022Æhttp://anotherthing.la'
    'Machado de AssisÆmachado@literatura.comÆV2Æ1Ædrm/amdgpu: add drv_vram_usage_va for virt data exchangeÆhttp://machado.good.books.la'
    'Racionais McÆvidaloka@abc.comÆV2Æ1Ædrm/amdgpu: fix pci device refcount leakÆhttp://racionais.mc.vida.loka'
  )

  expected_result+=' \Zb\Z6Series:\ZnDC Patches November 19, 2022\n'
  expected_result+='\Zb\Z6Author:\ZnJuca Pirama\n\Zb\Z6Version:\ZnV1\n'
  expected_result+='\Zb\Z6Patches:\Zn255\n'
  expected_result+=' Bookmark Download'

  # shellcheck disable=SC2317
  function create_simple_checklist()
  {
    local title="$1"
    local message_box="$2"
    local -n _action_list="$3"

    printf '%s %s' "$title" "$message_box"

    for action in "${_action_list[@]}"; do
      printf ' %s' "$action"
    done
  }

  output=$(show_series_details "${patch_list_with_metadata[1]}")
  assert_equals_helper 'Wrong output' "$LINENO" "$expected_result" "$output"
}

function test_show_series_details_of_bookmarked_patchset()
{
  local raw_patchset='Juca PiramaÆjucapirama@xpto.comÆV1Æ255ÆDC Patches November 19, 2022Æhttp://anotherthing.la'
  local output
  local expected_result='Patchset info and actions'

  expected_result+=' \Zb\Z6Series:\ZnDC Patches November 19, 2022\n'
  expected_result+='\Zb\Z6Author:\ZnJuca Pirama\n\Zb\Z6Version:\ZnV1\n'
  expected_result+='\Zb\Z6Patches:\Zn255\n'
  expected_result+=' Unbookmark'

  # shellcheck disable=SC2317
  function create_simple_checklist()
  {
    local title="$1"
    local message_box="$2"
    local -n _action_list="$3"

    printf '%s %s' "$title" "$message_box"

    for action in "${_action_list[@]}"; do
      printf ' %s' "$action"
    done
  }

  output=$(show_series_details "$raw_patchset" 1)
  assert_equals_helper 'Wrong output' "$LINENO" "$expected_result" "$output"
}

invoke_shunit
