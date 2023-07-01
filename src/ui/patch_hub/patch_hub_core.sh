# The `patch_hub_core.sh` file centralizes the states representing the
# sequences of screen of the `patch-hub` feature. The feature is implemented
# as a state-machine that roughly follows the Model-View-Controller pattern. The roles
# being:
# - Model: `src/lib/lore.sh`
# - View: `src/lib/dialog.sh`
# - Controller: `src/ui/patch_hub`
#
# To keep the code clean and modular, it is best to break down major screen-sequences
# (like 'Settings') in small files that should reside in the Controller directory.

include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/dialog_ui.sh"
include "${KW_LIB_DIR}/lib/lore.sh"
include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/ui/patch_hub/settings.sh"
include "${KW_LIB_DIR}/ui/patch_hub/series_details.sh"

# These are references to data structures used all around the state-machine.
declare -ga registered_lists
declare -ga patches_from_mailing_list
declare -ga bookmarked_series
declare -g current_mailing_list

# This associative array is used to determine the states and  topass arguments
# between states.
declare -gA screen_sequence=(
  ['SHOW_SCREEN']=''
  ['SHOW_SCREEN_PARAMETER']=''
  ['RETURNING']=''
)

# This function is the main loop of the state-machine that represents the feature.
# It delegates the processing of states and state transitions to other functions.
function patch_hub_main_loop()
{
  local ret

  # Load UI variables that define screen size, layout and others.
  ui_setup "${lore_config['dialog_layout']}"

  # Load the registered lists from the file to the data structure
  IFS=',' read -r -a registered_lists <<< "${lore_config['lists']}"

  # "Dashboard" is the default state
  screen_sequence['SHOW_SCREEN']='dashboard'

  # In case the user doesn't have any mailing list registered, the first
  # state should be "Register/Unregister Mailing Lists"
  if [[ "${#registered_lists[@]}" == 0 ]]; then
    screen_sequence['SHOW_SCREEN']='manage_mailing_lists'
  fi

  # Main loop of the state-machine
  while true; do
    case "${screen_sequence['SHOW_SCREEN']}" in
      'dashboard')
        dashboard_entry_menu
        ret="$?"
        ;;
      'manage_mailing_lists')
        show_mailing_lists_screen
        ret="$?"
        ;;
      'registered_mailing_list')
        registered_mailing_list
        ret="$?"
        ;;
      'show_new_patches_in_the_mailing_list')
        show_new_patches_in_the_mailing_list "${screen_sequence['SHOW_SCREEN_PARAMETER']}"
        ret="$?"
        ;;
      'bookmarked_patches')
        show_bookmarked_patches
        ret="$?"
        ;;
      'settings')
        show_settings_screen
        ret="$?"
        ;;
      'series_details')
        show_series_details "${screen_sequence['SHOW_SCREEN_PARAMETER']}" list_of_mailinglist_patches
        ret="$?"
        ;;
      'bookmarked_series_details')
        show_bookmarked_series_details "${screen_sequence['SHOW_SCREEN_PARAMETER']}"
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
  local message_box
  local ret

  menu_list_string_array=('Registered mailing list' 'Bookmarked patches' 'Settings')

  message_box=''

  create_menu_options 'Dashboard' "$message_box" 'menu_list_string_array'
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain 'Something went wrong when kw tried to display the Dashboad screen.'
    return "$ret"
  fi

  case "$menu_return_string" in
    1) # Registered mailing list
      screen_sequence['SHOW_SCREEN']='registered_mailing_list'
      ;;
    2) # Bookmarked patches
      screen_sequence['SHOW_SCREEN']='bookmarked_patches'
      ;;
    3) # Settings
      screen_sequence['SHOW_SCREEN']='settings'
      ;;
  esac
}

# The bookmarked screen it is just a list of patches previously saved by the
# developer. For this reason, we just need to display the save patches.
function show_bookmarked_patches()
{
  local fallback_message

  if [[ -z "${screen_sequence['RETURNING']}" ]]; then
    get_bookmarked_series bookmarked_series
  fi

  # Avoiding stale value
  screen_sequence['RETURNING']=''

  fallback_message='kw could not find any bookmarked patches.'$'\n'$'\n'
  fallback_message+='Try bookmarking patches in the menu "Registered mailing list"'
  list_patches 'Bookmarked patches' bookmarked_series "${screen_sequence['SHOW_SCREEN']}" "${fallback_message}"
}

# Show all mailing list that the developer is registered
function registered_mailing_list()
{
  local message_box
  local selected_list
  local ret

  message_box='Below you can see all the mailing lists that you are registered:'

  create_menu_options 'Mailing lists' "$message_box" 'registered_lists' 1
  ret="$?"

  selected_list=$((menu_return_string - 1)) # Normalize array index
  case "$ret" in
    0) # OK
      screen_sequence['SHOW_SCREEN']='show_new_patches_in_the_mailing_list'
      screen_sequence['SHOW_SCREEN_PARAMETER']="${registered_lists[$selected_list]}"
      ;;
    1) # Exit
      handle_exit "$ret"
      ;;
    3) # Return
      screen_sequence['SHOW_SCREEN']='dashboard'
      ;;
  esac
}

