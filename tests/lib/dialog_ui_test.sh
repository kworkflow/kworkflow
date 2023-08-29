#!/bin/bash
#
include './src/lib/dialog_ui.sh'
include './tests/utils.sh'

function setUp()
{
  export ORIGINAL_PATH="$PWD"
  export TMP_DIR="${SHUNIT_TMPDIR}/ui"
  export KW_ETC_DIR="${TMP_DIR}"

  alias tput='tput_mock'
  [[ "$TERM" == '' || "$TERM" == 'dumb' ]] && TPUTTERM=' -T xterm-256color'

  EXPECTED_DEFAULT_WIDTH=$(eval tput"${TPUTTERM}" cols)
  EXPECTED_DEFAULT_HEIGHT=$(eval tput"${TPUTTERM}" lines)
  EXPECTED_DEFAULT_SMALL_WIDTH="$((EXPECTED_DEFAULT_WIDTH / 2))"
  EXPECTED_DEFAULT_SMALL_HEIGHT="$((EXPECTED_DEFAULT_HEIGHT / 3))"

  mkdir -p "$TMP_DIR"
  mkdir -p "$KW_ETC_DIR"

  cp --recursive 'etc/dialog_help' "${TMP_DIR}/dialog_help"
  # Let's run all test in a well-contained folder
  cd "${TMP_DIR}" || {
    fail "($LINENO): setUp: It was not possible to move into ${TMP_DIR}"
  }
}

function tearDown()
{
  cd "$ORIGINAL_PATH" || {
    fail "($LINENO): tearDown: It was not possible to move into ${ORIGINAL_PATH}"
    return
  }

  DIALOG_LAYOUT=''
  rm -rf "$SHUNIT_TMPDIR"
}

function test_ui_setup_no_layout()
{
  ui_setup

  assert_equals_helper 'Expected height' "$LINENO" "$EXPECTED_DEFAULT_HEIGHT" "$DEFAULT_HEIGHT"
  assert_equals_helper 'Expected width' "$LINENO" "$EXPECTED_DEFAULT_WIDTH" "$DEFAULT_WIDTH"
  assert_equals_helper 'Expected no layout' "$LINENO" '' "$DIALOG_LAYOUT"
}

function test_ui_setup_with_layout()
{
  # create a fake default layout
  mkdir -p "${KW_ETC_DIR}/dialog_ui/"
  touch "${KW_ETC_DIR}/dialog_ui/lala"

  ui_setup 'lala'

  assert_equals_helper 'Expected no layout' "$LINENO" "${KW_ETC_DIR}/dialog_ui/lala" "$DIALOG_LAYOUT"
}

function test_create_menu_options_rely_on_some_default_options()
{
  local menu_title='kunit test inside kw'
  local menu_message_box='This should be a useful message box'
  local -a menu_list_string_array=("I'm number 0" "I'm number 1" "I'm number 2" "I'm number 3" "I'm number 4" "I'm number 5")
  local expected=" dialog --backtitle \$'${KW_PATCH_HUB_TITLE}'"
  local output

  expected+=" --title $'${menu_title}' --clear --colors --cancel-label $'Exit' --menu $'${menu_message_box}'"
  expected+=" '${EXPECTED_DEFAULT_HEIGHT}' '${EXPECTED_DEFAULT_WIDTH}' '0'"
  expected+=" '0' $'I\'m number 0' '1' $'I\'m number 1' '2' $'I\'m number 2' '3' $'I\'m number 3' '4' $'I\'m number 4' '5' $'I\'m number 5'"

  output=$(create_menu_options "$menu_title" "$menu_message_box" menu_list_string_array '' '' '' '' '' '' '' '' 'TEST_MODE')
  assert_equals_helper 'Expected menu with some default options' "$LINENO" "$expected" "$output"
}

