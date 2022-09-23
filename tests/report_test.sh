#!/bin/bash

include './src/report.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  cp -r "$SAMPLES_DIR"/pomodoro_data/* "$SHUNIT_TMPDIR"
  export KW_POMODORO_DATA="$SHUNIT_TMPDIR"
}

function setUp()
{
  declare -gA tags_details
}

function tearDown()
{
  unset tags_details
}

function test_parse_report_options()
{
  local output
  local expected_result
  local ref_date
  local ret

  # Default values
  parse_report_options '--day'
  expected_result=$(get_today_info '+%Y/%m/%d')
  assert_equals_helper 'Get today info' "$LINENO" "${options_values['DAY']}" "$expected_result"

  parse_report_options '--week'
  expected_result=$(get_week_beginning_day)
  assert_equals_helper 'Get this week info' "$LINENO" "${options_values['WEEK']}" "$expected_result"

  parse_report_options '--month'
  expected_result=$(get_today_info '+%Y/%m')
  assert_equals_helper 'Get this month info' "$LINENO" "${options_values['MONTH']}" "$expected_result"

  parse_report_options '--year'
  expected_result=$(get_today_info '+%Y')
  assert_equals_helper 'Get this year info' "$LINENO" "${options_values['YEAR']}" "$expected_result"

  # Values with parameters
  ## Days
  ref_date='1999/03/03'
  parse_report_options "--day=$ref_date"
  expected_result=$(date_to_format "$ref_date" '+%Y/%m/%d')
  assert_equals_helper "$ref_date is a valid date" "$LINENO" "${options_values['DAY']}" "$expected_result"

  ref_date='2022/04/32'
  output=$(parse_report_options "--day=$ref_date" 2> /dev/null)
  ret="$?"
  assert_equals_helper "$ref_date is an invalid date" "$LINENO" "$ret" 22

  ## Weeks
  ref_date='1990/04/10'
  parse_report_options "--week=$ref_date"
  expected_result=$(get_week_beginning_day "$ref_date")
  assert_equals_helper 'We expected 1990/04/04' "$LINENO" "${options_values['WEEK']}" "$expected_result"

  ref_date='2022/04/32'
  output=$(parse_report_options "--week=$ref_date" 2> /dev/null)
  ret="$?"
  assert_equals_helper "$ref_date is invalid" "$LINENO" "$ret" 22

  ## Month
  ref_date='1990/04'
  parse_report_options "--month=$ref_date"
  expected_result=$(date_to_format "$ref_date/01" '+%Y/%m')
  assert_equals_helper 'We expected 1990/04' "$LINENO" "${options_values['MONTH']}" "$expected_result"

  ref_date='1990/30'
  output=$(parse_report_options "--month=$ref_date" 2> /dev/null)
  ret="$?"
  assert_equals_helper 'Invalid date' "$LINENO" "$ret" 22

  # Invalid parameter
  ref_date='2022/04/12'
  output=$(parse_report_options "--month=$ref_date --day=$ref_date" 2> /dev/null)
  ret="$?"
  assert_equals_helper 'Invalid date' "$LINENO" "$ret" 22
}

