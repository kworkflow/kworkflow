# The upstream_patches_ui.sh file is responsible for centralizing all the UI
# and logic parts for the interface between developers and the public mailing
# list. We try not to add UI-specific technology here since we want to be able
# to plug in a new interface in the future. Also, this file connects the lore
# API with the UI.
include "${KW_LIB_DIR}/lib/dialog_ui.sh"

# This function is responsible for managing the UI interface loop; here, it is
# possible to use the screen sequence used by this feature.
upstream_patches_ui_main()
{
  # Main loop
  while true; do
    exec 3>&1
    bookmark_menu
    exit_status="$?"
    exec 3>&-

    # Handling stop
    case "$exit_status" in
      1 | 255) # Exit
        clear
        exit 0
        ;;
    esac

    case "$menu_return_string" in
      1)
        printf 'This is a simple test\n'
        exit
        ;;
      2)
        printf 'Yet, another simple test\n'
        exit
        ;;
    esac

  done
}

# Build the bookmark screen. Developers may want to save some patch for
# verification later, and the bookmark page address this requirement by
# providing a list of patches saved by the developers.
function bookmark_menu()
{
  local message_box
  local -a menu_list_string_array

  # TODO: Get list from liblore
  menu_list_string_array=('amdgfx' 'drm' 'Linux iio' 'kernel jenitors' 'git list')

  message_box="It looks like that you don't have any lore list registered; please"
  message_box+=' select one or more of the below list:'

  create_menu_options 'Simple test' 'Mailing list' \
    "$message_box" 'menu_list_string_array' \
    'Exit' '' '' ''
}
