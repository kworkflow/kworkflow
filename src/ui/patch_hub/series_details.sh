include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

# Screen resposible for show a specific patch details
#
# @patch_index: Patch index
# @_target_patch_metadata: List with patches metadata
function show_series_details()
{
  local patch_index="$1"
  local -n _target_patch_metadata="$2"
  declare -A series
  local -a action_list
  local -a check_statuses=('' '')
  local patch_metadata
  local raw_series
  local message_box

  # TODO: Add apply patch
  action_list=('Bookmark' 'Download')

  raw_series=${_target_patch_metadata["$patch_index"]}
  parse_raw_series "${raw_series}" 'series'

  patch_metadata=$(prettify_string 'Series:' "${series['patch_title']}")
  patch_metadata+=$(prettify_string 'Author:' "${series['patch_author']}")
  patch_metadata+=$(prettify_string 'Version:' "${series['patch_version']}")
  patch_metadata+=$(prettify_string 'Patches:' "${series['total_patches']}")
  message_box="$patch_metadata"

  is_bookmarked "${raw_series}"
  if [[ "$?" == 0 ]]; then
    check_statuses[0]=1
    # TODO: when we refine the 'Download' action, we should revise the set below
    check_statuses[1]=1
  fi

  create_simple_checklist 'Patch(es) info and actions' "$message_box" 'action_list' 'check_statuses' 1
  ret="$?"

  case "$ret" in
    0) # OK
      IFS=' ' read -ra selected_options <<< "$menu_return_string"
      for option in "${selected_options[@]}"; do
        case "$option" in
          'Bookmark')
            handle_bookmark_action 'series' "$raw_series"
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
      screen_sequence['SHOW_SCREEN']='show_new_patches_in_the_mailing_list'
      screen_sequence['RETURNING']=1
      ;;
  esac
}

# Screen resposible for showing a specific bookmarked series details
#
# @series_index: Series index
function show_bookmarked_series_details()
{
  local series_index="$1"
  declare -A series
  local -a action_list
  local -a check_statuses=('')
  local patch_metadata
  local raw_series
  local message_box

  action_list=('Unbookmark')

  # The local bookmark database starting index is 1 and the index
  # passed as argument starts at 0.
  if [[ ! "${series_index}" =~ ^[0-9]+$ || "${series_index}" -lt 0 ]]; then
    complain "Invalid value for series_index: '${series_index}'"
    handle_exit 22 # EINVAL
  fi

  ((series_index++))

  raw_series=$(get_bookmarked_series_by_index "${series_index}")
  parse_raw_series "${raw_series}" 'series'

  patch_metadata=$(prettify_string 'Series:' "${series['patch_title']}")
  patch_metadata+=$(prettify_string 'Author:' "${series['patch_author']}")
  patch_metadata+=$(prettify_string 'Version:' "${series['patch_version']}")
  patch_metadata+=$(prettify_string 'Patches:' "${series['total_patches']}")
  message_box="$patch_metadata"

  create_simple_checklist 'Bookmarked Series info and actions' "$message_box" 'action_list' 'check_statuses' 1
  ret="$?"

  case "$ret" in
    0) # OK
      IFS=' ' read -ra selected_options <<< "$menu_return_string"
      for option in "${selected_options[@]}"; do
        case "$option" in
          'Unbookmark')
            handle_unbookmark_action 'series' "$series_index"
            ;;
        esac
      done
      ;;

    1) # Exit
      handle_exit "$ret"
      ;;

    3) # Return
      screen_sequence['SHOW_SCREEN']='bookmarked_patches'
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
  local series_index="$2"

  delete_series_from_local_storage "${_series['download_dir_path']}" "${_series['patch_url']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not delete patch(es)'$'\n'"- ${_series['patch_title']}"
  fi

  remove_series_from_bookmark_by_index "${series_index}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' 'Could not unbookmark patch(es)'$'\n'"- ${_series['patch_title']}"
  fi

  screen_sequence['SHOW_SCREEN']='bookmarked_patches'
}
