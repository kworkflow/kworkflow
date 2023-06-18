include "${KW_LIB_DIR}/lib/dialog_ui.sh"

function deploy_setup_screen()
{
  local menu_title='Configure Deploy Options'

  deploy_target_setup "$menu_title" 'SILENT'

  # Main loop
  while true; do
    case "${screen_sequence['SHOW_SCREEN']}" in
      'deploy_remote_setup')
        # First time here? Let's register some public mailing list
        deploy_remote_setup "$menu_title" 'SILENT'
        ret="$?"
        ;;
      'deploy_setup_reboot')
        deploy_setup_reboot "$menu_title" 'SILENT'
        ret="$?"
        ;;
    esac

    handle_exit "$ret"
  done

}

function deploy_target_setup()
{
  local menu_title="$1"
  local flag="$2"
  local message_box
  local selected_option='Remote'
  declare -A menu_list_string_array=(['Remote']='' ['Local']='')

  message_box="${module_text_dictionary[configure_compiler]}"

  create_choice_list_screen "$menu_title" "$message_box" 'menu_list_string_array'
  ret="$?"

  case "$?" in
    0) # OK
      selected_option=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
      if [[ "$selected_option" == 'Remote' ]]; then
        screen_sequence['SHOW_SCREEN']='deploy_remote_setup'
      else
        screen_sequence['SHOW_SCREEN']='deploy_setup_reboot'
      fi
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

function deploy_remote_setup()
{
  local menu_title="$1"
  local flag="$2"
  local message_box
  local selected_option='Remote'
  declare -a fields_list=('User' 'IP' 'Port')

  message_box="${module_text_dictionary[configure_compiler]}"

  create_form_screen 'Deploy Setup' 'Test' 'Back title' 'fields_list' 'Next' 'Previos' 'Exit'
  ret="$?"

  case "$?" in
    0) # OK
      selected_option=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
      if [[ "$selected_option" == 'Remote' ]]; then
        screen_sequence['SHOW_SCREEN']='deploy_remote_setup'
      fi

      screen_sequence['SHOW_SCREEN']='deploy_setup_reboot'

      screen_sequence['SHOW_SCREEN']=''
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

