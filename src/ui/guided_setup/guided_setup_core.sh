include "${KW_LIB_DIR}/ui/guided_setup/welcome_screen.sh"
include "${KW_LIB_DIR}/lib/dialog_ui.sh"
include "${KW_LIB_DIR}/kwlib.sh"

declare -gA screen_sequence=(
  ['SHOW_SCREEN']='welcome'
  ['SHOW_SCREEN_PARAMETER']=''
  ['RETURNING']=''
)

function guided_setup_main_loop()
{
  local ret

  load_module_text "${KW_ETC_DIR}/strings/guided_init.txt"
  ui_setup "${lore_config['dialog_layout']}"

  columns=$(eval tput"${TPUTTERM}" cols)

  # Main loop
  while true; do
    case "${screen_sequence['SHOW_SCREEN']}" in
      'welcome')
        # First time here? Let's register some public mailing list
        welcome_screen 'SILENT'
        ret="$?"
        ;;
      'build_setup')
        exit
        ;;
    esac

    handle_exit "$ret"
  done
}

