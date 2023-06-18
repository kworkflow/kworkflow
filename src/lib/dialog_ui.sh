# In this file, you will find the implementation of multiple abstract functions
# to build the interface between kw and lore. Notice that here we manage the
# dialog tool.

include "${KW_LIB_DIR}/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"

declare -gr KW_UPSTREAM_TITLE='kw upstream patches manager'

# Some UI returns the user-selected option, and this global variable is used
# for that.
declare -g menu_return_string

declare -g DEFAULT_WIDTH
declare -g DEFAULT_HEIGHT
declare -g DIALOG_LAYOUT

# Basic setup UI
function ui_setup()
{
  local default_layout="$1"
  local columns

  [[ "$TERM" == '' || "$TERM" == 'dumb' ]] && TPUTTERM=' -T xterm-256color'
  columns=$(eval tput"${TPUTTERM}" cols)
  lines=$(eval tput"${TPUTTERM}" lines)

  DEFAULT_WIDTH="$columns"
  DEFAULT_HEIGHT="$lines"

  # Set sefault layout
  if [[ -n "$default_layout" ]]; then
    if [[ -f "${KW_ETC_DIR}/dialog_ui/${default_layout}" ]]; then
      DIALOG_LAYOUT="${KW_ETC_DIR}/dialog_ui/${default_layout}"
    fi
  fi
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
  local back_button_label="$4"
  local cancel_label="$5"
  local height="$6"
  local width="$7"
  local max_elements_displayed_in_the_menu="$8"
  local no_index="$9"
  local flag="${10}"
  local index=1
  local cmd
  local ret

  if [[ "${#_menu_list_string_array[@]}" -eq 0 ]]; then
    return 22 # EINVAL
  fi

  flag=${flag:-'SILENT'}
  height=${height:-$DEFAULT_HEIGHT}
  width=${width:-$DEFAULT_WIDTH}
  cancel_label=${cancel_label:-'Exit'}
  max_elements_displayed_in_the_menu=${max_elements_displayed_in_the_menu:-'0'}
  back_title=${back_title:-$KW_UPSTREAM_TITLE}

  # Escape all single quotes to avoid breaking arguments
  back_title=$(str_escape_single_quotes "$back_title")
  menu_title=$(str_escape_single_quotes "$menu_title")
  cancel_label=$(str_escape_single_quotes "$cancel_label")
  menu_message_box=$(str_escape_single_quotes "$menu_message_box")

  # Start to compose menu
  if [[ -n "$DIALOG_LAYOUT" ]]; then
    cmd="DIALOGRC=${DIALOG_LAYOUT} "
  fi

  cmd+="dialog --backtitle $'${back_title}' --title $'${menu_title}' --clear --colors"

  # Change cancel label
  cmd+=" --cancel-label $'${cancel_label}'"

  # Add extra button?
  if [[ -n "$back_button_label" ]]; then
    cmd+=" --extra-button --extra-label 'Return'"
  fi

  # Menu option
  cmd+=" --menu $'${menu_message_box}'"

  # Set height, width, and max display itens
  cmd+=" '${height}' '${width}' '${max_elements_displayed_in_the_menu}'"

  for item in "${_menu_list_string_array[@]}"; do
    item=$(str_escape_single_quotes "$item")

    if [[ -n "$no_index" ]]; then
      cmd+=" $'${item}' ''"
      continue
    fi

    cmd+=" '${index}' $'${item}'"
    ((index++))
  done

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

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
# @_check_statuses: An array reference containing all the statuses of the checks (if they are on/off).
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
  local -n _check_statuses="$4"
  local back_button_label="$5"
  local cancel_label="$6"
  local height="$7"
  local width="$8"
  local list_height="$9"
  local flag="${10}"
  local index=0
  local cmd
  local ret

  flag=${flag:-'SILENT'}
  height=${height:-$DEFAULT_HEIGHT}
  width=${width:-$DEFAULT_WIDTH}
  list_height=${list_height:-'0'}
  cancel_label=${cancel_label:-'Exit'}
  back_title=${back_title:-$KW_UPSTREAM_TITLE}

  # Escape all single quotes to avoid breaking arguments
  back_title=$(str_escape_single_quotes "$back_title")
  menu_title=$(str_escape_single_quotes "$menu_title")
  cancel_label=$(str_escape_single_quotes "$cancel_label")
  menu_message_box=$(str_escape_single_quotes "$menu_message_box")

  # Start to compose menu
  if [[ -n "$DIALOG_LAYOUT" ]]; then
    cmd="DIALOGRC=${DIALOG_LAYOUT} "
  fi

  cmd+="dialog --backtitle $'${back_title}' --title $'${menu_title}' --clear --colors"

  # Change cancel label
  cmd+=" --cancel-label $'${cancel_label}'"

  # Add extra button?
  if [[ -n "$back_button_label" ]]; then
    cmd+=" --extra-button --extra-label 'Return'"
  fi

  # Start to compose menu
  cmd+=" --checklist $'${menu_message_box}'"

  # Set height, width, and max display itens
  cmd+=" '${height}' '${width}' '${list_height}'"

  for item in "${_menu_list_string_array[@]}"; do
    item=$(str_escape_single_quotes "$item")
    if [[ "${_check_statuses["$index"]}" == 1 ]]; then
      cmd+=" $'${item}' '' 'on'"
    else
      cmd+=" $'${item}' '' 'off'"
    fi
    ((index++))
  done

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  exec 3>&1
  menu_return_string=$(cmd_manager "$flag" "$cmd" 2>&1 1>&3)
  ret="$?"
  exec 3>&-
  return "$ret"
}

