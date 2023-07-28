include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

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
