#!/bin/bash

include './src/kw_time_and_date.sh'
include './tests/utils'

function suite()
{
  suite_addTest 'sec_to_format_Test'
  suite_addTest 'get_today_info_Test'
  suite_addTest 'get_week_beginning_day_Test'
  suite_addTest 'date_to_format_Test'
}

function setUp()
{
  # Samples file data
  pre_total_sec="1846"
  pre_formated_sec="00:30:46"
}

function sec_to_format_Test()
{
  formatted_time=$(sec_to_format "$pre_total_sec")
  assertEquals "($LINENO)" "$formatted_time" "$pre_formated_sec"

  formatted_time=$(sec_to_format "")
  assertEquals "($LINENO)" "$formatted_time" '00:00:00'

  formatted_time=$(sec_to_format "$pre_total_sec" '+%M:%S')
  assertEquals "($LINENO)" "$formatted_time" '30:46'

  formatted_time=$(sec_to_format "$pre_total_sec" '+%S')
  assertEquals "($LINENO)" "$formatted_time" '46'
}

function get_today_info_Test()
{
  local today=$(date +%Y/%m/%d)

  formated_today=$(get_today_info '+%Y/%m/%d')
  assert_equals_helper 'Today info did not match' "$LINENO" "$today" "$formated_today"

  formated_today=$(get_today_info)
  today=$(date)
  assert_equals_helper 'No parameter' "$LINENO" "$today" "$formated_today"
}

function get_week_beginning_day_Test()
{
  local ref_week='2021/05/19'
  local first_week_day='2021/05/16'
  local this_week_day

  week_day=$(get_week_beginning_day "$ref_week")
  assert_equals_helper 'First day of the week did not match' "$LINENO" "$first_week_day" "$week_day"

  week_day=$(get_week_beginning_day "$ref_week" '+%m/%d')
  assert_equals_helper 'Day format is wrong' "$LINENO" '05/16' "$week_day"

  # No parameters, means this week
  ref_week=$(date '+%Y/%m/%d')
  this_week_day=$(date '+%u')
  first_week_day=$(date --date="${ref_week} - ${this_week_day} day" '+%Y/%m/%d')

  week_day=$(get_week_beginning_day)
  assert_equals_helper 'The first day of this week' "$LINENO" "$first_week_day" "$week_day"
}

function date_to_format_Test()
{
  local formatted_date

  formatted_date=$(date_to_format '2020/3/1')
  assert_equals_helper 'Today' "$LINENO" "$formatted_date" '2020/03/01'

  formatted_date=$(date_to_format '2020/3/1' '+%Y/%m')
  assert_equals_helper 'Today' "$LINENO" "$formatted_date" '2020/03'

  formatted_date=$(date_to_format)
  today=$(date '+%Y/%m/%d')
  assert_equals_helper 'Today' "$LINENO" "$formatted_date" "$today"
}

invoke_shunit
