#!/bin/bash

include './src/report.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  cp -r "$SAMPLES_DIR"/pomodoro_data/* "$SHUNIT_TMPDIR"
  export KW_POMODORO_DATA="$SHUNIT_TMPDIR"
}

function test_report_parse()
{
  local output
  local expected_result
  local ref_date
  local ret

  # Default values
  report_parse '--day'
  expected_result=$(get_today_info '+%Y/%m/%d')
  assert_equals_helper 'Get today info' "$LINENO" "${options_values['DAY']}" "$expected_result"

  report_parse '--week'
  expected_result=$(get_week_beginning_day)
  assert_equals_helper 'Get this week info' "$LINENO" "${options_values['WEEK']}" "$expected_result"

  report_parse '--month'
  expected_result=$(get_today_info '+%Y/%m')
  assert_equals_helper 'Get this month info' "$LINENO" "${options_values['MONTH']}" "$expected_result"

  report_parse '--year'
  expected_result=$(get_today_info '+%Y')
  assert_equals_helper 'Get this year info' "$LINENO" "${options_values['YEAR']}" "$expected_result"

  # Values with parameters
  ## Days
  ref_date='1999/03/03'
  report_parse "--day $ref_date"
  expected_result=$(date_to_format "$ref_date" '+%Y/%m/%d')
  assert_equals_helper "$ref_date is a valid date" "$LINENO" "${options_values['DAY']}" "$expected_result"

  ref_date='2022/04/32'
  output=$(report_parse "--day $ref_date" 2> /dev/null)
  ret="$?"
  assert_equals_helper "$ref_date is an invalid date" "$LINENO" "$ret" 22

  ## Weeks
  ref_date='1990/04/10'
  report_parse "--week $ref_date"
  expected_result=$(get_week_beginning_day "$ref_date")
  assert_equals_helper 'We expected 1990/04/04' "$LINENO" "${options_values['WEEK']}" "$expected_result"

  ref_date='2022/04/32'
  output=$(report_parse "--week $ref_date" 2> /dev/null)
  ret="$?"
  assert_equals_helper "$ref_date is invalid" "$LINENO" "$ret" 22

  ## Month
  ref_date='1990/04'
  report_parse "--month $ref_date"
  expected_result=$(date_to_format "$ref_date/01" '+%Y/%m')
  assert_equals_helper 'We expected 1990/04' "$LINENO" "${options_values['MONTH']}" "$expected_result"

  ref_date='1990/30'
  output=$(report_parse "--month $ref_date" 2> /dev/null)
  ret="$?"
  assert_equals_helper 'Invalid date' "$LINENO" "$ret" 22

  # Invalid parameter
  ref_date='2022/04/12'
  output=$(report_parse "--month $ref_date --day $ref_date" 2> /dev/null)
  ret="$?"
  assert_equals_helper 'Invalid date' "$LINENO" "$ret" 22
}

function test_expand_time_labels()
{
  local output
  local ret

  # No label
  output=$(expand_time_labels '300')
  assert_equals_helper 'Expects 300 seconds' "$LINENO" "$output" '300 seconds'

  output=$(expand_time_labels '30s')
  assert_equals_helper 'Expects 30 seconds' "$LINENO" "$output" '30 seconds'

  output=$(expand_time_labels '30m')
  assert_equals_helper 'Expects 30 minutes' "$LINENO" "$output" '30 minutes'

  output=$(expand_time_labels '3h')
  assert_equals_helper 'Expects 3 hours' "$LINENO" "$output" '3 hours'

  output=$(expand_time_labels 'Nothing')
  ret="$?"
  assert_equals_helper 'Expected an error code' "$LINENO" "$ret" 22

  output=$(expand_time_labels '')
  ret="$?"
  assert_equals_helper 'Expected an error code' "$LINENO" "$ret" 22
}

function test_grouping_day_data()
{
  local count=0
  local line

  declare -a expected_content=(
    ' * [06:00:40-06:20:40][20m]: Tag 1 description\n'
    ' * [08:30:50-08:45:50][15m]: Tag 2 description\n'
    ' * [09:00:00-10:00:00][1h]: Tag 3 description\n'
    ' * [11:00:00-11:00:44][44s]: Tag 4 description\n'
    ' * [14:00:00-14:30:00][30m]: Tag 5 description\n'
    ' * [15:00:00-15:10:00][10m]\n'
  )

  declare -a expected_tags=(
    'tag_1'
    'tag_2'
    'tag_3'
    'tag_4'
    'tag_5'
    'tag_6'
  )

  grouping_day_data '2021/04/04'
  for tag in "${expected_tags[@]}"; do
    line="${expected_content[$count]}"
    assert_equals_helper "Loop $count failed" "$LINENO" "$line" "${tags_details[$tag]}"
    ((count++))
  done

  # Try to process file with bad data
  count=0
  declare -a expected_content=(
    ' * [06:00:40-06:20:40][20m]: Tag 1 description\n'
    ' * [09:00:00-10:00:00][1h]: Tag 3 description\n'
  )

  declare -a expected_tags=(
    'bad_tag_1'
    # We must skip bad_tag_2
    'bad_tag_3'
    # We must skip bad_tag_4
  )

  grouping_day_data 'bad_data/2021/04/04'
  for tag in "${expected_tags[@]}"; do
    line="${expected_content[$count]}"
    assert_equals_helper "Loop $count failed" "$LINENO" "$line" "${tags_details[$tag]}"
    ((count++))
  done
}

invoke_shunit
