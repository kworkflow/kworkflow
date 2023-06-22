# The `upstream_patches_ui_core.sh` file centralizes the states representing the
# sequences of screen of the `upstream-patches-ui` feature. The feature is implemented
# as a state-machine that roughly follows the Model-View-Controller pattern. The roles
# being:
# - Model: `src/lib/lore.sh`
# - View: `src/lib/dialog.sh`
# - Controller: `src/ui/upstream_patches_ui`
#
# To keep the code clean and modular, it is best to break down major screen-sequences
# (like 'Settings') in small files that should reside in the Controller directory.

include "${KW_LIB_DIR}/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/dialog_ui.sh"
include "${KW_LIB_DIR}/lib/lore.sh"
include "${KW_LIB_DIR}/kwio.sh"
include "${KW_LIB_DIR}/kwlib.sh"

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
function upstream_patches_ui_main_loop()
{
  local ret

  # Load UI variables that define screen size, layout and others.
  ui_setup "${lore_config['dialog_layout']}"

  # "Dashboard" is the default state
  screen_sequence['SHOW_SCREEN']='dashboard'

  # In case the user doesn't have any mailing list registered, the first
  # state should be "Register/Unregister Mailing Lists"
  if [[ -z "${lore_config['lists']}" ]]; then
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
      'show_series_details')
        show_series_details "${screen_sequence['SHOW_SCREEN_PARAMETER']}" list_of_mailinglist_patches
        ret="$?"
        ;;
      'show_bookmarked_series_details')
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
            delete_series_from_local_storage "${series['download_dir_path']}" "${series['patch_url']}"
            if [[ "$?" != 0 ]]; then
              create_message_box 'Error' 'Could not delete patch(es)'$'\n'"- ${series['patch_title']}"
              continue
            fi
            remove_series_from_bookmark_by_index "${series_index}"
            if [[ "$?" != 0 ]]; then
              create_message_box 'Error' 'Could not unbookmark patch(es)'$'\n'"- ${series['patch_title']}"
            fi
            screen_sequence['SHOW_SCREEN']='bookmarked_patches'
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

# Screen that shows all types of settings available.
function show_settings_screen()
{
  local lore_config_path="${PWD}/.kw/lore.config"
  local -a menu_list_string_array
  local new_value
  local output
  declare -A branches
  local index
  local -a check_statuses
  local ret

  if [[ ! -f "${lore_config_path}" ]]; then
    lore_config_path="${KW_ETC_DIR}/lore.config"
  fi

  menu_list_string_array=(
    'Register/Unregister Mailing Lists'
    'Save Patches To'
    'Kernel Tree Path'
    'Kernel Tree Target Branch'
  )
  create_menu_options 'Settings' '' 'menu_list_string_array' 1
  ret="$?"

  case "$ret" in
    0) # OK
      case "$menu_return_string" in
        1) # Register/Unregister Mailing Lists
          screen_sequence['SHOW_SCREEN']='manage_mailing_lists'
          ;;
        2) # Save Patches To
          create_directory_selection_screen "${lore_config['save_patches_to']}" 'Select directory where patches will be downloaded'
          case "$?" in
            0) # OK
              new_value=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
              if [[ ! -d "$new_value" ]]; then
                create_message_box 'Error' "${new_value}: No such directory."
              else
                output=$(save_new_lore_config 'save_patches_to' "$new_value" "$lore_config_path")
                if [[ "$?" != 0 ]]; then
                  create_message_box 'Error' "Failed to save new value ${new_value} in ${lore_config_path}:"$'\n'"$output"
                fi
                # As we altered the settings, we need to reload lore.config
                load_lore_config
              fi
              ;;
            1) # Cancel
              ;;
            2) # Help
              create_help_screen 'directory_selection'
              if [[ "$?" != 0 ]]; then
                create_message_box 'Error' 'Cannot create help screen'
              fi
              ;;
          esac

          # Just to be safe
          screen_sequence['SHOW_SCREEN']='settings'
          ;;
        3) # Kernel Tree Path
          create_directory_selection_screen "${lore_config['kernel_tree_path']}" 'Select Linux kernel source tree'
          case "$?" in
            0) # OK
              new_value=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
              if ! is_kernel_root "$new_value"; then
                create_message_box 'Error' "${new_value}: Not a Linux kernel source tree."
              else
                new_value=$(realpath "$new_value")
                save_new_lore_config 'kernel_tree_path' "$new_value" "$lore_config_path"
                # As we changed the kernel tree, we set the target branch to empty
                save_new_lore_config 'kernel_tree_branch' '' "$lore_config_path"
                # As we altered the settings, we need to reload lore.config
                load_lore_config
              fi
              ;;
            1) # Cancel
              ;;
            2) # Help
              create_help_screen 'directory_selection'
              if [[ "$?" != 0 ]]; then
                create_message_box 'Error' 'Cannot create help screen'
              fi
              ;;
          esac
          # Just to be safe
          screen_sequence['SHOW_SCREEN']='settings'
          ;;
        4) # Kernel Tree Target Branch
          if [[ -z "${lore_config['kernel_tree_path']}" ]]; then
            create_message_box 'Error' 'You need to set "Kernel Tree Path" first.'
          else
            get_git_repository_branches "${lore_config['kernel_tree_path']}" 'branches'
            index=0
            for branch in "${!branches[@]}"; do
              [[ "${lore_config['kernel_tree_branch']}" == "$branch" ]] && check_statuses["$index"]=1
              ((index++))
            done
            message_box='Select the target branch of the Linux kernel tree.'$'\n'
            message_box+='When applying patches, this branch will be used as base.'
            create_choice_list_screen 'Kernel Tree Target Branch' "$message_box" 'branches' 'check_statuses'
            case "$?" in
              0) # OK
                new_value=$(printf '%s' "$menu_return_string" | sed 's/\/$//')
                save_new_lore_config 'kernel_tree_branch' "$new_value" "$lore_config_path"
                # As we altered the settings, we need to reload lore.config
                load_lore_config
                ;;
              1) # Cancel
                ;;
            esac
          fi
          # Just to be safe
          screen_sequence['SHOW_SCREEN']='settings'
          ;;
      esac
      ;;
    1) # Exit
      handle_exit "$ret"
      ;;
    3) # Return
      screen_sequence['SHOW_SCREEN']='dashboard'
      ;;
  esac
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
  local output

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
            create_loading_screen_notification 'Bookmarking patch(es)'$'\n'"- ${series['patch_title']}"
            output=$(download_series "${series['patch_url']}" "${lore_config['save_patches_to']}")
            if [[ "$?" != 0 ]]; then
              create_message_box 'Error' 'Could not download patch(es):'$'\n'"- ${series['patch_title']}"$'\n'"[error message] ${output}"
              continue
            fi
            add_series_to_bookmark "${raw_series}" "${lore_config['save_patches_to']}"
            if [[ "$?" != 0 ]]; then
              create_message_box 'Error' 'Could not bookmark patch(es)'$'\n'"- ${series['patch_title']}"
            fi
            ;;
          'Download')
            create_loading_screen_notification 'Downloading patch(es)'$'\n'"- ${series['patch_title']}"
            output=$(download_series "${series['patch_url']}" "${lore_config['save_patches_to']}")
            if [[ "$?" != 0 ]]; then
              create_message_box 'Error' 'Could not download patch(es):'$'\n'"- ${series['patch_title']}"$'\n'"[error message] ${output}"
            fi
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
          screen_sequence['SHOW_SCREEN']='show_series_details'
          ;;
        'bookmarked_patches')
          screen_sequence['SHOW_SCREEN']='show_bookmarked_series_details'
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
