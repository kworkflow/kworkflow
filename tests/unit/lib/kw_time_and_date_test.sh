#!/usr/bin/env bash

include './src/lib/kw_time_and_date.sh'
include './tests/unit/utils.sh'

function setUp() {
	# Samples file data
	pre_total_sec="1846"
	pre_formated_sec="00:30:46"
}

function test_sec_to_format() {
	formatted_time=$(sec_to_format "$pre_total_sec")
	assertEquals "($LINENO)" "$pre_formated_sec" "$formatted_time"

	formatted_time=$(sec_to_format "")
	assertEquals "($LINENO)" '00:00:00' "$formatted_time"

	formatted_time=$(sec_to_format "$pre_total_sec" '+%M:%S')
	assertEquals "($LINENO)" '30:46' "$formatted_time"

	formatted_time=$(sec_to_format "$pre_total_sec" '+%S')
	assertEquals "($LINENO)" '46' "$formatted_time"
}

function test_secs_to_arbitrarily_long_hours_mins_secs() {
	local output
	local expected

	output=$(secs_to_arbitrarily_long_hours_mins_secs)
	assert_equals_helper 'Empty value should result in an error code' "$LINENO" 22 "$?"

	output=$(secs_to_arbitrarily_long_hours_mins_secs '123m4')
	assert_equals_helper 'Non-integer value should result in an error code' "$LINENO" 22 "$?"

	output=$(secs_to_arbitrarily_long_hours_mins_secs '9999 ')
	assert_equals_helper 'Non-integer value should result in an error code' "$LINENO" 22 "$?"

	output=$(secs_to_arbitrarily_long_hours_mins_secs ' 1111')
	assert_equals_helper 'Non-integer value should result in an error code' "$LINENO" 22 "$?"

	output=$(secs_to_arbitrarily_long_hours_mins_secs 0)
	expected='00:00:00'
	assert_equals_helper 'Wrong conversion' "$LINENO" "$expected" "$output"

	output=$(secs_to_arbitrarily_long_hours_mins_secs 3666)
	expected='01:01:06'
	assert_equals_helper 'Wrong conversion' "$LINENO" "$expected" "$output"

	output=$(secs_to_arbitrarily_long_hours_mins_secs 86400)
	expected='24:00:00'
	assert_equals_helper 'Wrong conversion' "$LINENO" "$expected" "$output"

	output=$(secs_to_arbitrarily_long_hours_mins_secs 10000000000000000)
	expected='2777777777777:46:40'
	assert_equals_helper 'Wrong conversion' "$LINENO" "$expected" "$output"
}

function test_get_today_info() {
	local today

	today=$(date +%Y/%m/%d)
	formatted_today=$(get_today_info '+%Y/%m/%d')
	assert_equals_helper 'Today info did not match' "$LINENO" "$today" "$formatted_today"

	today=$(date)
	formatted_today=$(get_today_info)

	if [[ "$today" != "$formatted_today" ]]; then
		today=$(date)
		formatted_today=$(get_today_info)
	fi

	assert_equals_helper 'No parameter' "$LINENO" "$today" "$formatted_today"
}

function test_get_week_beginning_day() {
	local ref_week='2021/05/19'
	local first_week_day='2021/05/16'
	local this_week_day

	week_day=$(get_week_beginning_day "$ref_week")
	assert_equals_helper 'First day of the week did not match' "$LINENO" "$first_week_day" "$week_day"

	week_day=$(get_week_beginning_day "$ref_week" '+%m/%d')
	assert_equals_helper 'Day format is wrong' "$LINENO" '05/16' "$week_day"

	week_day=$(get_week_beginning_day "$first_week_day")
	assert_equals_helper 'First day of the week did not match' "$LINENO" "$first_week_day" "$week_day"

	# No parameters, means this week
	ref_week=$(date '+%Y/%m/%d')
	this_week_day=$(date '+%w')
	first_week_day=$(date --date="${ref_week} - ${this_week_day} day" '+%Y/%m/%d')

	week_day=$(get_week_beginning_day)
	assert_equals_helper 'The first day of this week' "$LINENO" "$first_week_day" "$week_day"
}

function test_get_days_of_week() {
	local current_day
	local week_day
	local beginning_day_of_week
	local output
	local expected

	# No parameters passed. Default to current week
	current_day=$(date '+%Y/%m/%d')
	week_day=$(date '+%w')
	beginning_day_of_week=$(date --date="${current_day} - ${week_day} day" '+%Y/%m/%d')
	expected="${beginning_day_of_week}"
	for ((i = 1; i < 7; i++)); do
		day=$(date --date="${beginning_day_of_week} + ${i} day" '+%Y/%m/%d')
		expected+="|${day}"
	done
	output=$(get_days_of_week)
	assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

	# Test arbitrary week with default format
	expected='1990/04/01|1990/04/02|1990/04/03|1990/04/04|1990/04/05|1990/04/06|1990/04/07'
	output=$(get_days_of_week '1990/04/01')
	assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
	output=$(get_days_of_week '1990/04/07')
	assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
	output=$(get_days_of_week '1990/04/04')
	assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

	# Test arbitrary week with custom format
	expected='08/29|08/30|08/31|09/01|09/02|09/03|09/04'
	output=$(get_days_of_week '1880/08/29' '+%m/%d')
	assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
	output=$(get_days_of_week '1880/09/04' '+%m/%d')
	assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
	output=$(get_days_of_week '1880/09/02' '+%m/%d')
	assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

	# Test invalid date parameter
	expected='Invalid date 1880/09-02'
	output=$(get_days_of_week '1880/09-02' '+%m/%d')
	assert_equals_helper 'Invalid date parameter should return error code' "$LINENO" 1 "$?"
	assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
}

