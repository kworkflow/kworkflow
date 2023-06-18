include "${KW_LIB_DIR}/lib/dialog_ui.sh"

function build_setup_screen()
{
  local menu_title='Configure Compilation options'

  build_setup_compiler "$menu_title"

  # Main loop
  while true; do
    case "${screen_sequence['SHOW_SCREEN']}" in
      'menu_config_setup')
        # First time here? Let's register some public mailing list
        menu_config_setup_screen "$menu_title" 'SILENT'
        ret="$?"
        ;;
      'cross_compile')
        cross_compile_screen "$menu_title" 'SILENT'
        ret="$?"
        ;;
      'deploy_setup')
        return 0
        ;;
    esac

    handle_exit "$ret"
  done

}

function build_setup_compiler()
{
  local menu_title="$1"
  local flag="$2"
  local message_box
  local selected_option='GCC'
  declare -A menu_list_string_array=(['GCC']='' ['LLVM']='')

  message_box="${module_text_dictionary[configure_compiler]}"

  create_choice_list_screen "$menu_title" "$message_box" 'menu_list_string_array'
  ret="$?"

  case "$?" in
    0) # OK
      selected_option=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
      #if [[ "$selected_option" == 'LLVM' ]]
      #  build_config[use_llvm]='yes'
      #fi
      screen_sequence['SHOW_SCREEN']='menu_config_setup'
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

function menu_config_setup_screen()
{
  local menu_title="$1"
  local flag="$2"
  local message_box
  local message_box
  local selected_option='nconfig'
  declare -A menu_list_string_array=(
    ['nconfig']='Pseudo-graphical menu based on ncurses.'
    ['menuconfig']='An ncurses-based pseudo-graphical menu.'
    ['xconfig']='Graphical menu using Qt5. Requires qtwidgets to be installed'
    ['gconfig']='Graphical menu using GTK. Requires gtk+, glib, and libglade to be installed.'
  )

  message_box="${module_text_dictionary[menu_option]}"

  create_choice_list_screen "$menu_title" "$message_box" 'menu_list_string_array'
  ret="$?"

  case "$?" in
    0) # OK
      selected_option=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
      #if [[ "$selected_option" == 'LLVM' ]]
      #  build_config[use_llvm]='yes'
      #fi
      screen_sequence['SHOW_SCREEN']='cross_compile'
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

function cross_compile_screen()
{
  local menu_title="$1"
  local flag="$2"
  local message_box
  local selected_option=''
  declare -A menu_list_string_array=(
    ['ARM64']='CROSS_COMPILE=aarch64-linux-gnu- and ARCH=arm64'
    ['ARM32']='CROSS_COMPILE=arm-linux-gnueabihf- and ARCH=arm32'
    ['Sparc64']='ARCH=sparc64'
    ['PowerPC 32']='CROSS_COMPILE=powerpc-linux-gnu- and ARCH=powerpc'
    ['PowerPC 64']='CROSS_COMPILE=powerpc64-linux-gnu- and ARCH=powerpc'
    ['x86-32']='ARCH=i386')

  message_box="${module_text_dictionary[cross_compile]}"

  create_choice_list_screen "$menu_title" "$message_box" 'menu_list_string_array'
  ret="$?"

  case "$?" in
    0) # OK
      selected_option=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
      #if [[ "$selected_option" == 'LLVM' ]]
      #  build_config[use_llvm]='yes'
      #fi
      screen_sequence['SHOW_SCREEN']='deploy_setup'
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
