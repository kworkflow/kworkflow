#!/bin/bash

include './src/pomodoro.sh'
include './tests/utils.sh'

function setUp()
{
  mkdir -p "$TMP_TEST_DIR"
  export POMODORO_LOG_FILE="$SHUNIT_TMPDIR/pomodoro_current.log"
  export KW_POMODORO_DATA="$SHUNIT_TMPDIR/pomodoro"
  export KW_POMODORO_TAG_LIST="$KW_POMODORO_DATA/tags"

  touch "$POMODORO_LOG_FILE"

  declare -gA options_values
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
  mkdir -p "$SHUNIT_TMPDIR"
}

function test_register_timebox()
{
  local timebox='3332232557'
  local output
  local expected_result

  options_values['TIMER']='2m'
  register_timebox "$timebox"
  output=$(cat "$POMODORO_LOG_FILE")
  expected_result="$timebox,${options_values['TIMER']}"
  assert_equals_helper 'Regitered file did not match' "$LINENO" "$expected_result" "$output"

  declare -a expected_content=(
    "$expected_result"
    '4332232557,30m'
    '433222557,1h'
  )

  options_values['TIMER']='30m'
  register_timebox '4332232557'

  options_values['TIMER']='1h'
  register_timebox '433222557'

  output=$(cat "$POMODORO_LOG_FILE")
  compare_command_sequence '' "$LINENO" 'expected_content' "$output"
}

function test_remove_completed_timebox()
{
  # Register a bunch of data
  options_values['TIMER']='30m'
  register_timebox '4332232557'

  options_values['TIMER']='1h'
  register_timebox '433222557'

  options_values['TIMER']='43s'
  register_timebox '933222557'

  declare -a expected_content=(
    '4332232557,30m'
    '933222557,43s'
  )

  remove_completed_timebox '433222557'
  output=$(cat "$POMODORO_LOG_FILE")
  compare_command_sequence '' "$LINENO" 'expected_content' "$output"

  remove_completed_timebox '933222557'
  output=$(cat "$POMODORO_LOG_FILE")
  assert_equals_helper 'Line was not removed' "$LINENO" '4332232557,30m' "$output"

  remove_completed_timebox '4332232557'
  output=$(cat "$POMODORO_LOG_FILE")
  assert_equals_helper 'File should be empty' "$LINENO" '' "$output"

  # Invalid timestamp
  remove_completed_timebox '99032432'
  output=$(cat "$POMODORO_LOG_FILE")
  assert_equals_helper 'Line was not removed' "$LINENO" '' "$output"
}

function test_calculate_missing_time()
{
  local output

  output=$(calculate_missing_time '2m' 59)
  assert_equals_helper 'Expected 61 seconds' "$LINENO" "$output" '61'

  output=$(calculate_missing_time '2m' 10)
  assert_equals_helper 'Expected 110 seconds' "$LINENO" "$output" '110'

  output=$(calculate_missing_time '337s' 40)
  assert_equals_helper 'Expected 297 seconds' "$LINENO" "$output" '297'

  # No time type, we suppose seconds
  output=$(calculate_missing_time '337' 40)
  assert_equals_helper 'Expected 297 seconds' "$LINENO" "$output" '297'

  output=$(calculate_missing_time '2h' 0)
  assert_equals_helper 'Expected 7200 seconds' "$LINENO" "$output" '7200'

  output=$(calculate_missing_time '10m' 0)
  assert_equals_helper 'Expected 600 seconds' "$LINENO" "$output" '600'

  # Negative value
  output=$(calculate_missing_time '10s' 20)
  assert_equals_helper 'Expected 0 seconds' "$LINENO" "$output" '0'
}

function get_timestamp_sec_mock()
{
  printf '%s\n' '3332232700'
}

function test_show_active_pomodoro_timebox()
{
  local timestamp='3332232557'
  local timestamp_to_date
  local missing_time
  local diff_time
  local output

  shopt -s expand_aliases
  alias get_timestamp_sec='get_timestamp_sec_mock'

  options_values['TIMER']='2m'
  register_timebox "$timestamp"
  output=$(show_active_pomodoro_timebox)

  timestamp_to_date=$(date_to_format "@$timestamp" '+%H:%M:%S[%Y/%m/%d]')
  diff_time=$((3332232700 - timestamp))
  elapsed_time=$(sec_to_format "$diff_time")
  missing_time=$(calculate_missing_time "${options_values['TIMER']}" "$diff_time")
  missing_time=$(sec_to_format "$missing_time")

  declare -a expected_content=(
    "Started at: $timestamp_to_date"
    "- Elapsed time: $elapsed_time"
    "- You still have $missing_time"
  )

  output=$(show_active_pomodoro_timebox)
  compare_command_sequence '' "$LINENO" 'expected_content' "$output"

  rm "$POMODORO_LOG_FILE"
  output=$(show_active_pomodoro_timebox 2>&1)
  assert_equals_helper 'We should have no output' "$LINENO" "$output" ''
}

