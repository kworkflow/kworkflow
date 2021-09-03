#!/bin/bash

include './src/statistics.sh'
include './tests/utils.sh'

# Pre-calculated:
# Values: "9433 8750 4316 13 18 145 107 282 45 13 57 37 4 44"
# Average: 14
# Min: 4
# Max: 9433
function setUp()
{
  export KW_DATA_DIR='tests/samples'

  # Samples file data
  base_statistics='tests/samples/statistics/2020'
  sample_total='19'
  sample_build_avg='00:00:23' #23
  sample_build_min='00:00:06' #6
  sample_build_max='00:03:40' #220
  build_output="$sample_total $sample_build_max $sample_build_min $sample_build_avg"

  sample_deploy_total='8'
  sample_deploy_avg='00:01:04' #23
  sample_deploy_min='00:00:31' #6
  sample_deploy_max='00:01:13' #220
  deploy_output="$sample_deploy_total $sample_deploy_max $sample_deploy_min $sample_deploy_avg"

  pre_values='9433 8750 4316 13 18 145 107 282 45 13 57 37 4 44'
  pre_min='4'
  pre_max='9433'
  pre_avg='1661'
  pre_total='14'
  pre_total_sec='1846'
  pre_formated_sec='00:30:46'

  declare -ga may_27_2020=(
    'Deploy             8 00:01:13 00:00:31 00:01:04'
    'Build             19 00:03:40 00:00:06 00:00:23'
  )
}

function test_statistics()
{
  local msg

  declare -a expected_cmd=(
    'You have disable_statistics_data_track marked as "yes"'
    'If you want to see the statistics, change this option to "no"'
  )

  configurations[disable_statistics_data_track]='yes'
  output=$(statistics --)
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  configurations[disable_statistics_data_track]='no'

  output=$(statistics --invalid-option)
  msg='Invalid parameter: --invalid-option'
  assertEquals "($LINENO)" "$msg" "$output"

  output=$(statistics --day not_a_day 2> /dev/null)
  msg='Invalid parameter: not_a_day'
  assertEquals "($LINENO)" "$msg" "$output"

  output=$(statistics --month 13 2> /dev/null)
  msg='Invalid parameter: 13'
  assertEquals "($LINENO)" "$msg" "$output"

  output=$(statistics --month not_a_month 2> /dev/null)
  msg='Invalid parameter: not_a_month'
  assertEquals "($LINENO)" "$msg" "$output"

  output=$(statistics --year -2021 2> /dev/null)
  msg='Invalid parameter: -2021'
  assertEquals "($LINENO)" "$msg" "$output"

  output=$(statistics --year not_a_year 2> /dev/null)
  msg='Invalid parameter: not_a_year'
  assertEquals "($LINENO)" "$msg" "$output"

  output=$(statistics)
  msg='Currently, kw does not have any data for the present date.'
  assertEquals "($LINENO)" "$msg" "$output"
}

function test_calculate_average()
{
  avg=$(calculate_average "10")
  assertEquals "($LINENO)" "10" "$avg"

  avg=$(calculate_average "$pre_values")
  assertEquals "($LINENO)" "$pre_avg" "$avg"
}

function test_calculate_total_of_data()
{
  total=$(calculate_total_of_data "1")
  assertEquals "($LINENO)" "1" "$total"

  total=$(calculate_total_of_data "")
  assertEquals "($LINENO)" "0" "$total"

  total=$(calculate_total_of_data "$pre_values")
  assertEquals "($LINENO)" "$pre_total" "$total"
}

function test_max_value()
{
  max=$(max_value "0")
  assertEquals "($LINENO)" "$max" "0"

  max=$(max_value "")
  assertEquals "($LINENO)" "$max" "0"

  max=$(max_value "$pre_values")
  assertEquals "($LINENO)" "$pre_max" "$max"
}

function test_min_value()
{
  min=$(min_value "0" "0")
  assertEquals "($LINENO)" "$min" "0"

  min=$(min_value "" "")
  assertEquals "($LINENO)" "$min" ""

  min=$(min_value "$pre_values" "$pre_max")
  assertEquals "($LINENO)" "$min" "$pre_min"
}

# Note: The weekly, monthly, and yearly calculation uses `basic_data_process`.
# These functions only concatenate the set of values before invoke
# `basic_data_process`, for this reason, there is no point to validate this
# operation in the weekly, monthly, and yearly tests.
function test_basic_data_process()
{
  local data
  local day_path="$base_statistics/05/27"

  data=$(cat "$day_path")

  basic_data_process "$data"
  build="${shared_data["build"]}"
  assertEquals "($LINENO)" "$build_output" "$build"

  basic_data_process "$data"
  deploy="${shared_data["deploy"]}"
  assertEquals "($LINENO)" "$deploy_output" "$deploy"

  basic_data_process "$data"
  deploy="${shared_data["list"]}"
  assertEquals "($LINENO)" "" "$deploy"
}

function test_day_statistics()
{
  local day_data
  local msg1='Currently, kw does not have any data for the present date.'
  local msg2='There is no data in the kw records'

  day_data=$(day_statistics -14)
  assertEquals "($LINENO)" "$msg1" "$day_data"

  day_data=$(day_statistics 2020/05/28)
  assertEquals "($LINENO)" "$msg2" "$day_data"

  day_data=$(day_statistics 2020/05/27 | tail -n 2)
  compare_command_sequence 'may_27_2020' "$day_data" "$LINENO"
}

function test_week_statistics()
{
  local day_data
  local week_data
  local start_target_week='2019/05/05'
  local end_target_week='2019/05/11'
  local msg="Sorry, kw does not have any data from $start_target_week to $end_target_week"

  week_data=$(week_statistics "$start_target_week" "$end_target_week")
  assertEquals "($LINENO)" "$msg" "$week_data"

  week_data=$(week_statistics 2020/05/25 | tail -n 2)
  compare_command_sequence 'may_27_2020' "$week_data" "$LINENO"
}

function test_month_statistics()
{
  local target_month='2019/05'
  local month_data
  local msg='Currently, kw does not have any data for the present month.'

  month_data=$(month_statistics "$target_month")
  assertEquals "($LINENO)" "$msg" "$month_data"

  month_data=$(month_statistics 2020/05 | tail -n 2)
  compare_command_sequence 'may_27_2020' "$month_data" "$LINENO"

  mkdir -p "$base_statistics/04"
  msg='Sorry, kw does not have any record for 2020/04'
  month_data=$(month_statistics 2020/04)
  assertEquals "($LINENO)" "$msg" "$month_data"
  rm -rf "$base_statistics/04"
}

function test_year_statistics()
{
  local target_year='2019'
  local year_data
  local msg='Currently, kw does not have any data for the requested year.'

  year_data=$(year_statistics "$target_year")
  assertEquals "($LINENO)" "$msg" "$year_data"

  year_data=$(year_statistics 2020 | tail -n 2)
  compare_command_sequence 'may_27_2020' "$year_data" "$LINENO"

  declare -a expected_cmd=(
    'Deploy             1 00:00:21 00:00:21 00:00:21'
    'Build              3 00:00:55 00:00:01 00:00:19'
    'List               2 00:00:08 00:00:00 00:00:04'
    'Uninstall          3 00:00:03 00:00:02 00:00:02'
    'Build_failure      1 00:00:01 00:00:01 00:00:01'
  )

  year_data=$(year_statistics 2021 | tail -n 5)
  compare_command_sequence 'expected_cmd' "$year_data" "$LINENO"
}

invoke_shunit