function test_create_menu_options_use_all_options()
{
  local menu_title='kunit test inside kw'
  local menu_message_box='This should be a useful message box'
  local -a menu_list_string_array=("I'm number 0" "I'm number 1" "I'm number 2" "I'm number 3" "I'm number 4" "I'm number 5")
  local expected=" dialog --backtitle \$'${KW_PATCH_HUB_TITLE}'"
  local output

  expected+=" --title $'${menu_title}' --clear --colors --cancel-label $'Xpto'"
  expected+=" --extra-button --extra-label $'Return' --help-button --help-label $'LoremIpsum'"
  expected+=" --menu $'${menu_message_box}'"
  expected+=" '300' '300' '0'"
  expected+=" $'I\'m number 2' '' $'I\'m number 3' '' $'I\'m number 4' ''"

  output=$(create_menu_options "$menu_title" "$menu_message_box" menu_list_string_array 2 4 'Return' 'Xpto' 'LoremIpsum' 300 300 1 'TEST_MODE')
  assert_equals_helper 'Expected menu with with all custom options' "$LINENO" "$expected" "$output"
}

function test_create_simple_checklist_rely_on_some_default_options()
{
  local menu_title='kunit test inside kw'
  local menu_message_box="This shouldn't be a useful dialog's screen message box"
  local -a menu_list_string_array=('Checklist 1' 'Checklist 2')
  local -a check_statuses=(1 0)
  local expected_cmd=" dialog --backtitle \$'${KW_PATCH_HUB_TITLE}'"
  local output

  expected_cmd+=" --title $'${menu_title}' --clear --colors --cancel-label $'Exit'"
  expected_cmd+=" --checklist $'This shouldn\'t be a useful dialog\'s screen message box'"
  expected_cmd+=" '${EXPECTED_DEFAULT_HEIGHT}' '${EXPECTED_DEFAULT_WIDTH}' '0'"
  expected_cmd+=" $'Checklist 1' '' 'on' $'Checklist 2' '' 'off'"

  output=$(create_simple_checklist "$menu_title" "$menu_message_box" 'menu_list_string_array' 'check_statuses' '' '' '' '' '' 'TEST_MODE')
  assert_equals_helper 'Expected simple checklist' "$LINENO" "${output}" "${expected_cmd}"
}

function test_create_simple_checklist_use_all_options()
{
  local menu_title='kunit test inside kw'
  local menu_message_box="This shouldn't be a useful dialog's screen message box"
  local -a menu_list_string_array=('Checklist 1' 'Checklist 2')
  local -a check_statuses=(1 0)
  local expected_cmd=" dialog --backtitle \$'${KW_PATCH_HUB_TITLE}'"
  local output

  expected_cmd+=" --title $'${menu_title}' --clear --colors --cancel-label $'Nop'"
  expected_cmd+=" --extra-button --extra-label 'Return'"
  expected_cmd+=" --checklist $'This shouldn\'t be a useful dialog\'s screen message box'"
  expected_cmd+=" '442' '244' '3'"
  expected_cmd+=" $'Checklist 1' '' 'on' $'Checklist 2' '' 'off'"

  output=$(create_simple_checklist "$menu_title" "$menu_message_box" 'menu_list_string_array' 'check_statuses' 1 'Nop' '442' '244' '3' 'TEST_MODE')
  assert_equals_helper 'Expected simple checklist' "$LINENO" "${output}" "${expected_cmd}"
}

function test_create_loading_screen_notification_rely_on_some_default_options()
{
  local loading_message="kunit's test inside kw"
  local expected_cmd="dialog --colors"
  local output

  expected_cmd+=" --infobox $'kunit\'s test inside kw'"
  expected_cmd+=" '8' '60'"

  output=$(create_loading_screen_notification "$loading_message" '' '' 'TEST_MODE')
  assert_equals_helper 'Expected loading screen with some default options' "$LINENO" "${output}" "${expected_cmd}"
}

function test_create_loading_screen_notification_use_all_options()
{
  local loading_message="kunit's test inside kw"
  local expected_cmd="dialog --colors"
  local output

  expected_cmd+=" --infobox $'kunit\'s test inside kw'"
  expected_cmd+=" '1234' '4321'"

  output=$(create_loading_screen_notification "$loading_message" '1234' '4321' 'TEST_MODE')
  assert_equals_helper 'Expected loading screen with some default options' "$LINENO" "${output}" "${expected_cmd}"
}