function test_parse_pomodoro()
{
  local output

  parse_pomodoro '-t' '10m'
  assert_equals_helper 'Time parser failed (minutes)' "$LINENO" "${options_values['TIMER']}" '10m'

  parse_pomodoro '-t' '333h'
  assert_equals_helper 'Time parser failed (hour)' "$LINENO" "${options_values['TIMER']}" '333h'

  parse_pomodoro '--set-timer' '234s'
  assert_equals_helper 'Time parser failed (sec)' "$LINENO" "${options_values['TIMER']}" '234s'

  output=$(parse_pomodoro '--set-timer' '23 s')
  assert_equals_helper 'No space' "$LINENO" "$?" '22'

  output=$(parse_pomodoro '--set-timer' '234')
  assert_equals_helper 'No suffix' "$LINENO" "$?" '22'

  output=$(parse_pomodoro '--set-timer' 'uum')
  assert_equals_helper 'No a number' "$LINENO" "$?" '22'

  parse_pomodoro '--check-timer'
  assert_equals_helper 'Show current timebox' "$LINENO" "${options_values['SHOW_TIMER']}" '1'

  parse_pomodoro '--tag' 'Something is here'
  assert_equals_helper 'Tag requires set timer' "$LINENO" "$?" 22

  parse_pomodoro '--set-timer' '1234s' '--tag' 'Something is here'
  assert_equals_helper 'Get tag' "$LINENO" "${options_values['TAG']}" 'Something is here'

  parse_pomodoro '--set-timer' '1234s' '--tag' '   Extra space   '
  assert_equals_helper 'Handle extra space failed' "$LINENO" "${options_values['TAG']}" 'Extra space'

  str_sample='com ç -u ^ xpo-la ¬ x--bl'
  parse_pomodoro '--set-timer' '1234s' '--tag' "$str_sample"
  assert_equals_helper 'Handle diverse chars' "$LINENO" "${options_values['TAG']}" "$str_sample"

  output=$(parse_pomodoro '--description' 'lala lalala')
  assert_equals_helper 'Description requires tag' "$LINENO" "$?" 22

  output=$(parse_pomodoro '-g' 'Some tag' '--description' 'lala lalala')
  assert_equals_helper 'Description requires set timer' "$LINENO" "$?" 22

  str_sample='This is just a simple description'
  parse_pomodoro '--set-timer' '1234s' '--tag' 'Some tag' '-d' "$str_sample"
  assert_equals_helper 'Wrong description' "$LINENO" "${options_values['DESCRIPTION']}" "$str_sample"

  str_sample_spaces='            This is just a simple description    '
  parse_pomodoro '--set-timer' '1234s' '--tag' 'Some tag' '-d' "$str_sample_spaces"
  assert_equals_helper 'Wrong description' "$LINENO" "${options_values['DESCRIPTION']}" "$str_sample"

  str_sample='Does --comment --lal -u -x xpto-bla and xpto--blablbal'
  parse_pomodoro '--set-timer' '1234s' '--tag' 'Some tag' '-d' "$str_sample"
  assert_equals_helper 'Wrong description' "$LINENO" "${options_values['DESCRIPTION']}" "$str_sample"

  apostrophe="Let's try something with apostrophe (I'm, you're, we're)"
  parse_pomodoro '--set-timer' '1234s' '--tag' 'apostrophe' '--description' "$apostrophe"
  assert_equals_helper 'Wrong description' "$LINENO" "${options_values['DESCRIPTION']}" "$apostrophe"
}

function test_setup_pomodoro()
{
  local output
  local year_month
  local today

  year_month=$(date '+%Y/%m')
  today=$(date '+%d')

  output=$(setup_pomodoro)
  assertTrue 'Date file was not created' '[[ -f "$KW_POMODORO_DATA/$year_month/$today" ]]'
}

function test_register_data_for_report()
{
  local output
  local year_month
  local today
  local description
  local sample_str

  year_month=$(date '+%Y/%m')
  today=$(date '+%d')

  options_values['TAG']='Test 12'
  options_values['TIMER']='30m'
  output=$(register_data_for_report)

  assertTrue 'Date file was not created' '[[ -f "$KW_POMODORO_DATA/$year_month/$today" ]]'

  data=$(cat "$KW_POMODORO_DATA/$year_month/$today")
  tag=$(printf '%s\n' "$data" | cut -d',' -f1)
  timer=$(printf '%s\n' "$data" | cut -d',' -f2)

  assert_equals_helper 'Label did not match' "$LINENO" "$tag" "${options_values['TAG']}"
  assert_equals_helper 'Timer did not match' "$LINENO" "$timer" "${options_values['TIMER']}"
  rm "$KW_POMODORO_DATA/$year_month/$today"
  sample_str='Simple description'
  options_values['DESCRIPTION']="$sample_str"
  output=$(register_data_for_report)
  data=$(cat "$KW_POMODORO_DATA/$year_month/$today")
  description=$(printf '%s\n' "$data" | cut -d',' -f4)

  assert_equals_helper 'Label did not match' "$LINENO" "$sample_str" "${options_values['DESCRIPTION']}"
}

