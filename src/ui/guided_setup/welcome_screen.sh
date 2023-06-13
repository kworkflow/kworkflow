include "${KW_LIB_DIR}/lib/dialog_ui.sh"

function welcome_screen()
{
  local flag="$1"
  local message_box
  local ret
  local width
  local height

  message_box="${module_text_dictionary[welcome_page]}"

  create_yes_no_message 'Welcome to kw setup' "$message_box" '' '' 'Next' 'Exit'
  ret="$?"

  case "$ret" in
    0) # OK
      screen_sequence['SHOW_SCREEN']='build_setup'
      ;;
    1) # Cancel
      handle_exit "$ret"
      ;;
    3) # Return
      screen_sequence['SHOW_SCREEN']='welcome'
      screen_sequence['RETURNING']=1
      ;;
  esac
}

