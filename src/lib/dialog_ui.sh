# In this file, you will find the implementation of multiple abstract functions
# to build the interface between kw and lore. Notice that here we manage the
# dialog tool.

include "${KW_LIB_DIR}/kwlib.sh"

declare -gr KW_UPSTREAM_TITLE='kw upstream patches manager'

# Some UI returns the user-selected option, and this global variable is used
# for that.
declare -g menu_return_string

declare -g DEFAULT_WIDTH
declare -g DEFAULT_HEIGHT

# Basic setup UI
function ui_setup()
{
  local columns

  [[ "$TERM" == '' || "$TERM" == 'dumb' ]] && TPUTTERM=' -T xterm-256color'
  columns=$(eval tput"${TPUTTERM}" cols)
  lines=$(eval tput"${TPUTTERM}" lines)

  DEFAULT_WIDTH="$columns"
  DEFAULT_HEIGHT="$lines"
}

# This function is responsible for creating dialog menus.
#
# @menu_title: This is the menu title used on the top left of the dialog screen.
# @menu_message_box: The instruction text used for this menu.
# @_menu_list_string_array: An array reference containing all the strings to be used in the menu.
# @cancel_label: Cancel label. If not set, the default is 'Exit']
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# If everything works as expected, the user option is saved in the
# menu_return_string variable, and the return code is 0. Otherwise, an errno
# code is returned.
function create_menu_options()
{
  local menu_title="$1"
  local menu_message_box="$2"
  local -n _menu_list_string_array="$3"
  local cancel_label="$4"
  local height="$5"
  local width="$6"
  local max_elements_displayed_in_the_menu="$7"
  local no_index="$8"
  local index=1
  local cmd
  local ret

  if [[ "${#_menu_list_string_array[@]}" -eq 0 ]]; then
    return 22 # EINVAL
  fi

  flag=${flag:-'SILENT'}
  height="$DEFAULT_HEIGHT"
  width="$DEFAULT_WIDTH"
  cancel_label=${cancel_label:-'Exit'}
  max_elements_displayed_in_the_menu=${max_elements_displayed_in_the_menu:-'0'}
  back_title=${back_title:-$KW_UPSTREAM_TITLE}

  # Start to compose menu
  cmd="dialog --backtitle \$'${back_title}' --title '${menu_title}' --clear"

  # Change cancel label
  if [[ -n "$cancel_label" ]]; then
    cmd+=" --cancel-label '${cancel_label}'"
  fi

  cmd+=" --menu $\"${menu_message_box}\""

  # Set height, width, and max display itens
  cmd+=" '${height}' '${width}' '${max_elements_displayed_in_the_menu}'"

  for item in "${_menu_list_string_array[@]}"; do
    if [[ -n "$no_index" ]]; then
      cmd+=" $\"${item}\" ''"
      continue
    fi

    cmd+=" '${index}' $\"${item}\""
    ((index++))
  done

  exec 3>&1
  menu_return_string=$(cmd_manager "$flag" "$cmd" 2>&1 1>&3)
  ret="$?"
  exec 3>&-
  return "$ret"
}

# Create simple checklist without index
#
# @menu_title: This is the menu title used on the top left of the dialog screen.
# @menu_message_box: The instruction text used for this menu.
# @_menu_list_string_array: An array reference containing all the strings to be used in the menu.
# @cancel_label: Cancel label. If not set, the default is 'Exit']
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# If everything works as expected, the user option is saved in the
# menu_return_string variable, and the return code is 0. Otherwise, an errno
# code is returned.
function create_simple_checklist()
{
  local menu_title="$1"
  local menu_message_box="$2"
  local -n _menu_list_string_array="$3"
  local cancel_label="$4"
  local height="$5"
  local width="$6"
  local list_height="$7"
  local flag="$8"
  local cmd
  local ret

  flag=${flag:-'SILENT'}
  height="$DEFAULT_HEIGHT"
  width="$DEFAULT_WIDTH"
  list_height=${list_height:-'0'}
  cancel_label=${cancel_label:-'Exit'}
  back_title=${back_title:-$KW_UPSTREAM_TITLE}

  cmd="dialog --backtitle \$'${back_title}' --title '${menu_title}' --clear --colors"

  # Change cancel label
  if [[ -n "$cancel_label" ]]; then
    cmd+=" --cancel-label '${cancel_label}'"
  fi

  # Start to compose menu
  cmd+=" --checklist $\"${menu_message_box}\""

  # Set height, width, and max display itens
  cmd+=" '${height}' '${width}' '${list_height}'"

  for item in "${_menu_list_string_array[@]}"; do
    cmd+=" '${item}' '' 'off' "
  done

  exec 3>&1
  menu_return_string=$(cmd_manager "$flag" "$cmd" 2>&1 1>&3)
  ret="$?"
  exec 3>&-
  return "$ret"
}

# This function is responsible for handling the dialog exit.
#
# @exit_status: Exit code
function handle_exit()
{
  local exit_status="$1"

  # Handling stop
  case "$exit_status" in
    1 | 255) # Exit
      clear
      exit 0
      ;;
  esac
}

function prettify_string()
{
  local fixed_text="$1"
  local variable_to_concatenate="$2"

  printf '\Zb\Z6%s\Zn%s\\n' "$fixed_text" "$variable_to_concatenate"
}