function test_register_tag()
{
  local output

  # We need basic setup for tags
  setup_pomodoro > /dev/null
  declare -a expected_content=(
    'tag 1'
    'tag 2'
  )

  register_tag 'tag 1'
  register_tag 'tag 2'
  output=$(cat "$KW_POMODORO_TAG_LIST")

  compare_command_sequence '' "$LINENO" 'expected_content' "$output"

  # Try to register the same tag
  register_tag 'tag 2'
  compare_command_sequence '' "$LINENO" 'expected_content' "$output"

  # Try to register an empty tag
  register_tag ''
  compare_command_sequence '' "$LINENO" 'expected_content' "$output"
}

function test_is_tag_already_registered()
{
  # We need basic setup for test this function
  setup_pomodoro > /dev/null
  touch "$KW_POMODORO_TAG_LIST"

  is_tag_already_registered 'Tag 0'
  assertNotEquals "$LINENO: We should not get a success" "$?" 0

  is_tag_already_registered ''
  assertNotEquals "$LINENO: We should not get a success" "$?" 0

  printf '%s\n' 'Tag 0' >> "$KW_POMODORO_TAG_LIST"
  is_tag_already_registered 'Tag 0'
  assertEquals "$LINENO: We expect to find Tag 0" "$?" 0
}

function test_get_tag_name()
{
  local output
  local expected

  setup_pomodoro > /dev/null

  get_tag_name ''
  assert_equals_helper 'Empty string should be detected' "$LINENO" '22' "$?"

  output=$(get_tag_name 'Some tag')
  expected='Some tag'
  assert_equals_helper 'Should return same value if it is not a number' "$LINENO" "$expected" "$output"

  register_tag 'tag 1'
  register_tag 'tag 2'
  register_tag 'tag 3'
  register_tag 'tag 4'

  for i in {1..4}; do
    output=$(get_tag_name "$i")
    expected="tag $i"
    assert_equals_helper 'We expect to find a tag' "$LINENO: ($i)" "$expected" "$output"
  done

  # Try to get an ID out of range
  get_tag_name 65
  assert_equals_helper 'Out of range' "$LINENO" '22' "$?"

  get_tag_name -2
  assert_equals_helper 'Out of range' "$LINENO" '22' "$?"
}

function test_is_valid_argument()
{
  local expected_error

  is_valid_argument '--long-option' 'some-option'
  assert_equals_helper 'Long option should return 22' "$LINENO" 22 "$?"
  expected_error='Invalid some-option argument: --long-option'
  assert_equals_helper 'Incorrect error message' "$LINENO" "$expected_error" "${options_values[ERROR]}"

  is_valid_argument '-o' 'some-option'
  assert_equals_helper 'Short option should return 22' "$LINENO" 22 "$?"
  expected_error='Invalid some-option argument: -o'
  assert_equals_helper 'Incorrect error message' "$LINENO" "$expected_error" "${options_values[ERROR]}"

  is_valid_argument 'valid-argument' 'some-option'
  assert_equals_helper 'Valid argument should return 0' "$LINENO" 0 "$?"
}

function test_is_valid_time()
{
  local expected_error

  is_valid_time 'invalid-time'
  assert_equals_helper 'Invalid time should return 22' "$LINENO" 22 "$?"
  expected_error='Invalid time: invalid-time'
  assert_equals_helper 'Incorrect error message' "$LINENO" "$expected_error" "${options_values[ERROR]}"

  is_valid_time '1'
  assert_equals_helper 'Number without time scale should return 22' "$LINENO" 22 "$?"
  expected_error='Invalid time: 1'
  assert_equals_helper 'Incorrect error message' "$LINENO" "$expected_error" "${options_values[ERROR]}"

  is_valid_time 'NUMBERm'
  assert_equals_helper 'Not a number with time scale should return 22' "$LINENO" 22 "$?"
  expected_error='Invalid time: NUMBERm'
  assert_equals_helper 'Incorrect error message' "$LINENO" "$expected_error" "${options_values[ERROR]}"

  is_valid_time '0m'
  assert_equals_helper 'Null time should return 22' "$LINENO" 22 "$?"
  expected_error='Time should be bigger than zero'
  assert_equals_helper 'Incorrect error message' "$LINENO" "$expected_error" "${options_values[ERROR]}"

  is_valid_time '1234h'
  assert_equals_helper 'Valid time should return 0' "$LINENO" 0 "$?"

  is_valid_time '7654321m'
  assert_equals_helper 'Valid time should return 0' "$LINENO" 0 "$?"

  is_valid_time '999000999000s'
  assert_equals_helper 'Valid time should return 0' "$LINENO" 0 "$?"
}

invoke_shunit
