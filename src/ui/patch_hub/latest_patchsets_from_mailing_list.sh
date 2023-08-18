include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

declare -g PAGE=1
declare -ga formatted_patchsets_list

# This function displays a list of the latest patchsets from a target mailing list.
# These patchsets are ordered by their recieved time in the lore.kernel.org servers.
function show_latest_patchsets_from_mailing_list()
{
  local starting_index
  local ending_index
  local box_title
  local extra_label='Previous'

  create_loading_screen_notification "Loading patchsets from ${current_mailing_list} list"
  # Query patches from mailing list, this info will be saved at `list_of_mailinglist_patches[@]`.
  fetch_latest_patchsets_from "$current_mailing_list" "$PAGE" "${lore_config['patchsets_per_page']}"
  if [[ "$?" != 0 ]]; then
    create_message_box 'Error' "Couldn't fetch patchsets from ${current_mailing_list} list."
    screen_sequence['SHOW_SCREEN']='registered_mailing_lists'
    return
  fi

  # Getting the indexes of range from target page
  starting_index=$(get_page_starting_index "$PAGE" "${lore_config['patchsets_per_page']}")
  ending_index=$(get_page_ending_index "$PAGE" "${lore_config['patchsets_per_page']}")
  # Format and load patchset metadata for display, in case it wasn't done
  if [[ "$((ending_index + 1))" -gt "${#formatted_patchsets_list[@]}" ]]; then
    format_patchsets 'formatted_patchsets_list' "$starting_index" "$ending_index"
  fi
  box_title="Patchsets from ${current_mailing_list} (page ${PAGE})"
  [[ "$PAGE" == 1 ]] && extra_label='Return'
  create_menu_options "$box_title" '' 'formatted_patchsets_list' "$starting_index" "$ending_index" "$extra_label" 'Next' 'Exit'
  ret="$?"

  case "$ret" in
    0) # OK
      screen_sequence['PREVIOUS_SCREEN']='latest_patchsets_from_mailing_list'
      screen_sequence['SHOW_SCREEN_PARAMETER']=${list_of_mailinglist_patches["$menu_return_string"]}
      screen_sequence['SHOW_SCREEN']='patchset_details_and_actions'
      ;;
    1) # Next
      ((PAGE++))
      ;;
    2) # Exit
      handle_exit 1
      ;;
    3) # Previous
      ((PAGE--))
      if [[ "$PAGE" == 0 ]]; then
        reset_current_lore_fetch_session
        PAGE=1
        formatted_patchsets_list=()
        screen_sequence['SHOW_SCREEN']='registered_mailing_lists'
      fi
      ;;
  esac
}
