include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

# This function is responsible for showing the screen with a patchset details
# and actions available.
#
# @raw_patchset: Raw data of patchset to be displayed
function show_patchset_details_and_actions()
{
  local raw_patchset="$1"
  declare -A patchset
  local -a actions_list=('Download to specific directory' 'Bookmark')
  local -a actions_starting_status=()
  local actions_to_take
  local patch_metadata
  local message_box

  read_patch_into_dict "$raw_patchset" 'patchset'
  patch_metadata=$(prettify_string 'Series:' "${patchset['message_title']}")
  patch_metadata+=$(prettify_string 'Author:' "${patchset['author_name']}")
  patch_metadata+=$(prettify_string 'Version:' "${patchset['version']}")
  patch_metadata+=$(prettify_string 'Patches:' "${patchset['total_in_series']}")
  message_box="$patch_metadata"

  actions_starting_status[1]=$(get_patchset_bookmark_status "${patchset['message_id']}")

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
  if [[ "$selected_actions" =~ 'Download' ]]; then
    actions_to_take+='download '
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

# Handler of the 'download' action. To download a patchset is to download its
# single .mbx file hosted in lore.kernel.org containing all the patches in the
# patchset without the cover letter to a user-chosen directory.
#
# @_patchset: Associative array reference with metadata of patchset
function handle_download_action()
{
  local -n _patchset="$1"
  local download_dir_path
  local output
  local message_box
  local loading_pid
  local ret

  create_directory_selection_screen "${lore_config['save_patches_to']}" 'Select directory to download .mbx file'

  case "$?" in
    0) # OK
      download_dir_path=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
      if [[ ! -d "$download_dir_path" ]]; then
        create_message_box 'Error' "${download_dir_path}: No such directory."
        return
      fi

      create_async_loading_screen_notification 'Downloading patchset'$'\n'"${_patchset['message_title']}" &
      loading_pid="$!"

      output=$(download_series "${_patchset['message_id']}" "$download_dir_path")
      ret="$?"
      stop_async_loading_screen_notification "$loading_pid"
      if [[ "$ret" != 0 ]]; then
        create_message_box 'Error' 'Could not download patchset:'$'\n'"${_patchset['message_title']}"$'\n'"[error message] ${output}"
      else
        message_box='Downloaded patchset:'$'\n'"- ${_patchset['message_title']}"$'\n'$'\n'
        message_box+='Filepath:'$'\n'"$output"
        create_message_box 'Success' "$message_box"
      fi
      ;;

    1) # Cancel
      ;;

    2) # Help
      create_help_screen 'directory_selection'
      if [[ "$?" != 0 ]]; then
        create_message_box 'Error' 'Cannot create help screen'
      fi
      ;;
  esac
}

# Handler of the 'bookmark' action. To bookmark a patchset is to add it to the
# local bookmarked database managed by kw.
#
# @_patchset: Associative array reference with metadata of patchset
# @raw_patchset: String with raw data of patchset
function handle_bookmark_action()
{
  local -n _patchset="$1"
  local raw_patchset="$2"
  local message_box
  local output
  local loading_pid
  local ret

  output=$(download_series "${_patchset['message_id']}" "${lore_config['save_patches_to']}")
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not download patchset:'$'\n'"- ${_patchset['message_title']}"$'\n'"[error message] ${output}"
    return
  fi

  create_async_loading_screen_notification 'Bookmarking patchset'$'\n'"- ${_patchset['message_title']}" &
  loading_pid="$!"

  add_patchset_to_bookmarked_database "${raw_patchset}" "${lore_config['save_patches_to']}"
  ret="$?"
  stop_async_loading_screen_notification "$loading_pid"
  if [[ "$ret" != 0 ]]; then
    create_message_box 'Error' 'Could not bookmark patchset'$'\n'"- ${_patchset['message_title']}"
    return
  fi

  message_box='Bookmarked patchset:'$'\n'"- ${_patchset['message_title']}"$'\n'$'\n'
  message_box+='Downloaded mbox file to:'$'\n'"$output"
  create_message_box 'Success' "$message_box"
}

# Handler of the 'remove bookmark' action. This function removes the patchset
# from the local bookmarked database managed by kw.
#
# @_patchset: Associative array reference with metadata of patchset
function handle_remove_bookmark_action()
{
  local -n _patchset="$1"
  local message_box

  delete_series_from_local_storage "${lore_config['save_patches_to']}" "${_patchset['message_id']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Warning' 'Could not delete patchset .mbx file'$'\n'"- ${_patchset['message_title']}"
    return
  fi

  remove_patchset_from_bookmark_by_url "${_patchset['message_id']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not unbookmark patchset'$'\n'"- ${_patchset['message_title']}"
    return
  fi

  message_box='Removed bookmark from patchset:'$'\n'"- ${_patchset['message_title']}"$'\n'$'\n'
  create_message_box 'Success' "$message_box"
}