function test_date_to_format() {
	local formatted_date

	formatted_date=$(date_to_format '2020/3/1')
	assert_equals_helper 'Today' "$LINENO" '2020/03/01' "$formatted_date"

	formatted_date=$(date_to_format '2020/3/1' '+%Y/%m')
	assert_equals_helper 'Today' "$LINENO" '2020/03' "$formatted_date"

	formatted_date=$(date_to_format)
	today=$(date '+%Y/%m/%d')
	assert_equals_helper 'Today' "$LINENO" "$today" "$formatted_date"
}

function test_days_in_the_month() {
	local total_days
	local this_year
	local this_month
	local this_month_total_days
	local ret

	total_days=$(days_in_the_month 2 2021)
	assert_equals_helper 'We expect 28 days' "$LINENO" 28 "$total_days"

	total_days=$(days_in_the_month 02 2021)
	assert_equals_helper 'We expect 28 days' "$LINENO" 28 "$total_days"

	# Leap year, February has 29 days
	total_days=$(days_in_the_month 2 2016)
	assert_equals_helper 'We expect 29 days' "$LINENO" 29 "$total_days"

	total_days=$(days_in_the_month 2 300)
	assert_equals_helper 'We expect 28 days' "$LINENO" 28 "$total_days"

	# Leap year, February has 29 days
	total_days=$(days_in_the_month 2 1600)
	assert_equals_helper 'We expect 29 days' "$LINENO" 29 "$total_days"

	total_days=$(days_in_the_month 1 2016)
	assert_equals_helper 'We expect 31 days' "$LINENO" 31 "$total_days"

	total_days=$(days_in_the_month 6 2021)
	assert_equals_helper 'We expect 30 days' "$LINENO" 30 "$total_days"

	total_days=$(days_in_the_month 9 2021)
	assert_equals_helper 'We expect 30 days' "$LINENO" 30 "$total_days"

	total_days=$(days_in_the_month 09 2021)
	assert_equals_helper 'We expect 30 days' "$LINENO" 30 "$total_days"

	total_days=$(days_in_the_month 8 2021)
	assert_equals_helper 'We expect 31 days' "$LINENO" 31 "$total_days"

	# Empty year should be converted to the present year
	total_days=$(days_in_the_month 8)
	assert_equals_helper 'Use this year' "$LINENO" 31 "$total_days"

	# An invalid month
	days_in_the_month 333
	ret="$?"
	assert_equals_helper 'Invalid month' "$LINENO" 22 "$ret"

	days_in_the_month -5
	ret="$?"
	assert_equals_helper 'Invalid month' "$LINENO" 22 "$ret"

	days_in_the_month -09
	ret="$?"
	assert_equals_helper 'Invalid month' "$LINENO" 22 "$ret"

	days_in_the_month -009
	ret="$?"
	assert_equals_helper 'Invalid month' "$LINENO" 22 "$ret"
}

function test_timebox_to_sec() {
	local output

	timebox_to_sec 'invalid' >/dev/null 2>&1
	assert_equals_helper 'Invalid timebox should return error code' "$LINENO" 22 "$?"

	timebox_to_sec '11mm' >/dev/null 2>&1
	assert_equals_helper 'Invalid timebox should return error code' "$LINENO" 22 "$?"

	timebox_to_sec '12345h ' >/dev/null 2>&1
	assert_equals_helper 'Invalid timebox should return error code' "$LINENO" 22 "$?"

	timebox_to_sec ' 987654321s' >/dev/null 2>&1
	assert_equals_helper 'Invalid timebox should return error code' "$LINENO" 22 "$?"

	output=$(timebox_to_sec '2718281828s')
	assert_equals_helper 'Amount in seconds should be the same' "$LINENO" '2718281828' "$output"

	output=$(timebox_to_sec '12m')
	assert_equals_helper 'Wrong conversion of minutes to seconds' "$LINENO" '720' "$output"

	output=$(timebox_to_sec '5h')
	assert_equals_helper 'Wrong conversion of hours to seconds' "$LINENO" '18000' "$output"

	output=$(timebox_to_sec '9999999h')
	assert_equals_helper 'Wrong conversion of hours to seconds' "$LINENO" '35999996400' "$output"

	output=$(timebox_to_sec '0m')
	assert_equals_helper 'Null amount of time should return zero seconds' "$LINENO" '0' "$output"
}

invoke_shunit
