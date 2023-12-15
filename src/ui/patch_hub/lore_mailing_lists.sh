#!/bin/bash
include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

# This function displays a checklist menu of the available mailing lists from lore.kernel.org
# sorted by lexicographic order for the user to define the set of registered lists.
function show_lore_mailing_lists()
{
  local -a available_lore_mailing_lists_array
  local -a lists_check_status=()
  local menu_title
  local message_box
  local new_registered_lists
  local lore_config_path="${PWD}/.kw/lore.config"
  local ret
  local loading_pid

  if [[ ! -f "${lore_config_path}" ]]; then
    lore_config_path="${KW_ETC_DIR}/lore.config"
  fi

  create_async_loading_screen_notification 'Retrieving available mailing lists from lore.kernel.org' &
  loading_pid="$!"

  # This call retrieves the available mailing lists archived on lore.kernel.org and
  # stores it in the `available_lore_mailing_lists` associative array.
  retrieve_available_mailing_lists
  convert_available_lore_mailing_lists_to_array 'available_lore_mailing_lists' 'available_lore_mailing_lists_array'
  get_lists_check_status 'available_lore_mailing_lists_array' 'lists_check_status' "${lore_config['lists']}"

  stop_async_loading_screen_notification "$loading_pid"

  menu_title='Register/Unresgister Mailing Lists'
  # Add a message to the user in case there are no registered list.
  if [[ -z "${lore_config['lists']}" ]]; then
    message_box="It looks like that you don't have any lore list registered."
    message_box+=" Please, select one or more of the list below:"
  fi

  create_simple_checklist "$menu_title" "$message_box" 'available_lore_mailing_lists_array' \
    'lists_check_status' 1
  ret="$?"

  case "$ret" in
    0) # OK
      new_registered_lists=$(printf '%s' "$menu_return_string" | tr -s '[:blank:]' ',')
      save_new_lore_config 'lists' "$new_registered_lists" "$lore_config_path"

      # As we altered the settings, we need to reload lore.config
      load_lore_config

      screen_sequence['SHOW_SCREEN']='dashboard'
      ;;
    1) # Exit
      handle_exit "$ret"
      ;;
    3) # Return
      screen_sequence['SHOW_SCREEN']='dashboard'
      ;;
  esac
}

# This function converts the available mailing lists from lore.kernel.org stored in the
# associative array to an array. The way `available_lore_mailing_lists` is structured is
# that the keys are the names of the lists and the values are the descriptions. This
# converts the keys (i.e. the names of the lists) into a sorted array
#
# @_available_lore_mailing_lists: Associative array reference to lore mailing lists
# @_available_lore_mailing_lists_array: Array reference to store sorted lore mailing lists
function convert_available_lore_mailing_lists_to_array()
{
  local -n _available_lore_mailing_lists="$1"
  local -n _available_lore_mailing_lists_array="$2"

  # shellcheck disable=SC2207
  IFS=$'\n' _available_lore_mailing_lists_array=($(sort <<< "${!_available_lore_mailing_lists[*]}"))
  unset IFS
}

# This function assigns the check status of the lists in the `@_lists` array
# and stores it in the `@_lists_check_status` array using the `@registered_lists_string`
# string. A list is considered 'checked' if it is a registered list.
#
# @_lists: Array reference to the lists
# @_lists_check_status: Array reference to the check statuses of the lists
# @registered_lists_string: String containing the registered lists (which are
#   considered checked) separated by comma
function get_lists_check_status()
{
  local -n _lists="$1"
  local -n _lists_check_status="$2"
  local registered_lists_string="$3"
  local index=0

  for list in "${_lists[@]}"; do
    _lists_check_status["$index"]=0

    # substring of others (e.g. 'yocto' and 'yocto-docs') may lead to false positives.
    IFS=',' read -r -a registered_lists <<< "$registered_lists_string"
    for registered_list in "${registered_lists[@]}"; do
      [[ "$list" == "$registered_list" ]] && _lists_check_status["$index"]=1
    done

    ((index++))
  done
}