function test_statistics()
{
  local msg
  local start_target_week
  local end_target_week

  declare -a expected_cmd=(
    'You have disable_statistics_data_track marked as "yes"'
    'If you want to see the statistics, change this option to "no"'
    '# Statistics:'
  )

  configurations[disable_statistics_data_track]='yes'
  output=$(report_main --statistics)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  configurations[disable_statistics_data_track]='no'

  # DAY
  msg=$'# Statistics: \nCurrently, kw does not have any data for the present date.'

  output=$(report_main --statistics --day)
  assertEquals "($LINENO)" "$msg" "$output"

  #WEEK
  start_target_week='2021/11/14'
  end_target_week='2021/11/20'
  msg=$(printf "# Statistics: \nSorry, kw does not have any data from %s to %s" "$start_target_week" "$end_target_week")

  output=$(report_main --statistics --week=2021/11/17)
  assertEquals "($LINENO)" "$msg" "$output"

  #MONTH
  msg=$'# Statistics: \nCurrently, kw does not have any data for the present month.'

  output=$(report_main --statistics --month)
  assertEquals "($LINENO)" "$msg" "$output"

  #YEAR
  msg=$'# Statistics: \nCurrently, kw does not have any data for the requested year.'

  output=$(report_main --statistics --year=2019)
  assertEquals "($LINENO)" "$msg" "$output"
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
  local expected

  # Here we use $'...' to evaluate the newline at the end of the strings
  declare -a expected_content=(
    $' - 2021/04/04\n   * [06:00:40-06:20:40][20m]: Tag 1 description\n'
    $' - 2021/04/04\n   * [08:30:50-08:45:50][15m]: Tag 2 description\n'
    $' - 2021/04/04\n   * [09:00:00-10:00:00][1h]: Tag 3 description\n'
    $' - 2021/04/04\n   * [11:00:00-11:00:44][44s]: Tag 4 description\n'
    $' - 2021/04/04\n   * [14:00:00-14:30:00][30m]: Tag 5 description\n'
    $' - 2021/04/04\n   * [15:00:00-15:10:00][10m]\n'
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
    assert_equals_helper "Loop $count failed" "$LINENO" "${tags_details[$tag]}" "$line"
    ((count++))
  done

  expected=$' - 2021/04/05\n   * [06:00:40-06:20:40][20m]: Description, with comma\n'
  grouping_day_data '2021/04/05'
  assert_equals_helper 'Did not parse commas correctly' "$LINENO" "${tags_details['comma_tag']}" "$expected"

  # Try to process file with bad data
  count=0
  declare -a expected_content=(
    $' - bad_data/2021/04/04\n   * [06:00:40-06:20:40][20m]: Tag 1 description\n'
    $' - bad_data/2021/04/04\n   * [09:00:00-10:00:00][1h]: Tag 3 description\n'
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
    assert_equals_helper "Loop $count failed" "$LINENO" "${tags_details[$tag]}" "$line"
    ((count++))
  done
}

function test_grouping_week_data()
{
  local fake_base_data='1815/12'
  local day_path

  # Create fake files just for test: 1815/12/10-1815/12/16
  mkdir -p "$SHUNIT_TMPDIR/$fake_base_data"
  for ((i = 10; i < 17; i++)); do
    day_path="$SHUNIT_TMPDIR/$fake_base_data/$i"
    touch "$day_path"
    printf '%s\n' "$i,20m,06:00:40,Tag $i description" > "$day_path"
  done

  grouping_week_data '1815/12/10'

  output="${#tags_details[@]}"
  assert_equals_helper 'We expect 7 keys' "$LINENO" "$output" 7

  # Check tags just in case
  for ((i = 10; i < 17; i++)); do
    value="${tags_details[$i]}"
    [[ -z "$value" ]] && fail "$LINENO:$i: We expect one tag per week day"
  done

  # Let's remove some files, and check an incomplete week
  unset tags_details
  declare -gA tags_details
  mkdir -p "$SHUNIT_TMPDIR/$fake_base_data"
  for ((i = 14; i < 17; i++)); do
    day_path="$SHUNIT_TMPDIR/$fake_base_data/$i"
    rm "$day_path"
  done

  grouping_week_data '1815/12/10'
  output="${#tags_details[@]}"
  assert_equals_helper 'We expect 4 keys' "$LINENO" "$output" 4
}

function test_grouping_month_data()
{
  local fake_base_data='1815/12'
  local day_path
  local month_total_days

  month_total_days=$(days_in_the_month 12 1815)
  # Create fake files just for test: 1815/12/10-1815/12/16
  mkdir -p "$SHUNIT_TMPDIR/$fake_base_data"
  for ((i = 1; i <= month_total_days; i++)); do
    day_path="$SHUNIT_TMPDIR/$fake_base_data/"$(printf "%02d\n" "$i")
    touch "$day_path"
    printf '%s\n' "$i,20m,06:00:40,Tag $i description" > "$day_path"
  done

  grouping_month_data '1815/12'

  output="${#tags_details[@]}"
  assert_equals_helper "We expect $month_total_days keys" "$LINENO" "$output" "$month_total_days"

  # Let's remove some files, and check an incomplete week
  unset tags_details
  declare -gA tags_details
  mkdir -p "$SHUNIT_TMPDIR/$fake_base_data"
  for ((i = 20; i < 24; i++)); do
    day_path="$SHUNIT_TMPDIR/$fake_base_data/"$(printf "%02d\n" "$i")
    rm "$day_path"
  done

  grouping_month_data '1815/12'
  output="${#tags_details[@]}"
  assert_equals_helper 'We expect 27 keys' "$LINENO" "$output" 27
}

function test_grouping_year_data()
{
  local fake_base_data=2016
  local day_path
  local month_total_days
  local current_day
  local current_month

  # Create fake files just for test: 1815/12/10-1815/12/16
  mkdir -p "$SHUNIT_TMPDIR/$fake_base_data"
  for ((month = 1; month <= 12; month++)); do
    current_month=$(printf "%02d\n" "$month")
    month_total_days=$(days_in_the_month "$month" "$fake_base_data")
    month_path=$(join_path "$fake_base_data" "$current_month")
    mkdir -p "$SHUNIT_TMPDIR/$month_path"
    for ((day = 1; day <= month_total_days; day++)); do
      current_day=$(printf "%02d\n" "$day")
      day_path="$SHUNIT_TMPDIR/$month_path/$current_day"
      touch "$day_path"
      printf '%s\n' "$month_path-$day,20m,06:00:40,Tag $month_path-$day description" > "$day_path"
    done
  done

  grouping_year_data '2016'

  output="${#tags_details[@]}"
  assert_equals_helper "We expect 366 (leap year) keys" "$LINENO" "$output" 366
}

function test_calculate_total_work_hours()
{
  local output
  local expected

  output=$(calculate_total_work_hours 1)
  expected='00:00:01'
  assert_equals_helper 'We expected 1 second' "$LINENO" "$output" "$expected"

  output=$(calculate_total_work_hours 60)
  expected='00:01:00'
  assert_equals_helper 'We expected 1 minute' "$LINENO" "$output" "$expected"

  output=$(calculate_total_work_hours 3600)
  expected='01:00:00'
  assert_equals_helper 'We expected 1 hour' "$LINENO" "$output" "$expected"

  output=$(calculate_total_work_hours 89999)
  expected='24:59:59'
  assert_equals_helper 'We expected full clock' "$LINENO" "$output" "$expected"

  output=$(calculate_total_work_hours 360000)
  expected='100:00:00'
  assert_equals_helper 'We expected 100 hours' "$LINENO" "$output" "$expected"
}

function test_show_data()
{
  local count=0
  local line
  local output

  grouping_day_data '2020/04/04'
  output=$(show_data)

  # Output can change multiple times. For this reason, I don't see a good
  # reason for a very detailed test on this function behavior. Let's just check
  # for a few keywords.

  assertTrue "$LINENO: We expected to find at least one Summary entry" '[[ "$output" =~ 'Summary:' ]]'
  assertTrue "$LINENO: We expected to find tag_2" '[[ "$output" =~ 'tag_2' ]]'
  assertTrue "$LINENO: We expected to find 06:00:40-" '[[ "$output" =~ '06:00:40-' ]]'

  grouping_day_data '2020/04/05'
  output=$(show_data)

  assertTrue "$LINENO: We expected to find per tag output over 24h" "[[ \"$output\" =~ 'time: 72:00:00' ]]"
}

function test_save_data_to()
{
  local output
  local expected

  grouping_day_data '2020/04/04'
  save_data_to "$SHUNIT_TMPDIR/test"
  [[ ! -f "$SHUNIT_TMPDIR/test" ]] && fail "$LINENO: We expect to find a test file"

  output=$(cat "$SHUNIT_TMPDIR/test")
  [[ ! "$output" =~ 'Summary:' ]] && fail "$LINENO: We expected to find at least one Summary entry"

  # Try to use an invalid path.
  output=$(save_data_to '/this/is/An/InvaLid/Path')
  ret="$?"
  assert_equals_helper "We expect an invalid path error" "$LINENO" "$ret" 1

  # Try to use a valid directory path.
  output=$(save_data_to './')
  ret="$?"
  assert_equals_helper "We expect a valid path" "$LINENO" "$ret" 0

  # Verifying that the correct message is displayed.
  expected='The report output was saved in:'
  message=${output::-16}
  assert_equals_helper "We expect a valid message" "$LINENO" "$message" "$expected"

  # Verifying that the correct filename is displayed.
  filename=${output:(-13)}
  [[ ! -f "./$filename" ]] && fail "$LINENO: We expect to find a test file"

  # Try to use an invalid root directory path.
  output=$(save_data_to '/root/')
  ret="$?"
  assert_equals_helper "We expect a root path invalid" "$LINENO" "$ret" 1

  # Try to use an invalid folder path error.
  output=$(save_data_to '/tmp/folder_not_created/')
  ret="$?"
  assert_equals_helper "We expect an invalid path error where the folder was not created." "$LINENO" "$ret" 1
}

invoke_shunit
