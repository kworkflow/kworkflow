include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

# This function is responsible for showing the screen with a patchset details
# and actions available.
#
# @raw_patchset: Raw data of patchset to be displayed
function show_patchset_details_and_actions()
{
  local raw_patchset="$1"
  declare -A patchset
  local -a actions_list=('Download' 'Bookmark')
  local -a actions_starting_status=()
  local actions_to_take
  local patch_metadata
  local message_box

  parse_raw_patchset_data "${raw_patchset}" 'patchset'
  patch_metadata=$(prettify_string 'Series:' "${patchset['patchset_title']}")
  patch_metadata+=$(prettify_string 'Author:' "${patchset['patchset_author']}")
  patch_metadata+=$(prettify_string 'Version:' "${patchset['patchset_version']}")
  patch_metadata+=$(prettify_string 'Patches:' "${patchset['total_patches']}")
  message_box="$patch_metadata"

  actions_starting_status[0]=$(get_patchset_download_status "${patchset['patchset_url']}" "${lore_config['save_patches_to']}")
  actions_starting_status[1]=$(get_patchset_bookmark_status "${patchset['patchset_url']}")

  create_simple_checklist 'Patchset details and actions' "$message_box" 'actions_list' 'actions_starting_status' 1
  ret="$?"

  case "$ret" in
    0) # OK
      actions_to_take=$(get_actions_to_take 'actions_starting_status' "$menu_return_string")
      IFS=' ' read -r -a actions <<< "$actions_to_take"
      for action in "${actions[@]}"; do
        case "$action" in
          'download')
            handle_download_action 'patchset'
            ;;
          'remove-download')
            handle_remove_download_action 'patchset'
            ;;
          'bookmark')
            handle_bookmark_action 'patchset' "$raw_patchset"
            ;;
          'remove-bookmark')
            handle_remove_bookmark_action 'patchset'
            ;;
        esac
      done
      ;;

    1) # Exit
      handle_exit "$ret"
      ;;

    3) # Return
      screen_sequence['SHOW_SCREEN']="${screen_sequence['PREVIOUS_SCREEN']}"
      screen_sequence['RETURNING']=1
      ;;
  esac
}

# This function returns a string containing patchset actions to take based on
# the transitions of the action statuses. In other words, this function uses
# the array reference `@_actions_starting_status` that stores the starting
# statuses of actions and the string `@selected_actions` that stores the ending
# statuses of actions.
#
# @_actions_starting_status: Array reference that stores the starting statuses
#   of actions.
# @selected_actions: String containing actions with a set status
function get_actions_to_take()
{
  local -n _actions_starting_status="$1"
  local selected_actions="$2"
  local actions_to_take

  # download
  if [[ "${_actions_starting_status[0]}" == 0 && "$selected_actions" =~ 'Download' ]]; then
    actions_to_take+='download '
  fi

  # remove-download
  if [[ "${_actions_starting_status[0]}" == 1 && ! "$selected_actions" =~ 'Download' ]]; then
    actions_to_take+='remove-download '
  fi

  # bookmark
  if [[ "${_actions_starting_status[1]}" == 0 && "$selected_actions" =~ 'Bookmark' ]]; then
    actions_to_take+='bookmark '
  fi

  # remove-bookmark
  if [[ "${_actions_starting_status[1]}" == 1 && ! "$selected_actions" =~ 'Bookmark' ]]; then
    actions_to_take+='remove-bookmark '
  fi

  printf '%s' "$actions_to_take"
}

# TODO: Document and test this function
function handle_bookmark_action()
{
  local -n _series="$1"
  local raw_series="$2"
  local output

  create_loading_screen_notification 'Bookmarking patchset'$'\n'"- ${_series['patchset_title']}"

  output=$(download_series "${_series['patchset_url']}" "${lore_config['save_patches_to']}")
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not download patchset:'$'\n'"- ${_series['patchset_title']}"$'\n'"[error message] ${output}"
  fi

  add_patchset_to_bookmarked_database "${raw_series}" "${lore_config['save_patches_to']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not bookmark patchset'$'\n'"- ${_series['patchset_title']}"
  fi
}

# TODO: Document and test this function
function handle_download_action()
{
  local -n _series="$1"
  local output

  create_loading_screen_notification 'Downloading patchset'$'\n'"- ${_series['patchset_title']}"

  output=$(download_series "${_series['patchset_url']}" "${lore_config['save_patches_to']}")
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not download patchset:'$'\n'"- ${_series['patchset_title']}"$'\n'"[error message] ${output}"
  fi
}

# TODO: Document and test this function
function handle_remove_download_action()
{
  local -n _patchset="$1"

  delete_series_from_local_storage "${lore_config['save_patches_to']}" "${_patchset['patchset_url']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not delete patchset'$'\n'"- ${_patchset['patchset_title']}"
  fi
}

# TODO: Document and test this function
function handle_remove_bookmark_action()
{
  local -n _patchset="$1"

  delete_series_from_local_storage "${lore_config['save_patches_to']}" "${_patchset['patchset_url']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not delete patchset'$'\n'"- ${_patchset['patchset_title']}"
  fi

  remove_patchset_from_bookmark_by_url "${_patchset['patchset_url']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not unbookmark patchset'$'\n'"- ${_patchset['patchset_title']}"
  fi
}