# Create simple loading screen notification for delayed actions.
#
# @loading_message: The message to be displayed to the user while loading.
# @height: Menu height in lines size, the default value is 8.
# @width: Menu width in column size, the default value is 60.
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# There is no return. The function just displays the infobox and returns,
# assuming the next command is going to delay its completionand that another
# screen is going to clear the current (the infobox).
function create_loading_screen_notification()
{
  local loading_message="$1"
  local height="$2"
  local width="$3"
  local flag="$4"
  local cmd
  local ret

  flag=${flag:-'SILENT'}
  height=${height:-'8'}
  width=${width:-'60'}
  back_title=${back_title:-$"$KW_UPSTREAM_TITLE"}

  # Add dialog layout if there is one
  if [[ -n "$DIALOG_LAYOUT" ]]; then
    cmd="DIALOGRC=${DIALOG_LAYOUT} "
  fi

  # We should not use --clear because this flushes the infobox
  cmd+='dialog --colors'

  # Start infobox
  # TODO: if possible, we should try using a progress bar/gauge
  # Escape all single quotes to avoid breaking arguments
  loading_message=$(str_escape_single_quotes "$loading_message")
  cmd+=" --infobox $'${loading_message}'"

  # Set height and width
  cmd+=" '${height}' '${width}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  exec 3>&1
  # dialog --infobox does not return a menu_return_string
  cmd_manager "$flag" "$cmd" 2>&1 1>&3
  ret="$?"
  exec 3>&-
  return "$ret"
}

# Create simple message box. Can be used for displaying errors and notifications.
#
# @box_title: Title of the box
# @message_box: The message to be displayed.
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Unlike other dialog screens, this one doesn't return a menu_return_string,
# just the status code of the command which should be 0, if everything worked
# as expected.
function create_message_box()
{
  local box_title="$1"
  local message_box="$2"
  local height="$3"
  local width="$4"
  local flag="$5"
  local cmd
  local ret

  flag=${flag:-'SILENT'}
  height=${height:-'15'}
  width=${width:-'40'}
  back_title=${back_title:-"${KW_UPSTREAM_TITLE}"}

  # Escape all single quotes to avoid breaking arguments
  back_title=$(str_escape_single_quotes "$back_title")
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")

  # Add layout to dialog
  if [[ -n "$DIALOG_LAYOUT" ]]; then
    cmd="DIALOGRC=${DIALOG_LAYOUT}"
  fi

  cmd+=" dialog --backtitle $'${back_title}' --title $'${box_title}' --clear --colors"

  cmd+=" --msgbox $'${message_box}'"

  # Set height and width
  cmd+=" '${height}' '${width}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  exec 3>&1
  cmd_manager "$flag" "$cmd" 2>&1 1>&3
  ret="$?"
  exec 3>&-
  return "$ret"
}

