include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

# This function displays an input box that allows the user to search a string in
# the lore archives.
function show_search_string_in_lore() {
  local -a list_of_options_array
  local message_box
  local ret

  message_box='This string will be searched in the entirety of the lore archives.'

  create_inputbox_screen 'Input string to be searched' "$message_box" 'Return'
  ret="$?"

  case "$ret" in
    0) # OK
      search_string_in_lore "$menu_return_string"
      ;;
    1) # Exit
      handle_exit "$ret"
      ;;
    3) # Return
      screen_sequence['SHOW_SCREEN']='dashboard'
      screen_sequence['SHOW_SCREEN_PARAMETER']=''
      ;;
  esac
}

# This function handles the search of a string in lore. It does this by passing
# the string as a query filter for the `latest_patchsets_from_mailing_list` screen.
#
# @string: String to be searched in lore.
function search_string_in_lore() {
  local string="$1"

  if [[ -z "$string" ]]; then
    create_message_box 'Error' 'Inputted string should not be empty.'
    return
  fi

  # Set mailing list to 'all' to search on all lore archives
  current_mailing_list='all'

  screen_sequence['SHOW_SCREEN']='latest_patchsets_from_mailing_list'
  additional_filters="$(url_encode "$string")"
}