function test_create_message_box_rely_on_some_default_options()
{
  local box_title='Bookmarked patches'
  local message_box="There're no bookmarked patches..."
  local expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  local output

  expected_cmd+=" --title $'${box_title}' --clear --colors"
  expected_cmd+=" --msgbox $'There\'re no bookmarked patches...'"
  expected_cmd+=" '15' '40'"
  output=$(create_message_box "${box_title}" "${message_box}" '' '' 'TEST_MODE')
  assert_equals_helper 'Expected message box with some default options' "$LINENO" "$output" "${expected_cmd}"
}

function test_create_message_box_use_all_options()
{
  local box_title='Bookmarked patches'
  local message_box="There're no bookmarked patches..."
  local expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  local output

  expected_cmd+=" --title $'${box_title}' --clear --colors"
  expected_cmd+=" --msgbox $'There\'re no bookmarked patches...'"
  expected_cmd+=" '1234' '4321'"
  output=$(create_message_box "${box_title}" "${message_box}" '1234' '4321' 'TEST_MODE')
  assert_equals_helper 'Expected message box with all custom options' "$LINENO" "$output" "${expected_cmd}"
}

function test_create_directory_selection_screen_rely_on_some_default_options()
{
  local starting_path='/some/creative/path'
  local box_title="Choose 'a' Directory!"
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Choose \'a\' Directory!' --clear --colors"
  expected_cmd+=" --help-button --dselect '${starting_path}'"
  expected_cmd+=" '15' '80'"
  output=$(create_directory_selection_screen "${starting_path}" "${box_title}" '' '' 'TEST_MODE')
  assert_equals_helper 'Expected directory selection with some default options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_directory_selection_screen_use_all_options()
{
  local starting_path='/some/creative/path'
  local box_title="Choose 'a' Directory!"
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Choose \'a\' Directory!' --clear --colors"
  expected_cmd+=" --help-button --dselect '${starting_path}'"
  expected_cmd+=" '2718' '281828'"
  output=$(create_directory_selection_screen "${starting_path}" "${box_title}" '2718' '281828' 'TEST_MODE')
  assert_equals_helper 'Expected directory selection with all custom options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_file_selection_screen_rely_on_some_default_options()
{
  local starting_path='/some/creative/path'
  local box_title="Choose 'a' File!"
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Choose \'a\' File!' --clear --colors"
  expected_cmd+=" --help-button --fselect '${starting_path}'"
  expected_cmd+=" '15' '80'"
  output=$(create_file_selection_screen "${starting_path}" "${box_title}" '' '' '' 'TEST_MODE')
  assert_equals_helper 'Expected file selection with some default options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_file_selection_screen_use_all_options()
{
  local starting_path='/some/creative/path'
  local box_title="Choose 'a' File!"
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Choose \'a\' File!' --clear --colors"
  expected_cmd+=" --help-button --extra-button --extra-label $'EXTRA' --fselect '${starting_path}'"
  expected_cmd+=" '2718' '281828'"
  output=$(create_file_selection_screen "${starting_path}" "${box_title}" 'EXTRA' '2718' '281828' 'TEST_MODE')
  assert_equals_helper 'Expected file selection with all custom options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_help_screen()
{
  local expected_cmd
  local output

  create_help_screen 'fake_screen' 'TEST_MODE'
  assert_equals_helper 'Invalid screen name should return 2' "$LINENO" 2 "$?"

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}' --title $'Directory Selection Help' --clear --colors --msgbox"
  expected_cmd+=" $'There are 3 regions in the Directory Selection screen:"$'\n'
  expected_cmd+='- [Upper Box]: list of directories in the current path.'$'\n'
  expected_cmd+='- [Lower Box]: the current path (input box).'$'\n'
  expected_cmd+='- [Buttons]: "OK" to confirm directory path, "Cancel" to cancel selection and "Help" to show this screen.'$'\n'$'\n'
  expected_cmd+='To move between the regions, use the <TAB> key.'$'\n'
  expected_cmd+='To complete the current path with the highlighted directory, use the <SPACE> key.'$'\n'
  expected_cmd+="Typing while in the Upper Box or the Lower Box alters the current path.'"
  expected_cmd+=" '15' '70'"
  output=$(create_help_screen 'directory_selection' 'TEST_MODE')
  assert_equals_helper 'Wrong help screen for Directory Selection' "$LINENO" "$expected_cmd" "$output"
}

function test_create_choice_list_screen_with_indexed_array_rely_on_some_default_options()
{
  local box_title="Make 'a' choice!"
  local message_box="Select \`one' of the below options."
  # shellcheck disable=SC2190
  local -a choices=('choice1' 'choice2' 'choice3' 'choice4')
  local -a check_statuses=('' 1 '' '')
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Make \'a\' choice!' --clear --colors"
  expected_cmd+=" --ok-label $'Ok' --cancel-label $'Cancel'"
  expected_cmd+=" --radiolist $'Select \`one\' of the below options.'"
  expected_cmd+=" '${EXPECTED_DEFAULT_HEIGHT}' '${EXPECTED_DEFAULT_WIDTH}' '0'"
  expected_cmd+=" $'choice1' '' 'off' $'choice2' '' 'on' $'choice3' '' 'off' $'choice4' '' 'off'"
  output=$(create_choice_list_screen "$box_title" "$message_box" 'choices' 'check_statuses' '' '' '' '' '' 'TEST_MODE')
  assert_equals_helper 'Expected choice list with some default options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_choice_list_screen_with_indexed_array_use_all_options()
{
  local box_title="Make 'a' choice!"
  local message_box="Select \`one' of the below options."
  # shellcheck disable=SC2190
  local -a choices=('choice1' 'choice2' 'choice3' 'choice4')
  local -a check_statuses=('' 1 '' '')
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Make \'a\' choice!' --clear --colors"
  expected_cmd+=" --ok-label $'Next' --cancel-label $'Previous' --extra-button --extra-label $'Cancel'"
  expected_cmd+=" --radiolist $'Select \`one\' of the below options.'"
  expected_cmd+=" '17041998' '10300507' '0'"
  expected_cmd+=" $'choice1' '' 'off' $'choice2' '' 'on' $'choice3' '' 'off' $'choice4' '' 'off'"
  output=$(create_choice_list_screen "$box_title" "$message_box" 'choices' 'check_statuses' 'Next' 'Previous' 'Cancel' '17041998' '10300507' 'TEST_MODE')
  assert_equals_helper 'Expected choice list with all custom options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_choice_list_screen_with_associative_array_rely_on_some_default_options()
{
  local box_title="Make 'a' choice!"
  local message_box="Select \`one' of the below options."
  declare -A choices=(['choice1']='good choice' ['choice2']='bad choice' ['choice3']='a choice is a choice')
  local -a check_statuses=('' 1 '')
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Make \'a\' choice!' --clear --colors"
  expected_cmd+=" --ok-label $'Ok' --cancel-label $'Cancel'"
  expected_cmd+=" --radiolist $'Select \`one\' of the below options.'"
  expected_cmd+=" '${EXPECTED_DEFAULT_HEIGHT}' '${EXPECTED_DEFAULT_WIDTH}' '0'"
  expected_cmd+=" $'choice1' $'${choices['choice1']}' 'off' $'choice2' $'${choices['choice2']}' 'on' $'choice3' $'${choices['choice3']}' 'off'"
  output=$(create_choice_list_screen "$box_title" "$message_box" 'choices' 'check_statuses' '' '' '' '' '' 'TEST_MODE')
  assert_equals_helper 'Expected choice list with some default options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_choice_list_screen_with_associative_array_use_all_options()
{
  local box_title="Make 'a' choice!"
  local message_box="Select \`one' of the below options."
  declare -A choices=(['choice1']='good choice' ['choice2']='bad choice' ['choice3']='a choice is a choice')
  local -a check_statuses=('' 1 '')
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Make \'a\' choice!' --clear --colors"
  expected_cmd+=" --ok-label $'Next' --cancel-label $'Previous' --extra-button --extra-label $'Cancel'"
  expected_cmd+=" --radiolist $'Select \`one\' of the below options.'"
  expected_cmd+=" '17041998' '10300507' '0'"
  expected_cmd+=" $'choice1' $'${choices['choice1']}' 'off' $'choice2' $'${choices['choice2']}' 'on' $'choice3' $'${choices['choice3']}' 'off'"
  output=$(create_choice_list_screen "$box_title" "$message_box" 'choices' 'check_statuses' 'Next' 'Previous' 'Cancel' '17041998' '10300507' 'TEST_MODE')
  assert_equals_helper 'Expected choice list with all custom options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_yes_no_prompt_rely_on_some_default_options()
{
  local box_title="Choose Yes 'or' No!"
  local message_box="This is \`a Yes/No' prompt."
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Choose Yes \'or\' No!' --clear --colors"
  expected_cmd+=" --yes-label $'Yes' --no-label $'No'"
  expected_cmd+=" --yesno $'This is \`a Yes/No\' prompt.'"
  expected_cmd+=" '15' '40'"
  output=$(create_yes_no_prompt "$box_title" "$message_box" '' '' '' '' '' 'TEST_MODE')
  assert_equals_helper 'Expected Yes/No prompt with some default options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_yes_no_prompt_use_all_options()
{
  local box_title="Choose Yes 'or' No!"
  local message_box="This is \`a Yes/No' prompt."
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Choose Yes \'or\' No!' --clear --colors"
  expected_cmd+=" --yes-label $'No' --no-label $'Yes'"
  expected_cmd+=" --extra-button --extra-label $'Not Extra'"
  expected_cmd+=" --yesno $'This is \`a Yes/No\' prompt.'"
  expected_cmd+=" '31415' '2718281828'"
  output=$(create_yes_no_prompt "$box_title" "$message_box" 'No' 'Yes' 'Not Extra' '31415' '2718281828' 'TEST_MODE')
  assert_equals_helper 'Expected Yes/No prompt with all custom options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_form_screen_default_options()
{
  local box_title='Simple form'
  local message_box='This is a simple form'
  declare -a fields_list=('User' 'IP' 'Port')
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}' --title $'${box_title}'"
  expected_cmd+=' --clear --colors'
  expected_cmd+=" --ok-label $'Ok' --cancel-label $'Cancel'"
  expected_cmd+=" --form $'${message_box}'"
  expected_cmd+=" '${DEFAULT_WIDTH}' '${DEFAULT_HEIGHT}' '0'"
  expected_cmd+=" $'User:' $'1' 1 $'' $'1' $'6' 10 0"
  expected_cmd+=" $'IP:' $'2' 1 $'' $'2' $'6' 10 0"
  expected_cmd+=" $'Port:' $'3' 1 $'' $'3' $'6' 10 0"

  output=$(create_form_screen "$box_title" "$message_box" 'fields_list' '' '' '' "${EXPECTED_DEFAULT_WIDTH}" "${EXPECTED_DEFAULT_HEIGHT}" 'TEST_MODE')

  assert_equals_helper 'Expected form with default values' "$LINENO" "$expected_cmd" "$output"
}

function test_create_form_screen_all_options()
{
  local box_title='Simple form'
  local message_box='This is a simple form'
  local ok_label='Next'
  local cancel_label='Previous'
  local extra_label='Cancel'
  declare -a fields_list=('User' 'IP' 'Port')
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}' --title $'${box_title}'"
  expected_cmd+=' --clear --colors'
  expected_cmd+=" --ok-label $'${ok_label}' --cancel-label $'${cancel_label}'"
  expected_cmd+=" --extra-button --extra-label ${extra_label}"
  expected_cmd+=" --form $'${message_box}'"
  expected_cmd+=" '200' '344' '0'"
  expected_cmd+=" $'User:' $'1' 1 $'' $'1' $'6' 10 0"
  expected_cmd+=" $'IP:' $'2' 1 $'' $'2' $'6' 10 0"
  expected_cmd+=" $'Port:' $'3' 1 $'' $'3' $'6' 10 0"

  output=$(create_form_screen "$box_title" "$message_box" 'fields_list' "$ok_label" "$cancel_label" "$extra_label" 200 344 'TEST_MODE')

  assert_equals_helper 'Expected form with default values' "$LINENO" "$expected_cmd" "$output"
}

function test_create_rangebox_screen_rely_on_some_default_options()
{
  local box_title="Select a 'value' from this range"
  local message_box="This is \`a rangebox'."
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Select a \'value\' from this range' --clear --colors"
  expected_cmd+=" --cancel-label $'Exit'"
  expected_cmd+=" --rangebox $'This is \`a rangebox\'.'"
  expected_cmd+=" '10' '60'"
  expected_cmd+=" '0' '100' '50'"
  output=$(create_rangebox_screen "$box_title" "$message_box" '' '' '' '' '' '' '' '' 'TEST_MODE')
  assert_equals_helper 'Expected Rangebox with some default options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_rangebox_screen_use_all_options()
{
  local box_title="Select a 'value' from this range"
  local message_box="This is \`a rangebox'."
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Select a \'value\' from this range' --clear --colors"
  expected_cmd+=" --cancel-label $'Cancel'"
  expected_cmd+=" --extra-button --extra-label $'range' --help-button --help-label $'box'"
  expected_cmd+=" --rangebox $'This is \`a rangebox\'.'"
  expected_cmd+=" '2718' '31415'"
  expected_cmd+=" '23' '42' '318'"
  output=$(create_rangebox_screen "$box_title" "$message_box" 23 42 318 'range' 'Cancel' 'box' 2718 31415 'TEST_MODE')
  assert_equals_helper 'Expected Rangebox with all custom options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_inputbox_screen_rely_on_some_default_options()
{
  local box_title="Type a 'string' here!"
  local message_box="This is \`a inputbox'."
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Type a \'string\' here!' --clear --colors"
  expected_cmd+=" --cancel-label $'Exit'"
  expected_cmd+=" --inputbox $'This is \`a inputbox\'.'"
  expected_cmd+=" '${EXPECTED_DEFAULT_SMALL_HEIGHT}' '${EXPECTED_DEFAULT_SMALL_WIDTH}'"
  output=$(create_inputbox_screen "$box_title" "$message_box" '' '' '' '' '' 'TEST_MODE')
  assert_equals_helper 'Expected Inputbox with some default options' "$LINENO" "$expected_cmd" "$output"
}

function test_create_inputbox_screen_use_all_options()
{
  local box_title="Type a 'string' here!"
  local message_box="This is \`a inputbox'."
  local expected_cmd
  local output

  expected_cmd=" dialog --backtitle $'${KW_PATCH_HUB_TITLE}'"
  expected_cmd+=" --title $'Type a \'string\' here!' --clear --colors"
  expected_cmd+=" --cancel-label $'Cancel'"
  expected_cmd+=" --extra-button --extra-label $'range' --help-button --help-label $'box'"
  expected_cmd+=" --inputbox $'This is \`a inputbox\'.'"
  expected_cmd+=" '11223348' '8498129'"
  output=$(create_inputbox_screen "$box_title" "$message_box" 'range' 'Cancel' 'box' 11223348 8498129 'TEST_MODE')
  assert_equals_helper 'Expected Inputbox with all custom options' "$LINENO" "$expected_cmd" "$output"
}

function test_build_dialog_command_preamble()
{
  local output
  local expected

  # No dialog layout
  DIALOG_LAYOUT=''
  output=$(build_dialog_command_preamble 'title')
  expected=" dialog --backtitle \$'kw patch-hub' --title \$'title' --clear --colors"
  assert_equals_helper 'Wrong command built' "$LINENO" "$expected" "$output"

  # With dialog layout
  DIALOG_LAYOUT='/path/to/dialog/layout'
  output=$(build_dialog_command_preamble 'title')
  expected='DIALOGRC=/path/to/dialog/layout'
  expected+=" dialog --backtitle \$'kw patch-hub' --title \$'title' --clear --colors"
  assert_equals_helper 'Wrong command built' "$LINENO" "$expected" "$output"

  # With custom back title
  DIALOG_LAYOUT=''
  output=$(build_dialog_command_preamble 'title' 'back title')
  expected=" dialog --backtitle \$'back title' --title \$'title' --clear --colors"
  assert_equals_helper 'Wrong command built' "$LINENO" "$expected" "$output"
}

function test_prettify_string_failures()
{
  prettify_string
  assert_equals_helper 'Expected failure' "$LINENO" "$?" 22

  prettify_string 'Something'
  assert_equals_helper 'Expected failure' "$LINENO" "$?" 22
}

function test_prettify_string()
{
  local output
  local expected_string='\Zb\Z6Series:\ZnSomething\n'

  output=$(prettify_string 'Series:' 'Something')
  assert_equals_helper 'Expected pretty string' "$LINENO" "$output" "$expected_string"
}

invoke_shunit