# This option creates the yes/no screen. Note from the parameters that this
# function is highly configurable, allowing you to change the button names and
# add extra buttons. This flexibility, for example, can help create an
# installation screen with "Next" and "Previous" buttons.
#
# @box_title: Title of the box
# @message_box: The message to be displayed
# @height: Menu height in lines size
# @width: Menu width in column size
# @yes_label: If not set, this function assumes 'Yes' as a label
# @no_label: If not set, this function assumes 'No' as a label
# @extra_button: Allow user to have one extra button (e.g., Exit)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Unlike other dialog screens, this one doesn't return a menu_return_string,
# just the status code of the command which should be 0, if everything worked
# as expected.
function create_yes_no_message()
{
  local box_title="$1"
  local message_box="$2"
  local height="$3"
  local width="$4"
  local yes_label="$5"
  local no_label="$6"
  local extra_button="$7"
  local flag="$8"
  local cmd
  local ret

  flag=${flag:-'SILENT'}
  height=${height:-'15'}
  width=${width:-'40'}
  back_title=${back_title:-"${KW_UPSTREAM_TITLE}"}
  yes_label=${yes_label:-'Yes'}
  no_label=${no_label:-'No'}
  extra_button=${extra_button:-''}

  # Escape all single quotes to avoid breaking arguments
  back_title=$(str_escape_single_quotes "$back_title")
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")

  # Add layout to dialog
  if [[ -n "$DIALOG_LAYOUT" ]]; then
    cmd="DIALOGRC=${DIALOG_LAYOUT}"
  fi

  cmd+=" dialog --backtitle $'${back_title}' --title $'${box_title}' --clear --colors"
  cmd+=" --yes-label $'${yes_label}' --no-label $'${no_label}'"

  if [[ -n "$extra_button" ]]; then
    cmd+=" --extra-label $'${extra_button}'"
  fi

  cmd+=" --yesno $'${message_box}'"

  # Set height and width
  cmd+=" '${height}' '${width}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  exec 3>&1
  cmd_manager "$flag" "$cmd" 2>&1 1>&3
  ret="$?"
  exec 3>&-
  return "$ret"
}

# Create directory selection screen.
#
# @starting_path: Path that is in the input box when screen starts
# @box_title: Title of the box
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Returns 0 if the 'OK' button is pressed, 1 if the 'Cancel' button is pressed
# and 2 if the 'Help' button is pressed. The string in the input box (current
# path) is returned via the `menu_return_string` variable.
function create_directory_selection_screen()
{
  local starting_path="$1"
  local box_title="$2"
  local height="$3"
  local width="$4"
  local flag="$5"
  local cmd
  local ret

  flag=${flag:-'SILENT'}
  height=${height:-'15'}
  width=${width:-'80'}
  back_title=${back_title:-"${KW_UPSTREAM_TITLE}"}

  # Escape all single quotes to avoid breaking arguments
  back_title=$(str_escape_single_quotes "$back_title")
  box_title=$(str_escape_single_quotes "$box_title")

  # Add layout to dialog
  if [[ -n "$DIALOG_LAYOUT" ]]; then
    cmd="DIALOGRC=${DIALOG_LAYOUT}"
  fi

  # Add general information to the dialog box
  cmd+=" dialog --backtitle $'${back_title}' --title $'${box_title}' --clear --colors"
  # Add help button
  cmd+=" --help-button"
  # Add directory selection screen
  cmd+=" --dselect '${starting_path}'"
  # Set height and width
  cmd+=" '${height}' '${width}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  exec 3>&1
  menu_return_string=$(cmd_manager "$flag" "$cmd" 2>&1 1>&3)
  ret="$?"
  exec 3>&-
  return "$ret"
}

# Create a screen with a list of choices.
#
# @box_title: Title of the box
# @message_box: The message to be displayed
# @_choices: Associative array reference containing all the
#   `<choice><choice_description>` pairs to be displayd
# @_check_statuses: An array reference containing all the statuses of the checks
#   (if they are on/off).
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Returns 0 if the 'OK' button is pressed and 1 if the 'Cancel' button is pressed.
# The key of the chosen pair (i.e. the `<choice>`) is returned via the
# `menu_return_string` variable.
function create_choice_list_screen()
{
  local box_title="$1"
  local message_box="$2"
  local -n _choices="$3"
  local -n _check_statuses="$4"
  local height="$5"
  local width="$6"
  local flag="$7"
  local choice_description
  local index=0
  local cmd
  local ret

  flag=${flag:-'SILENT'}
  height=${height:-$DEFAULT_HEIGHT}
  width=${width:-$DEFAULT_WIDTH}
  back_title=${back_title:-"${KW_UPSTREAM_TITLE}"}

  # Escape all single quotes to avoid breaking arguments
  back_title=$(str_escape_single_quotes "$back_title")
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")

  # Add layout to dialog
  if [[ -n "$DIALOG_LAYOUT" ]]; then
    cmd="DIALOGRC=${DIALOG_LAYOUT}"
  fi

  # Add general information to the dialog box
  cmd+=" dialog --backtitle $'${back_title}' --title $'${box_title}' --clear --colors"
  # Add radiolist screen
  cmd+=" --radiolist $'${message_box}'"
  # Set height and width
  cmd+=" '${height}' '${width}' '0'"
  # Add choices (${choices["${choice}"]} refers to the choice's description)
  for choice in "${!_choices[@]}"; do
    choice_description=$(str_escape_single_quotes "${_choices["${choice}"]}")
    choice=$(str_escape_single_quotes "$choice")
    if [[ "${_check_statuses["$index"]}" == 1 ]]; then
      cmd+=" $'${choice}' $'${choice_description}' 'on'"
    else
      cmd+=" $'${choice}' $'${choice_description}' 'off'"
    fi
    ((index++))
  done

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  exec 3>&1
  menu_return_string=$(cmd_manager "$flag" "$cmd" 2>&1 1>&3)
  ret="$?"
  exec 3>&-
  return "$ret"
}