function show_new_patches_in_the_mailing_list()
{
  local -a new_patches
  local fallback_message

  # If returning from a 'show_series_details' screen, i.e., we already fetched the information needed to render this screen.
  if [[ -n "${screen_sequence['RETURNING']}" ]]; then
    # Avoiding stale value
    screen_sequence['RETURNING']=''
  else
    current_mailing_list="$1"
    create_loading_screen_notification "Loading patches from ${current_mailing_list} list"
    # Query patches from mailing list, this info will be saved at "${list_of_mailinglist_patches[@]}".
    get_patches_from_mailing_list "$current_mailing_list" patches_from_mailing_list
  fi

  fallback_message='kw could not retrieve patches from this mailing list'
  list_patches "Patches from ${current_mailing_list}" patches_from_mailing_list \
    "${screen_sequence['SHOW_SCREEN']}" "${fallback_message}"
}

# This is a generic function used to show a list of patches. If the user select
# one specific patch, this function will set the next screen to be
# show_patch_details with the patch index saved in the SHOW_SCREEN_PARAMETER
# option.
#
# @message_box: Text description to the list of patches
# @_target_array_list: List of patches to be displayed
# @previous_screen: Determines the next screen if an option is chosen
# @fallback_message: Message for when there are no patches to display
function list_patches()
{
  local menu_title="$1"
  local -n _target_array_list="$2"
  local previous_screen="$3"
  local fallback_message="$4"
  local selected_patch
  local ret

  if [[ -z "${_target_array_list}" ]]; then
    create_message_box "${menu_title}" "${fallback_message}"
    screen_sequence['SHOW_SCREEN']='dashboard'
    return "$?"
  fi

  create_menu_options "${menu_title}" '' '_target_array_list' 1
  ret="$?"

  selected_patch=$((menu_return_string - 1))

  case "$ret" in
    0) # OK
      case "$previous_screen" in
        'show_new_patches_in_the_mailing_list')
          screen_sequence['SHOW_SCREEN']='series_details'
          ;;
        'bookmarked_patches')
          screen_sequence['SHOW_SCREEN']='bookmarked_series_details'
          ;;
      esac
      screen_sequence['SHOW_SCREEN_PARAMETER']="$selected_patch"
      ;;
    1) # Exit
      handle_exit "$ret"
      ;;
    3) # Return
      screen_sequence['SHOW_SCREEN']='dashboard'
      ;;
  esac
}

# Screen used to manage the mailing lists
function show_mailing_lists_screen()
{
  local message_box
  local new_list
  local -a menu_list_string_array
  local -a check_statuses=()
  local index=0
  local lore_config_path="${PWD}/.kw/lore.config"
  local ret

  if [[ ! -f "${lore_config_path}" ]]; then
    lore_config_path="${KW_ETC_DIR}/lore.config"
  fi

  create_loading_screen_notification 'Retrieving available mailing lists from lore.kernel.org'
  retrieve_available_mailing_lists

  # shellcheck disable=SC2207
  IFS=$'\n' menu_list_string_array=($(sort <<< "${!available_lore_mailing_lists[*]}"))
  unset IFS

  # Put check marks on mailing lists already registered
  for list in "${menu_list_string_array[@]}"; do
    check_statuses["$index"]=0
    # substring of others (e.g. 'yocto' and 'yocto-docs') may lead to false positives.
    IFS=',' read -r -a registered_lists <<< "${lore_config['lists']}"
    for registered_list in "${registered_lists[@]}"; do
      [[ "$list" == "$registered_list" ]] && check_statuses["$index"]=1
    done
    ((index++))
  done

  if [[ -z "${lore_config['lists']}" ]]; then
    message_box="It looks like that you don't have any lore list registered."
    message_box+=" Please, select one or more of the list below:"
  fi

  create_simple_checklist 'Register/Unresgister Mailing Lists' "$message_box" 'menu_list_string_array' \
    'check_statuses' 1
  ret="$?"

  new_list=$(printf '%s' "$menu_return_string" | tr -s '[:blank:]' ',')

  case "$ret" in
    0) # OK
      if [[ -n "$new_list" ]]; then
        screen_sequence['SHOW_SCREEN']='dashboard'
        lore_config['lists']="${new_list}"
        IFS=',' read -r -a registered_lists <<< "$new_list"
        sed -i -r "s<(lists=).*<\1${new_list}<" "$lore_config_path"
      fi
      ;;
    1) # Exit
      handle_exit "$ret"
      ;;
    3) # Return
      screen_sequence['SHOW_SCREEN']='dashboard'
      ;;
  esac
}

load_lore_config
