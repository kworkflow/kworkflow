#!/bin/bash

include './src/report.sh'
include './tests/utils.sh'

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

invoke_shunit
