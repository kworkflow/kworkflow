#!/bin/bash

include './src/ui/patch_hub/series_details.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  export LORE_DATA_DIR="${SHUNIT_TMPDIR}/lore"
  export BOOKMARKED_SERIES_PATH="${LORE_DATA_DIR}/lore_bookmarked_series"
  # shellcheck disable=SC2155
  export sample_mbx_file_path=$(realpath './tests/samples/ui/patch-hub/20230622_rodrigo_siqueira_dc_patches_june_22_2023.mbx')

  cp "$sample_mbx_file_path" "$SHUNIT_TMPDIR"
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

# This unit test works on a local machine, but fails in the remote CI/CD pipeline.
# This behaviour may be explained by the fact that this unit test really downloads
# the patchset using b4 and the network environment of the remote may be blocking
# it, causing the download to fail and this unit test too.
test_handle_download_action()
{
  :
  # declare -A patchset
  # declare -A lore_config
  # local mbx_file_path

  # # shellcheck disable=SC2317
  # function create_loading_screen_notification()
  # {
  #   return
  # }

  # patchset['patchset_url']='https://lore.kernel.org/amd-gfx/20230622215735.2026220-1-Rodrigo.Siqueira@amd.com/'
  # lore_config['save_patches_to']="$SHUNIT_TMPDIR"
  # mbx_file_path="${lore_config['save_patches_to']}/20230622215735.2026220-1-Rodrigo.Siqueira@amd.com.mbx"

  # handle_download_action 'patchset' > /dev/null 2>&1
  # [[ -f "$mbx_file_path" ]]
  # assert_equals_helper 'Should have downloaded the .mbx file' "$LINENO" 0 "$?"

  # cmp --silent "$sample_mbx_file_path" "$mbx_file_path"
  # assert_equals_helper 'File downloaded diverges from sample' "$LINENO" 0 "$?"
}

test_handle_remove_download_action()
{
  declare -A patchset
  declare -A lore_config
  local mbx_file_path

  patchset['patchset_url']='https://lore.kernel.org/amd-gfx/20230622215735.2026220-1-Rodrigo.Siqueira@amd.com/'
  lore_config['save_patches_to']="$SHUNIT_TMPDIR"
  mbx_file_path="${lore_config['save_patches_to']}/20230622215735.2026220-1-Rodrigo.Siqueira@amd.com.mbx"

  touch "$mbx_file_path"
  handle_remove_download_action 'patchset'
  [[ ! -f "$mbx_file_path" ]]
  assert_equals_helper 'Should have removed the .mbx file' "$LINENO" 0 "$?"
}

test_handle_bookmark_action()
{
  declare -A patchset
  local output

  # shellcheck disable=SC2317
  function create_loading_screen_notification()
  {
    return
  }

  # We need to mock download_series or else the test
  # fails in the remote CI/CD pipeline.
  # shellcheck disable=SC2317
  function download_series()
  {
    return 0
  }

  handle_bookmark_action 'patchset' 'this_is_a_raw_patchset'
  output=$(< "$BOOKMARKED_SERIES_PATH")
  [[ "$output" =~ 'this_is_a_raw_patchset' ]]
  assert_equals_helper 'Should have added patchset entry to database' "$LINENO" 0 "$?"
}

test_handle_remove_bookmark_action()
{
  declare -A patchset
  declare -A lore_config
  local mbx_file_path
  local output

  patchset['patchset_url']='https://lore.kernel.org/amd-gfx/20230622215735.2026220-1-Rodrigo.Siqueira@amd.com/'
  lore_config['save_patches_to']="$SHUNIT_TMPDIR"
  mbx_file_path="${lore_config['save_patches_to']}/20230622215735.2026220-1-Rodrigo.Siqueira@amd.com.mbx"
  touch "$mbx_file_path"
  printf 'https://lore.kernel.org/list/message-ID/' >> "$BOOKMARKED_SERIES_PATH"

  handle_remove_bookmark_action 'patchset'
  [[ ! -f "$mbx_file_path" ]]
  assert_equals_helper 'Should have removed the .mbx file' "$LINENO" 0 "$?"
  output=$(< "$BOOKMARKED_SERIES_PATH")
  # shellcheck disable=SC2076
  [[ ! "$output" =~ "${patchset['patchset_url']}" ]]
  assert_equals_helper 'Should have removed patchset entry from database' "$LINENO" 0 "$?"
}

invoke_shunit
