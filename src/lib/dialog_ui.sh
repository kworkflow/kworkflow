# In this file, you will find the implementation of multiple abstract functions
# to build the interface between kw and lore. Notice that here we manage the
# dialog tool.

include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"

declare -gr KW_PATCH_HUB_TITLE='kw patch-hub'

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
  DEFAULT_SMALL_WIDTH="$((columns / 2))"
  DEFAULT_SMALL_HEIGHT="$((lines / 3))"

  # Set sefault layout
  if [[ -n "$default_layout" ]]; then
    if [[ -f "${KW_ETC_DIR}/dialog_ui/${default_layout}" ]]; then
      DIALOG_LAYOUT="${KW_ETC_DIR}/dialog_ui/${default_layout}"
    fi
  fi
}

# Create menu with options that the user can select. This function is flexible enough
# to allow the menu to have from 2 to 4 buttons with custom labels, options displayed
# with or without indexes and to display just a range of options from the array passed
# as reference.
#
# @box_title: This is the menu title used on the top left of the dialog screen
# @message_box: The instruction text used for this menu
# @_list_of_options_array: An array reference with the options to be displayed
# @starting_index: Starting index of range of options to be displayed. If not set,
#   the default is 0.
# @ending_index: Ending index of range of options to be displayed. If not set, the
#   default is the size of `_list_of_options_array` minus 1 (last index of array).
# @extra_label: Extra label. If not set, the 'Extra' button won't be displayed
# @cancel_label: Cancel label. If not set, the default is 'Exit'
# @help_label: Help label. If not set, the 'Help' button won't be displayed
# @height: Menu height in lines size
# @width: Menu width in column size
# @no_index: Boolean to control display of index. If set, indexes won't be displayed
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# If everything works as expected, the user option is saved in the
# menu_return_string variable, and the return code is 0. Otherwise, an errno
# code is returned.
function create_menu_options()
{
  local box_title="$1"
  local message_box="$2"
  local -n _list_of_options_array="$3"
  local starting_index="$4"
  local ending_index="$5"
  local extra_label="$6"
  local cancel_label="$7"
  local help_label="$8"
  local height="$9"
  local width="${10}"
  local no_index="${11}"
  local flag="${12}"
  local option
  local cmd

  if [[ "${#_list_of_options_array[@]}" -eq 0 ]]; then
    return 22 # EINVAL
  fi

  flag=${flag:-'SILENT'}
  height=${height:-$DEFAULT_HEIGHT}
  width=${width:-$DEFAULT_WIDTH}
  cancel_label=${cancel_label:-'Exit'}
  starting_index=${starting_index:-0}
  ending_index=${ending_index:-$((${#_list_of_options_array[@]} - 1))}

  # Escape all single quotes to avoid breaking arguments
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")
  cancel_label=$(str_escape_single_quotes "$cancel_label")
  extra_label=$(str_escape_single_quotes "$extra_label")
  help_label=$(str_escape_single_quotes "$help_label")

  cmd=$(build_dialog_command_preamble "$box_title")
  # Change cancel label
  cmd+=" --cancel-label $'${cancel_label}'"
  # Add extra button
  if [[ -n "$extra_label" ]]; then
    cmd+=" --extra-button --extra-label $'${extra_label}'"
  fi
  # Add help button
  if [[ -n "$help_label" ]]; then
    cmd+=" --help-button --help-label $'${help_label}'"
  fi
  # Add Menu screen
  cmd+=" --menu $'${message_box}'"
  # Set height, width, and max display itens
  cmd+=" '${height}' '${width}' '0'"
  # Add each menu option with or without index
  for i in $(seq "$starting_index" "$ending_index"); do
    option=$(str_escape_single_quotes "${_list_of_options_array["$i"]}")
    if [[ -n "$no_index" ]]; then
      cmd+=" $'${option}' ''"
    else
      cmd+=" '${i}' $'${option}'"
    fi
  done

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  run_dialog_command "$cmd" "$flag"
}

# Create simple checklist without index
#
# @box_title: This is the menu title used on the top left of the dialog screen.
# @message_box: The instruction text used for this menu.
# @_menu_list_string_array: An array reference containing all the strings to be used in the menu.
# @_check_statuses: An array reference containing all the statuses of the checks (if they are on/off).
# @cancel_label: Cancel label. If not set, the default is 'Exit']
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# If everything works as expected, the user option is saved in the
# menu_return_string variable, and the return code is 0. Otherwise, an errno
# code is returned.
function create_simple_checklist()
{
  local box_title="$1"
  local message_box="$2"
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

  flag=${flag:-'SILENT'}
  height=${height:-$DEFAULT_HEIGHT}
  width=${width:-$DEFAULT_WIDTH}
  list_height=${list_height:-'0'}
  cancel_label=${cancel_label:-'Exit'}

  # Escape all single quotes to avoid breaking arguments
  box_title=$(str_escape_single_quotes "$box_title")
  cancel_label=$(str_escape_single_quotes "$cancel_label")
  message_box=$(str_escape_single_quotes "$message_box")

  cmd=$(build_dialog_command_preamble "$box_title")
  # Change cancel label
  cmd+=" --cancel-label $'${cancel_label}'"
  # Add extra button
  if [[ -n "$back_button_label" ]]; then
    cmd+=" --extra-button --extra-label 'Return'"
  fi
  # Add Checklist screen
  cmd+=" --checklist $'${message_box}'"
  # Set height, width, and max display itens
  cmd+=" '${height}' '${width}' '${list_height}'"
  # Add each checklist item with their respective starting check status
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

  run_dialog_command "$cmd" "$flag"
}

# Create simple loading screen notification for delayed actions.
#
# @loading_message: The message to be displayed to the user while loading.
# @height: Menu height in lines size, the default value is 8.
# @width: Menu width in column size, the default value is 60.
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# There is no return. The function just displays the infobox and returns,
# assuming the next command is going to delay its completion and that another
# screen is going to clear the current (the infobox).
function create_loading_screen_notification()
{
  local loading_message="$1"
  local height="$2"
  local width="$3"
  local flag="$4"
  local cmd

  flag=${flag:-'SILENT'}
  height=${height:-'8'}
  width=${width:-'60'}

  # Escape all single quotes to avoid breaking arguments
  loading_message=$(str_escape_single_quotes "$loading_message")

  # Add dialog layout if there is one
  if [[ -n "$DIALOG_LAYOUT" ]]; then
    cmd="DIALOGRC=${DIALOG_LAYOUT} "
  fi
  # We should not use --clear because this flushes the infobox
  cmd+='dialog --colors'
  # Add Infobox screen
  # TODO: if possible, we should try using a progress bar/gauge
  cmd+=" --infobox $'${loading_message}'"
  # Set height and width
  cmd+=" '${height}' '${width}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  run_dialog_command "$cmd" "$flag"
}

# Get the current spinner frame.
#
# @frame_offset: Offset corresponding to the current frame on the spin string.
#
# Return:
# A frame of the spinner animation in string format.
function spin_frame()
{
  local LC_CTYPE=C
  local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
  local char_width=3
  local frame_offset="$1"

  frame_offset=$(((frame_offset) % ${#spin}))
  printf "%s" "${spin:$frame_offset:$char_width}"
}

# Create simple async loading screen notification for delayed actions.
#
# The caller is required to use stop_async_loading_screen_notification() with the pid of this function call
# afterwards to stop the loading screen.
#
# @loading_message: The message to be displayed to the user while loading.
# @height: Menu height in lines size, the default value is 8.
# @width: Menu width in column size, the default value is 60.
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
function create_async_loading_screen_notification()
{
  local loading_message="$1"
  local height="$2"
  local width="$3"
  local flag="$4"
  local cmd
  local frame_offset

  frame_offset=0
  flag=${flag:-'SILENT'}
  height=${height:-8}
  width=${width:-60}

  # Escape all single quotes to avoid breaking arguments
  loading_message=$(str_escape_single_quotes "$loading_message")

  while true; do
    # Add dialog layout if there is one
    if [[ -n "$DIALOG_LAYOUT" ]]; then
      cmd="DIALOGRC=${DIALOG_LAYOUT} "
    fi
    # We should not use --clear because this flushes the infobox
    cmd+='dialog --colors'
    spin="$(spin_frame $frame_offset)"
    frame_offset=$((frame_offset + 3))

    # Add Infobox screen
    cmd+=" --infobox $'${loading_message} ${spin}'"
    # Set height and width
    cmd+=" '${height}' '${width}'"

    [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

    run_dialog_command "$cmd" "$flag"
    sleep .1
  done
}

# Kill async loading process
#
# @loading_pid: PID of the async loading process
function stop_async_loading_screen_notification()
{
  local loading_pid="$1"

  kill -15 "$loading_pid"
}

# Create simple message box. Can be used for displaying errors and notifications.
#
# @box_title: Title of the box
# @message_box: The message to be displayed.
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
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

  flag=${flag:-'SILENT'}
  height=${height:-'15'}
  width=${width:-'40'}

  # Escape all single quotes to avoid breaking arguments
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")

  cmd=$(build_dialog_command_preamble "$box_title")
  # Add Message Box screen
  cmd+=" --msgbox $'${message_box}'"
  # Set height and width
  cmd+=" '${height}' '${width}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  run_dialog_command "$cmd" "$flag"
}

# Create directory selection screen.
#
# @starting_path: Path that is in the input box when screen starts
# @box_title: Title of the box
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
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

  flag=${flag:-'SILENT'}
  height=${height:-'15'}
  width=${width:-'80'}

  # Escape all single quotes to avoid breaking arguments
  box_title=$(str_escape_single_quotes "$box_title")

  cmd=$(build_dialog_command_preamble "$box_title")
  # Add help button
  cmd+=" --help-button"
  # Add directory selection screen
  cmd+=" --dselect '${starting_path}'"
  # Set height and width
  cmd+=" '${height}' '${width}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  run_dialog_command "$cmd" "$flag"
}

# Create file selection screen.
#
# @starting_path: Path that is in the input box when screen starts
# @box_title: Title of the box
# @extra_label: Label to override 'Extra' button. If empty, 'Extra' button
#   is not displayed.
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# Returns 0 if the 'OK' button is pressed, 1 if the 'Cancel' button is pressed
# and 2 if the 'Help' button is pressed. The string in the input box (current
# path) is returned via the `menu_return_string` variable.
function create_file_selection_screen()
{
  local starting_path="$1"
  local box_title="$2"
  local extra_label="$3"
  local height="$4"
  local width="$5"
  local flag="$6"
  local cmd

  flag=${flag:-'SILENT'}
  height=${height:-'15'}
  width=${width:-'80'}

  # Escape all single quotes to avoid breaking arguments
  box_title=$(str_escape_single_quotes "$box_title")
  extra_label=$(str_escape_single_quotes "$extra_label")

  cmd=$(build_dialog_command_preamble "$box_title")
  # Add help button
  cmd+=" --help-button"
  # Add extra button, if needed
  if [[ -n "$extra_label" ]]; then
    cmd+=" --extra-button --extra-label $'${extra_label}'"
  fi
  # Add file selection screen
  cmd+=" --fselect '${starting_path}'"
  # Set height and width
  cmd+=" '${height}' '${width}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  run_dialog_command "$cmd" "$flag"
}

# Create a screen with a list of choices. This function supports both choices with descriptions
# and without description. The first behaviour happens by passing an associative array as
# `_choices`, but, as associative arrays in bash are hashed, the order of display may not be the
# order of definition. The second behaviour happens by passing an indexed array as `_choices` and,
# in this case, the order of definition of the elements is the same as the displayed one.
#
# @box_title: Title of the box
# @message_box: The message to be displayed
# @_choices: Reference to an associative array with `<choice><choice_description>`
#   pairs to be displayed, or to an indexed array with a list of choices.
# @_check_statuses: An array reference containing all the statuses of the checks
#   (if they are on/off).
# @ok_label: Override the default 'Ok' button label option (Default is 'Yes').
# @cancel_label: Override the default 'Cancel' button label option (Default is 'Cancel')
# @extra_label: Label for the 'Extra' button
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
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
  local ok_label="$5"
  local cancel_label="$6"
  local extra_button_label="$7"
  local height="$8"
  local width="$9"
  local flag="${10}"
  local choice_description
  local index=0
  local cmd

  flag=${flag:-'SILENT'}
  height=${height:-$DEFAULT_HEIGHT}
  width=${width:-$DEFAULT_WIDTH}
  cancel_label=${cancel_label:-'Cancel'}
  ok_label=${ok_label:-'Ok'}

  # Escape all single quotes to avoid breaking arguments
  ok_label=$(str_escape_single_quotes "$ok_label")
  cancel_label=$(str_escape_single_quotes "$cancel_label")
  extra_button_label=$(str_escape_single_quotes "$extra_button_label")
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")

  cmd=$(build_dialog_command_preamble "$box_title")
  # Override OK, cancel, and add extra button if necessary.
  cmd+=" --ok-label $'${ok_label}'"
  cmd+=" --cancel-label $'${cancel_label}'"
  if [[ -n "$extra_button_label" ]]; then
    cmd+=" --extra-button --extra-label $'${extra_button_label}'"
  fi

  # Add radiolist screen
  cmd+=" --radiolist $'${message_box}'"
  # Set height and width
  cmd+=" '${height}' '${width}' '0'"
  # Add choices without description if `_choices` is an indexed array
  if [[ "$(typeset -p "$3")" =~ 'declare -a' ]]; then
    for choice in "${_choices[@]}"; do
      choice=$(str_escape_single_quotes "$choice")
      if [[ "${_check_statuses["$index"]}" == 1 ]]; then
        cmd+=" $'${choice}' '' 'on'"
      else
        cmd+=" $'${choice}' '' 'off'"
      fi
      ((index++))
    done
  # Add choices with description if `_choices` is an associative array
  else
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
  fi

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  run_dialog_command "$cmd" "$flag"
}

# Create a screen with a Yes/No prompt.
#
# @box_title: Title of the box
# @message_box: The message to be displayed
# @ok_label: Label for the 'Yes' button
# @no_label: Label for the 'No' button
# @extra_label: Label for the 'Extra' button
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# Returns 0 if the 'Yes' button is pressed, 1 if the 'No' button is pressed and
# 3 if the 'Extra' button is pressed.
function create_yes_no_prompt()
{
  local box_title="$1"
  local message_box="$2"
  local yes_label="$3"
  local no_label="$4"
  local extra_label="$5"
  local height="$6"
  local width="$7"
  local flag="$8"
  local cmd

  yes_label=${yes_label:-'Yes'}
  no_label=${no_label:-'No'}
  flag=${flag:-'SILENT'}
  height=${height:-'15'}
  width=${width:-'40'}

  # Escape all single quotes to avoid breaking arguments
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")
  yes_label=$(str_escape_single_quotes "$yes_label")
  no_label=$(str_escape_single_quotes "$no_label")
  extra_label=$(str_escape_single_quotes "$extra_label")

  cmd=$(build_dialog_command_preamble "$box_title")
  # Add labels
  cmd+=" --yes-label $'${yes_label}' --no-label $'${no_label}'"
  if [[ -n "${extra_label}" ]]; then
    cmd+=" --extra-button --extra-label $'${extra_label}'"
  fi
  # Add Yes/No screen
  cmd+=" --yesno $'${message_box}'"
  # Set height and width
  cmd+=" '${height}' '${width}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  run_dialog_command "$cmd" "$flag"
}

# Create form screen.
#
# @box_title: Title of the box
# @message_box: The message to be displayed
# @_fields_list: Array of labels
# @ok_label: Label for the traditional Ok button. By default, it is 'Ok'
# @cancel_label: Label for the traditional Cancel button. By default, it is 'Cancel'
# @extra_label: If this option label is set, one extra button is added
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Returns 0 if the 'Ok' button is pressed, 1 if the 'Cancel' button is pressed
# and 3 if the 'Extra' button is pressed. The menu_return_string will have all
# the user input.
function create_form_screen()
{
  local box_title="$1"
  local message_box="$2"
  local -n _fields_list="$3"
  local ok_label="$4"
  local cancel_label="$5"
  local extra_label="$6"
  local height="$7"
  local width="$8"
  local flag="$9"
  local auxiliar_label_size=0
  local start_text_field=0
  local row=1
  local choice_description
  local cmd

  height=${height:-"${DEFAULT_HEIGHT}"}
  width=${width:-"${DEFAULT_WIDTH}"}
  cancel_label=${cancel_label:-'Cancel'}
  ok_label=${ok_label:-'Ok'}
  flag=${flag:-'SILENT'}

  # Escape all single quotes to avoid breaking arguments
  ok_label=$(str_escape_single_quotes "$ok_label")
  cancel_label=$(str_escape_single_quotes "$cancel_label")
  extra_label=$(str_escape_single_quotes "$extra_label")
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")

  cmd=$(build_dialog_command_preamble "$box_title")
  # Override OK and cancel labels
  cmd+=" --ok-label $'${ok_label}'"
  cmd+=" --cancel-label $'${cancel_label}'"
  # Add extra button
  if [[ -n "$extra_label" ]]; then
    cmd+=" --extra-button --extra-label ${extra_label}"
  fi
  # Add form option
  cmd+=" --form $'${message_box}'"
  # Set height and width
  cmd+=" '${height}' '${width}' '0'"

  # Find out the largest label to know where we need to start the input field
  for field in "${_fields_list[@]}"; do
    auxiliar_label_size=$(str_length "$field")
    if [[ "${auxiliar_label_size}" -gt "${start_text_field}" ]]; then
      start_text_field="${auxiliar_label_size}"
    fi
  done

  # Add two extra spaces to the start point
  start_text_field=$((start_text_field + 2))

  # Add form fields
  for label in "${_fields_list[@]}"; do
    label=$(str_escape_single_quotes "$label")
    cmd+=" $'${label}:' $'${row}' 1 $'' $'${row}' $'${start_text_field}' 10 0"
    ((row++))
  done

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  run_dialog_command "$cmd" "$flag"
}

# Create a rangebox to collect an integer from the user. This rangebox can be
# used to guaranteedly an integer from a restricted range.
#
# @box_title: Title of the box
# @message_box: The message to be displayed
# @min_value: Minimum value of the range
# @max_value: Maximum value of the range
# @default_value: Starting value of the rangebox
# @extra_label: Extra label. If not set, the 'Extra' button won't be displayed
# @cancel_label: Cancel label. If not set, the default is 'Exit'
# @help_label: Help label. If not set, the 'Help' button won't be displayed
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# Returns 0 if the 'Ok' button is pressed, 1 if the 'Cancel' button is pressed,
# 2 if the 'Help' button is pressed, and 3 if the 'Extra' button is pressed.
# The menu_return_string will store the user selected value.
function create_rangebox_screen()
{
  local box_title="$1"
  local message_box="$2"
  local min_value="$3"
  local max_value="$4"
  local default_value="$5"
  local extra_label="$6"
  local cancel_label="$7"
  local help_label="$8"
  local height="$9"
  local width="${10}"
  local flag="${11}"
  local cmd

  min_value=${min_value:-'0'}
  max_value=${max_value:-'100'}
  default_value=${default_value:-$(((min_value + max_value) / 2))}
  cancel_label=${cancel_label:-'Exit'}
  flag=${flag:-'SILENT'}
  height=${height:-'10'}
  width=${width:-'60'}

  # Escape all single quotes to avoid breaking arguments
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")
  cancel_label=$(str_escape_single_quotes "$cancel_label")
  help_label=$(str_escape_single_quotes "$help_label")
  extra_label=$(str_escape_single_quotes "$extra_label")

  cmd=$(build_dialog_command_preamble "$box_title")
  # Override 'Cancel' button label
  cmd+=" --cancel-label $'${cancel_label}'"
  # Add 'Extra' button
  if [[ -n "${extra_label}" ]]; then
    cmd+=" --extra-button --extra-label $'${extra_label}'"
  fi
  # Add 'Help' button
  if [[ -n "${help_label}" ]]; then
    cmd+=" --help-button --help-label $'${help_label}'"
  fi
  # Add Rangebox screen
  cmd+=" --rangebox $'${message_box}'"
  # Set height and width
  cmd+=" '${height}' '${width}'"
  # Set range and default value
  cmd+=" '${min_value}' '${max_value}' '${default_value}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  run_dialog_command "$cmd" "$flag"
}

# Create an Inputbox to collect a string from the user. The string typed in the
# Inputbox is returned in the variable `menu_return_string` if the user hits either
# the 'Ok' button or the 'Extra' button. An empty string is also a valid input.
#
# @box_title: Title of the box
# @message_box: The message to be displayed
# @extra_label: Extra label. If not set, the 'Extra' button won't be displayed
# @cancel_label: Cancel label. If not set, the default is 'Exit'
# @help_label: Help label. If not set, the 'Help' button won't be displayed
# @height: Menu height in lines size
# @width: Menu width in column size
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# Returns 0 if the 'Ok' button is pressed, 1 if the 'Cancel' button is pressed,
# 2 if the 'Help' button is pressed, and 3 if the 'Extra' button is pressed.
# The `menu_return_string` will store the string in the Inputbox if the user hits
# either the 'Ok' button or the 'Extra' button. An empty string is also a valid
# input.
function create_inputbox_screen()
{
  local box_title="$1"
  local message_box="$2"
  local extra_label="$3"
  local cancel_label="$4"
  local help_label="$5"
  local height="$6"
  local width="$7"
  local flag="$8"
  local cmd

  cancel_label=${cancel_label:-'Exit'}
  flag=${flag:-'SILENT'}
  height=${height:-$DEFAULT_SMALL_HEIGHT}
  width=${width:-$DEFAULT_SMALL_WIDTH}

  # Escape all single quotes to avoid breaking arguments
  box_title=$(str_escape_single_quotes "$box_title")
  message_box=$(str_escape_single_quotes "$message_box")
  cancel_label=$(str_escape_single_quotes "$cancel_label")
  extra_label=$(str_escape_single_quotes "$extra_label")
  help_label=$(str_escape_single_quotes "$help_label")

  cmd=$(build_dialog_command_preamble "$box_title")
  # Override 'Cancel' button label
  cmd+=" --cancel-label $'${cancel_label}'"
  # Add 'Extra' button
  if [[ -n "${extra_label}" ]]; then
    cmd+=" --extra-button --extra-label $'${extra_label}'"
  fi
  # Add 'Help' button
  if [[ -n "${help_label}" ]]; then
    cmd+=" --help-button --help-label $'${help_label}'"
  fi
  # Add Inputbox screen
  cmd+=" --inputbox $'${message_box}'"
  # Set height and width
  cmd+=" '${height}' '${width}'"

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s' "$cmd" && return 0

  run_dialog_command "$cmd" "$flag"
}

# Creates a help message box for a dialog's screen. There must be a file
# that follows the pattern of `load_module_text`, for reference see `src/lib/kwio.sh`.
#
# @screen_name: Name of screen to show the help. There must be a text file
#   `${KW_ETC_DIR}/dialog_help/${screen_name}_help.txt` that holds the help message
#   (in the proper format) to be displayed.
# @flag: How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
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

# This function outputs the preamble of most dialog command. This preamble consists
# of the configuration of a dialog layout, in case there is one, and the dialog box
# back title and title.
#
# @title: Main title of dialog box.
# @back_title: Back title of dialog box. If null, use `KW_PATCH_HUB_TITLE` as the
#   default back title.
function build_dialog_command_preamble()
{
  local title="$1"
  local back_title="$2"
  local cmd

  # Add layout (if existent) to command.
  if [[ -n "$DIALOG_LAYOUT" ]]; then
    cmd="DIALOGRC=${DIALOG_LAYOUT}"
  fi

  # Define `back_title` value and escape single quotes for safety
  back_title=${back_title:-$KW_PATCH_HUB_TITLE}
  back_title=$(str_escape_single_quotes "$back_title")

  # Add dialog box back title and title to command.
  cmd+=" dialog --backtitle $'${back_title}' --title $'${title}' --clear --colors"

  printf '%s' "$cmd"
}

# This function runs a dialog command. It does the file descriptor manipulation
# needed for the command to work. It also stores the string returned by the user
# interaction with the dialog screen in `menu_return_string` and returns the
# exit code, both really important values to determine actions after the command
# is run.
#
# @dialog_cmd: String containing a dialog command ready for run
# @flag: How to display a command, the default value is "SILENT". For more options
#   see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# The return value depends on the dialog command being run. Check the specific
# dialog screen function for more details.
# TODO: Is there a way to test this function?
function run_dialog_command()
{
  local dialog_cmd="$1"
  local flag="$2"
  local ret

  flag=${flag:-'SILENT'}

  exec 3>&1
  menu_return_string=$(cmd_manager "$flag" "$dialog_cmd" 2>&1 1>&3)
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
