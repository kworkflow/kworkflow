#!/bin/bash

include './src/ui/patch_hub/series_details.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  export LORE_DATA_DIR="${SHUNIT_TMPDIR}/lore"
  export BOOKMARKED_SERIES_PATH="${LORE_DATA_DIR}/lore_bookmarked_series"
}

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

function test_show_patchset_details_and_actions()
{
  local raw_patchset='Juca PiramaÆjucapirama@xpto.comÆV1Æ255ÆDC Patches November 19, 2022Æhttp://anotherthing.la'
  local output
  local expected_result='Patchset details and actions'

  expected_result+=' \Zb\Z6Series:\ZnDC Patches November 19, 2022\n'
  expected_result+='\Zb\Z6Author:\ZnJuca Pirama\n\Zb\Z6Version:\ZnV1\n'
  expected_result+='\Zb\Z6Patches:\Zn255\n'
  expected_result+=' Download Bookmark'

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

  output=$(show_patchset_details_and_actions "$raw_patchset")
  assert_equals_helper 'Wrong output' "$LINENO" "$expected_result" "$output"
}

function test_get_actions_to_take()
{
  local -a actions_starting_status=()
  local selected_actions
  local output
  local expected

  actions_starting_status[0]=0
  actions_starting_status[1]=0
  selected_actions=''
  output=$(get_actions_to_take 'actions_starting_status' "$selected_actions")
  expected=''
  assert_equals_helper 'Should output no action to take' "$LINENO" "$expected" "$output"

  actions_starting_status[0]=0
  actions_starting_status[1]=0
  selected_actions='Download'
  output=$(get_actions_to_take 'actions_starting_status' "$selected_actions")
  expected='download '
  assert_equals_helper 'Should output the download action' "$LINENO" "$expected" "$output"

  actions_starting_status[0]=0
  actions_starting_status[1]=0
  selected_actions='Bookmark'
  output=$(get_actions_to_take 'actions_starting_status' "$selected_actions")
  expected='bookmark '
  assert_equals_helper 'Should output the bookmark action' "$LINENO" "$expected" "$output"

  actions_starting_status[0]=0
  actions_starting_status[1]=0
  selected_actions='Download Bookmark'
  output=$(get_actions_to_take 'actions_starting_status' "$selected_actions")
  expected='download bookmark '
  assert_equals_helper 'Should output the download and bookmark action' "$LINENO" "$expected" "$output"

  actions_starting_status[0]=1
  actions_starting_status[1]=1
  selected_actions='Download Bookmark'
  output=$(get_actions_to_take 'actions_starting_status' "$selected_actions")
  expected=''
  assert_equals_helper 'Should output no action to take' "$LINENO" "$expected" "$output"

  actions_starting_status[0]=1
  actions_starting_status[1]=1
  selected_actions='Bookmark'
  output=$(get_actions_to_take 'actions_starting_status' "$selected_actions")
  expected='remove-download '
  assert_equals_helper 'Should output the remove-download action' "$LINENO" "$expected" "$output"

  actions_starting_status[0]=1
  actions_starting_status[1]=1
  selected_actions='Download'
  output=$(get_actions_to_take 'actions_starting_status' "$selected_actions")
  expected='remove-bookmark '
  assert_equals_helper 'Should output the remove-bookmark action' "$LINENO" "$expected" "$output"

  actions_starting_status[0]=1
  actions_starting_status[1]=1
  selected_actions=''
  output=$(get_actions_to_take 'actions_starting_status' "$selected_actions")
  expected='remove-download remove-bookmark '
  assert_equals_helper 'Should output the remove-download and remove-bookmark action' "$LINENO" "$expected" "$output"
}

invoke_shunit
