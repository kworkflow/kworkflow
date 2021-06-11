#!/bin/bash

include './src/pomodoro.sh'
include './tests/utils'

function suite()
{
  suite_addTest 'register_timebox_Test'
  suite_addTest 'remove_completed_timebox_Test'
  suite_addTest 'calculate_missing_time_Test'
  suite_addTest 'show_active_pomodoro_timebox_Test'
  suite_addTest 'pomodoro_parser_Test'
}

function setUp()
{
  mkdir "$TMP_TEST_DIR"
  export POMODORO_LOG_FILE="$TMP_TEST_DIR/pomodoro_current.log"

  touch "$POMODORO_LOG_FILE"
}

function tearDown()
{
  rm -rf "$TMP_TEST_DIR"
}

function register_timebox_Test()
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
  compare_command_sequence expected_content[@] "$output" "($LINENO)"
}

function remove_completed_timebox_Test()
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
  compare_command_sequence expected_content[@] "$output" "($LINENO)"

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

function calculate_missing_time_Test()
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
  echo 3332232700
}

function show_active_pomodoro_timebox_Test()
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
  diff_time=$((3332232700 - $timestamp))
  elapsed_time=$(sec_to_format "$diff_time")
  missing_time=$(calculate_missing_time "${options_values['TIMER']}" "$diff_time")
  missing_time=$(sec_to_format "$missing_time")

  declare -a expected_content=(
    "Started at: $timestamp_to_date"
    "- Elapsed time: $elapsed_time"
    "- You still have $missing_time"
  )

  output=$(show_active_pomodoro_timebox)
  compare_command_sequence expected_content[@] "$output" "($LINENO)"
}

function pomodoro_parser_Test()
{
  local output

  pomodoro_parser '-t 10m'
  assert_equals_helper 'Time parser failed (minutes)' "$LINENO" "${options_values['TIMER']}" '10m'

  pomodoro_parser '-t 333h'
  assert_equals_helper 'Time parser failed (hour)' "$LINENO" "${options_values['TIMER']}" '333h'

  pomodoro_parser '--set-timer 234s'
  assert_equals_helper 'Time parser failed (sec)' "$LINENO" "${options_values['TIMER']}" '234s'

  output=$(pomodoro_parser '--set-timer 23 s')
  assert_equals_helper 'No space' "$LINENO" "$?" '22'

  output=$(pomodoro_parser '--set-timer 234')
  assert_equals_helper 'No suffix' "$LINENO" "$?" '22'

  output=$(pomodoro_parser '--set-timer uum')
  assert_equals_helper 'No a number' "$LINENO" "$?" '22'

  pomodoro_parser '--current'
  assert_equals_helper 'Show current timebox' "$LINENO" "${options_values['SHOW_TIMER']}" '1'
}

invoke_shunit
