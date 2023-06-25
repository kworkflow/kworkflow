include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

# This function is responsible for showing the screen with a patchset details
# and actions available. The `@show_bookmarked_patchset` variable setted indicates
# that the patchset is a bookmarked one, which has different actions available.
#
# @raw_patchset: Raw data of patchset to be displayed
# @show_bookmarked_patchset: If set, the patchset to be shown is bookmarked
function show_series_details()
{
  local raw_patchset="$1"
  local show_bookmarked_patchset="$2"
  declare -A series
  local -a action_list
  local -a check_statuses=()
  local patch_metadata
  local message_box

  if [[ -n "$show_bookmarked_patchset" ]]; then
    action_list=('Unbookmark')
  else
    # TODO: Add apply patch
    action_list=('Bookmark' 'Download')

    is_bookmarked "${raw_patchset}"
    if [[ "$?" == 0 ]]; then
      check_statuses[0]=1
      # TODO: when we refine the 'Download' action, we should revise the set below
      check_statuses[1]=1
    fi
  fi

  parse_raw_series "${raw_patchset}" 'series'
  patch_metadata=$(prettify_string 'Series:' "${series['patch_title']}")
  patch_metadata+=$(prettify_string 'Author:' "${series['patch_author']}")
  patch_metadata+=$(prettify_string 'Version:' "${series['patch_version']}")
  patch_metadata+=$(prettify_string 'Patches:' "${series['total_patches']}")
  message_box="$patch_metadata"

  create_simple_checklist 'Patchset info and actions' "$message_box" 'action_list' 'check_statuses' 1
  ret="$?"

  case "$ret" in
    0) # OK
      IFS=' ' read -ra selected_options <<< "$menu_return_string"
      for option in "${selected_options[@]}"; do
        case "$option" in
          'Unbookmark')
            handle_unbookmark_action 'series'
            ;;
          'Bookmark')
            handle_bookmark_action 'series' "$raw_patchset"
            ;;
          'Download')
            handle_download_action 'series'
            ;;
        esac
      done
      ;;

    1) # Exit
      handle_exit "$ret"
      ;;

    3) # Return
      if [[ -n "$show_bookmarked_patchset" ]]; then
        screen_sequence['SHOW_SCREEN']='bookmarked_patches'
      else
        screen_sequence['SHOW_SCREEN']='show_new_patches_in_the_mailing_list'
      fi
      screen_sequence['RETURNING']=1
      ;;
  esac
}

# TODO: Document and test this function
function handle_bookmark_action()
{
  local -n _series="$1"
  local raw_series="$2"
  local output

  create_loading_screen_notification 'Bookmarking patch(es)'$'\n'"- ${_series['patch_title']}"

  output=$(download_series "${_series['patch_url']}" "${lore_config['save_patches_to']}")
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not download patch(es):'$'\n'"- ${_series['patch_title']}"$'\n'"[error message] ${output}"
  fi

  add_series_to_bookmark "${raw_series}" "${lore_config['save_patches_to']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not bookmark patch(es)'$'\n'"- ${_series['patch_title']}"
  fi
}

# TODO: Document and test this function
function handle_download_action()
{
  local -n _series="$1"
  local output

  create_loading_screen_notification 'Downloading patch(es)'$'\n'"- ${_series['patch_title']}"

  output=$(download_series "${_series['patch_url']}" "${lore_config['save_patches_to']}")
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not download patch(es):'$'\n'"- ${_series['patch_title']}"$'\n'"[error message] ${output}"
  fi
}

# TODO: Document and test this function
function handle_unbookmark_action()
{
  local -n _series="$1"

  delete_series_from_local_storage "${_series['download_dir_path']}" "${_series['patch_url']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not delete patch(es)'$'\n'"- ${_series['patch_title']}"
  fi

  remove_patchset_from_bookmark_by_id "${_series['patch_id']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not unbookmark patch(es)'$'\n'"- ${_series['patch_title']}"
  fi

  screen_sequence['SHOW_SCREEN']='bookmarked_patches'
}
