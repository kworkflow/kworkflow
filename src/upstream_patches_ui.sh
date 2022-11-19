# The upstream_patches_ui.sh file is responsible for centralizing all the UI
# and logic parts for the interface between developers and the public mailing
# list. We try not to add UI-specific technology here since we want to be able
# to plug in a new interface in the future. Also, this file connects the lore
# API with the UI.

include "${KW_LIB_DIR}/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/dialog_ui.sh"

declare -gr KW_UPSTREAM_TITLE='kw upstream patches manager'
declare -ga registered_lists

# TODO: Bookmarked patches must come from local database
declare -ga bookmarked_patches=(
  '2022-11-10 | #1   | drm/amd/pm: Enable bad memory page/channel recording support for smu v13_0_0'
  '2021-05-10 | #255 | DC Patches November 19, 2022'
  '2000-01-29 | #12  | drm/amdgpu: add drv_vram_usage_va for virt data exchange'
  '2022-07-01 | #7   | drm/amdgpu: fix pci device refcount leak'
)

# To make it easier to change between different screens, we implement a
# mechanism that uses this associative array to indicate the current screen to
# be shown.
declare -gA screen_sequence=(
  ['SHOW_SCREEN']='register'
  ['SHOW_SCREEN_PARAMETER']=''
)

# This function is responsible for managing the UI interface loop; here, it is
# possible to use the screen sequence used by this feature.
upstream_patches_ui_main()
{
  local all_registered_list="${lore_config['lists']}"
  local ret

  IFS=',' read -r -a registered_lists <<< "$all_registered_list"
  if [[ "${#registered_lists[@]}" != 0 ]]; then
    screen_sequence['SHOW_SCREEN']='dashboard'
  fi

  # Main loop
  while true; do
    case "${screen_sequence['SHOW_SCREEN']}" in
      'register')
        # First time here? Let's register some public mailing list
        register_mailing_list
        ret="$?"
        ;;
      'dashboard')
        # Main menu
        dashboard_entry_menu
        ret="$?"
        ;;
      'registered_mailing_list')
        registered_mailing_list
        ret="$?"
        ;;
      'bookmarked_patches')
        show_bookmarked_patches
        ret="$?"
        ;;
      'show_patch_details')
        show_patche_details
        ret="$?"
        ;;
    esac

    handle_exit "$ret"
  done
}

# Build the bookmark screen. Developers may want to save some patch for
# verification later, and the bookmark page address this requirement by
# providing a list of patches saved by the developers.
function dashboard_entry_menu()
{
  local message_box
  local -a menu_list_string_array

  # TODO: Get list from liblore
  menu_list_string_array=('Registered mailing list' 'Bookmarked patches')

  message_box="It looks like that you don't have any lore list registered; please"
  message_box+=' select one or more of the below list:'

  create_menu_options 'Dashboard' "$KW_UPSTREAM_TITLE" \
    "$message_box" 'menu_list_string_array' \
    'Exit' '' '' ''

  case "$menu_return_string" in
    1) # Registered mailing list
      screen_sequence['SHOW_SCREEN']='registered_mailing_list'
      ;;
    2) # Bookmarked patches
      screen_sequence['SHOW_SCREEN']='bookmarked_patches'
      ;;
  esac
}

# The bookmarked screen it is just a list of patches previously saved by the
# developer. For this reason, we just need to display the save patches.
function show_bookmarked_patches()
{
  # TODO: Get bookmarked_patches from the local database
  list_patches 'Bookmarked patches' bookmarked_patches
}

# Show all mailing list that the developer is registered
function registered_mailing_list()
{
  local message_box

  # TODO: Get list from liblore
  message_box="Below you can see all the mailing lists that you are registered:"

  create_menu_options 'Mailing lists' "$KW_UPSTREAM_TITLE" \
    "$message_box" 'registered_lists' \
    'Exit' '' '' '' 'no_index'
}

# This is a generic function used to show a list of patches. If the user select
# one specific patch, this function will set the next screen to be
# show_patch_details with the patch index saved in the SHOW_SCREEN_PARAMETER
# option.
#
# @message_box: Text description to the list of patches
# @_target_array_list: List of patches to be displayed
function list_patches()
{
  local message_box="$1"
  local -n _target_array_list="$2"
  local selected_patch

  # TODO: Get list from local store
  # Format patche like this:
  # printf 'V%-2s |#%-3s| %-100s' "$patch_version" "$total_patches" "$patch_title"

  message_box='List of bookmarked patches'

  create_menu_options 'Bookmarked patches' "$KW_UPSTREAM_TITLE" \
    "$message_box" '_target_array_list' \
    'Exit' '' '' ''

  selected_patch="$menu_return_string"

  if [[ -n "$selected_patch" ]]; then
    screen_sequence['SHOW_SCREEN']='show_patch_details'
    screen_sequence['SHOW_SCREEN_PARAMETER']="$selected_patch"
  fi
}

# Screen used to register to a new mailing list
function register_mailing_list()
{
  local message_box
  local new_list
  local -a menu_list_string_array

  # TODO: Get list from liblore
  menu_list_string_array=('lkml' 'amd-gfx' 'netdev' 'u-boot')

  message_box="It looks like that you don't have any lore list registered; please"
  message_box+=" select one or more of the below list:"

  create_simple_checklist 'Lore list' "$KW_UPSTREAM_TITLE" \
    "$message_box" 'menu_list_string_array' \
    'Exit' '' '' ''

  new_list=$(printf '%s' "$menu_return_string" | tr -s '[:blank:]' ',')

  if [[ -n "$new_list" ]]; then
    screen_sequence['SHOW_SCREEN']='dashboard'
    lore_config['lists']="${new_list}"
    # TODO: Update config file
  fi
}

load_lore_config
