#!/bin/bash

include './src/kw_time_and_date.sh'
include './tests/utils.sh'

function setUp()
{
  # Samples file data
  pre_total_sec="1846"
  pre_formated_sec="00:30:46"
}

function test_sec_to_format()
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

function test_get_today_info()
{
  local today

  today=$(date +%Y/%m/%d)
  formated_today=$(get_today_info '+%Y/%m/%d')
  assert_equals_helper 'Today info did not match' "$LINENO" "$today" "$formated_today"

  formated_today=$(get_today_info)
  today=$(date)
  assert_equals_helper 'No parameter' "$LINENO" "$today" "$formated_today"
}

function test_get_week_beginning_day()
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

function test_date_to_format()
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

function test_days_in_the_month()
{
  local total_days
  local this_year
  local this_month
  local this_month_total_days
  local ret

  # Leap year, February has 29 days
  total_days=$(days_in_the_month 2 2016)
  assert_equals_helper 'We expect 29 days' "$LINENO" "$total_days" 29

  total_days=$(days_in_the_month 6 2021)
  assert_equals_helper 'We expect 30 days' "$LINENO" "$total_days" 30

  total_days=$(days_in_the_month 8 2021)
  assert_equals_helper 'We expect 31 days' "$LINENO" "$total_days" 31

  # Empty year should be converted to the present year
  total_days=$(days_in_the_month 8)
  assert_equals_helper 'Use this year' "$LINENO" "$total_days" 31

  # Empty year should be converted to the present year
  total_days=$(days_in_the_month)
  this_year=$(date +%Y)
  this_month=$(date +%m)
  this_month_total_days=$(cal "$this_month" "$this_year" | awk 'NF {DAYS = $NF}; END {print DAYS}')
  assert_equals_helper 'Use the current month' "$LINENO" "$total_days" "$this_month_total_days"

  # An invalid month
  days_in_the_month 333
  ret="$?"
  assert_equals_helper 'Invalid month' "$LINENO" "$ret" 22
}

invoke_shunit