function create_form_screen()
{
  local box_title="$1"
  local message_box="$2"
  local back_title="$3"
  local -n _fields_list="$4"
  local ok_label="$5"
  local cancel_label="$6"
  local extra_label="$7"
  local height="$8"
  local width="$9"
  local flag="${10}"
  local choice_description
  local index=0
  local cmd
  local ret
  local start_text_field=0
  local auxiliar_label_size=0
  local row=1

  flag=${flag:-'SILENT'}
  height=${height:-$DEFAULT_HEIGHT}
  width=${width:-$DEFAULT_WIDTH}
  back_title=${back_title:-"${KW_UPSTREAM_TITLE}"}
  ok_label=${ok_label:-"$ok_label"}
  cancel_label=${cancel_label:-"$cancel_label"}
  extra_label=${extra_label:-"$extra_label"}

  # Escape all single quotes to avoid breaking arguments
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")

  # Add layout to dialog
  if [[ -n "$DIALOG_LAYOUT" ]]; then
    cmd="DIALOGRC=${DIALOG_LAYOUT}"
  fi

  # Add general information to the dialog box
  cmd+=" dialog --backtitle $'${back_title}' --title $'${box_title}' --clear --colors"
  # Set height and width

  # Find out the largest label to know where we need to start the field
  for field in "${_fields_list[@]}"; do
    auxiliar_label_size=$(str_length "$field")
    if [[ "${auxiliar_label_size}" -gt "${start_text_field}" ]]; then
      start_text_field="${auxiliar_label_size}"
    fi
  done
  # Add two extra spaces to the start point
  start_text_field=$(( start_text_field + 2 ))

  # Creating form line
  cmd+=" --form $'${message_box}'"

  cmd+=" '${height}' '${width}' '0'"

  for label in "${_fields_list[@]}"; do
    cmd+=" $'${label}:' $'${row}' 1 $'' $'${row}' $'${start_text_field}' 10 0"
    (( row++ ))
  done

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  exec 3>&1
  menu_return_string=$(cmd_manager "$flag" "$cmd" 2>&1 1>&3)
  ret="$?"
  exec 3>&-
  return "$ret"
}

# Creates a help message box for a dialog's screen. There must be a file
# that follows the pattern of `load_module_text`, for reference see `src/kwio.sh`.
#
# @screen_name: Name of screen to show the help. There must be a text file
#   `${KW_ETC_DIR}/dialog_help/${screen_name}_help.txt` that holds the help message
#   (in the proper format) to be displayed.
# @flag: How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Returns 2 (ENOENT) if there is no text file relative to @screen_name and 0, otherwise.
function create_help_screen()
{
  local screen_name="$1"
  local flag="$2"
  local box_title
  local message_box

  flag=${flag:-'SILENT'}

  if [[ ! -f "${KW_ETC_DIR}/dialog_help/${screen_name}_help.txt" ]]; then
    return 2 # ENOENT
  fi

  load_module_text "${KW_ETC_DIR}/dialog_help/${screen_name}_help.txt"
  box_title="${module_text_dictionary["${screen_name}_help_box_title"]}"
  message_box="${module_text_dictionary["${screen_name}_help_message_box"]}"

  create_message_box "$box_title" "$message_box" '15' '70' "$flag"
}

# This function is responsible for handling the dialog exit.
#
# @exit_status: Exit code
function handle_exit()
{
  local exit_status="$1"

  # Handling stop
  case "$exit_status" in
    1 | 22 | 255) # Exit
      clear
      exit 0
      ;;
  esac
}

function prettify_string()
{
  local fixed_text="$1"
  local variable_to_concatenate="$2"

  if [[ -z "$fixed_text" || -z "$variable_to_concatenate" ]]; then
    return 22
  fi

  printf '\Zb\Z6%s\Zn%s\\n' "$fixed_text" "$variable_to_concatenate"
}
