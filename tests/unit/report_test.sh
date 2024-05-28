#!/usr/bin/env bash

include './src/report.sh'
include './src/lib/kw_db.sh'
include './tests/unit/utils.sh'

function oneTimeSetUp()
{
  declare -g DB_FILES
  DB_FILES="$(realpath './tests/unit/samples/db_files/report')"
  export KW_DATA_DIR="${SHUNIT_TMPDIR}"
  KW_DB_DIR="$(realpath './database')"
}

function setUp()
{
  declare -gA options_values
  declare -g target_period

  # Statistics data structures
  declare -g statistics_raw_data
  declare -gA statistics=(['deploy']='' ['build']='' ['list']='' ['uninstall']='' ['modules_deploy']='')

  # Pomodoro data structures
  declare -g pomodoro_raw_data
  declare -gA pomodoro_sessions
  declare -gA pomodoro_metadata

  setupDatabase
}

function tearDown()
{
  unset options_values
  unset target_period
  unset statistics_raw_data
  unset statistics
  unset pomodoro_raw_data
  unset pomodoro_sessions
  unset pomodoro_metadata

  teardownDatabase
}

function setupDatabase()
{
  execute_sql_script "${KW_DB_DIR}/kwdb.sql" > /dev/null 2>&1
}

function teardownDatabase()
{
  is_safe_path_to_remove "${KW_DATA_DIR}/kw.db"
  if [[ "$?" == 0 ]]; then
    rm "${KW_DATA_DIR}/kw.db"
  fi
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
  expected_result=$(get_days_of_week)
  assert_equals_helper 'Get this week info' "$LINENO" "${options_values['WEEK']}" "$expected_result"

  parse_report_options '--month'
  expected_result=$(get_today_info '+%Y/%m')
  assert_equals_helper 'Get this month info' "$LINENO" "${options_values['MONTH']}" "$expected_result"

  parse_report_options '--year'
  expected_result=$(get_today_info '+%Y')
  assert_equals_helper 'Get this year info' "$LINENO" "${options_values['YEAR']}" "$expected_result"

  parse_report_options '--verbose'
  assert_equals_helper 'Show a detailed output' "$LINENO" "${options_values['VERBOSE']}" '1'

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
  expected_result=$(get_days_of_week "$ref_date")
  assert_equals_helper 'We expected all days of week' "$LINENO" "${options_values['WEEK']}" "$expected_result"

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
  local current_day
  local current_month

  current_day=$(date '+%Y/%m/%d')
  current_month=$(date '+%Y/%m')

  declare -a expected_cmd=(
    'You have "disable_statistics_data_track" marked as "yes"'
    'If you want to track statistics, change this option to "no"'
    "kw doesn't have any statistics of the target period: day ${current_day}"
  )

  configurations[disable_statistics_data_track]='yes'
  output=$(report_main --statistics)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  configurations[disable_statistics_data_track]='no'

  # DAY
  msg="kw doesn't have any statistics of the target period: day ${current_day}"

  output=$(report_main --statistics --day)
  assertEquals "($LINENO)" "$msg" "$output"

  # WEEK
  start_target_week='2021/11/14'
  msg="kw doesn't have any statistics of the target period: week of day ${start_target_week}"

  output=$(report_main --statistics --week=2021/11/17)
  assertEquals "($LINENO)" "$msg" "$output"

  # MONTH
  msg="kw doesn't have any statistics of the target period: month ${current_month}"

  output=$(report_main --statistics --month)
  assertEquals "($LINENO)" "$msg" "$output"

  # YEAR
  msg='kw doesn'"'"'t have any statistics of the target period: year 2019'

  output=$(report_main --statistics --year=2019)
  assertEquals "($LINENO)" "$msg" "$output"
}

function test_pomodoro()
{
  local start_target_week
  local current_day
  local current_month
  local expected

  current_day=$(date '+%Y/%m/%d')
  current_month=$(date '+%Y/%m')

  # DAY
  expected="kw doesn't have any Pomodoro data of the target period: day ${current_day}"

  output=$(report_main --pomodoro --day)
  assert_equals_helper 'Wrong error output' "$LINENO" "$expected" "$output"

  # WEEK
  start_target_week='2021/11/14'
  expected="kw doesn't have any Pomodoro data of the target period: week of day ${start_target_week}"

  output=$(report_main --pomodoro --week=2021/11/17)
  assert_equals_helper 'Wrong error output' "$LINENO" "$expected" "$output"

  # MONTH
  expected="kw doesn't have any Pomodoro data of the target period: month ${current_month}"

  output=$(report_main --pomodoro --month)
  assert_equals_helper 'Wrong error output' "$LINENO" "$expected" "$output"

  # YEAR
  expected='kw doesn'"'"'t have any Pomodoro data of the target period: year 2019'

  output=$(report_main --pomodoro --year=2019)
  assert_equals_helper 'Wrong error output' "$LINENO" "$expected" "$output"
}

function test_set_raw_data_target_period_setting()
{

  # Test setting of target period for day
  options_values['DAY']='1970/01/01'
  set_raw_data
  options_values['DAY']=''
  assert_equals_helper 'Wrong set of target period' "$LINENO" 'day 1970/01/01' "${target_period}"

  # Test setting of target period for week
  options_values['WEEK']='1969/12/28|1969/12/29|1969/12/30|1969/12/31|1970/01/01|1970/01/02|1970/01/03'
  set_raw_data
  options_values['WEEK']=''
  assert_equals_helper 'Wrong set of target period' "$LINENO" 'week of day 1969/12/28' "${target_period}"

  # Test setting of target period for day
  options_values['MONTH']='1970/01'
  set_raw_data
  options_values['MONTH']=''
  assert_equals_helper 'Wrong set of target period' "$LINENO" 'month 1970/01' "${target_period}"

  # Test setting of target period for day
  options_values['YEAR']='1970'
  set_raw_data
  options_values['YEAR']=''
  assert_equals_helper 'Wrong set of target period' "$LINENO" 'year 1970' "${target_period}"
}

function test_set_raw_data_setting_raw_data()
{
  local expected

  # See the file tests/unit/samples/db-files/report/statistics_and_pomodoro_insert.sql
  # for context of the next tests.
  sqlite3 "${KW_DATA_DIR}/kw.db" < "${DB_FILES}/statistics_and_pomodoro_insert.sql"

  options_values['STATISTICS']=''
  options_values['YEAR']='1970'
  set_raw_data
  options_values['YEAR']=''
  assert_equals_helper 'set_raw_data without statistics flag should not set statistics_raw_data' "$LINENO" '' "${statistics_raw_data}"

  options_values['POMODORO']=''
  options_values['YEAR']='1970'
  set_raw_data
  options_values['YEAR']=''
  assert_equals_helper 'set_raw_data without Pomodoro flag should not set pomodoro_raw_data' "$LINENO" '' "${pomodoro_raw_data}"

  options_values['STATISTICS']=1
  options_values['POMODORO']=1

  options_values['DAY']='1998/04/17'
  set_raw_data
  options_values['DAY']=''
  expected='4|deploy|success|1998-04-17|12:12:12|1'
  assert_equals_helper 'Wrong statistics_raw_data set for day 1998/04/17' "$LINENO" "$expected" "${statistics_raw_data}"

  options_values['WEEK']='1998/04/12|1998/04/13|1998/04/14|1998/04/15|1998/04/16|1998/04/17|1998/04/18'
  set_raw_data
  options_values['WEEK']=''
  expected='2|list|unknown|1998-04-12|12:12:12|1'$'\n'
  expected+='3|list|failure|1998-04-14|12:12:12|1'$'\n'
  expected+='4|deploy|success|1998-04-17|12:12:12|1'$'\n'
  expected+='5|list|interrupted|1998-04-18|12:12:12|1'
  assert_equals_helper 'Wrong statistics_raw_data set for week of day 1998/04/12' "$LINENO" "$expected" "${statistics_raw_data}"

  options_values['WEEK']='1998/04/05|1998/04/06|1998/04/07|1998/04/08|1998/04/09|1998/04/10|1998/04/11'
  set_raw_data
  options_values['WEEK']=''
  expected='12|1|tag1|1998-04-10|12:12:12|1234|someDescription'
  assert_equals_helper 'Wrong pomodoro_raw_data set for week of day 1998/04/05' "$LINENO" "$expected" "${pomodoro_raw_data}"

  options_values['MONTH']='1998/05'
  set_raw_data
  options_values['MONTH']=''
  expected='17|3|tag3|1998-05-17|12:12:12|1234|someDescription'$'\n'
  expected+='18|3|tag3|1998-05-18|12:12:12|1234|someDescription'
  assert_equals_helper 'Wrong pomodoro_raw_data set for month 1998/05' "$LINENO" "$expected" "${pomodoro_raw_data}"

  options_values['YEAR']='1923'
  set_raw_data
  options_values['YEAR']=''
  expected='8|modules_deploy|success|1923-04-17|12:12:12|1'$'\n'
  expected+='9|list|interrupted|1923-04-18|12:12:12|1'$'\n'
  expected+='10|build|success|1923-12-01|12:12:12|1'
  assert_equals_helper 'Wrong statistics_raw_data set for year 1923' "$LINENO" "$expected" "${statistics_raw_data}"
}

function test_get_raw_data_from_period_of_time()
{
  local output
  local expected

  # See the file tests/unit/samples/db-files/report/fake_entity_insert.sql
  # for context of the next tests.
  sqlite3 "${KW_DATA_DIR}/kw.db" < "${DB_FILES}/fake_entity_insert.sql"

  output=$(get_raw_data_from_period_of_time 'fake_entity' "'^2023-01-01$'")
  expected='1|2023-01-01'
  assert_equals_helper 'Wrong output for exact day 2023/01/01' "$LINENO" "$expected" "$output"

  output=$(get_raw_data_from_period_of_time 'fake_entity' "'^2023-01-02|2023-02-01$'")
  expected='2|2023-01-02'$'\n''3|2023-02-01'
  assert_equals_helper 'Wrong output for day 2023/01/02 or 2023/02/01' "$LINENO" "$expected" "$output"

  output=$(get_raw_data_from_period_of_time 'fake_entity' "'^1930-11-..$'")
  expected='4|1930-11-08'$'\n''5|1930-11-12'$'\n''6|1930-11-29'
  assert_equals_helper 'Wrong output for any day of month 1930/11' "$LINENO" "$expected" "$output"

  output=$(get_raw_data_from_period_of_time 'fake_entity' "'^1945-..-..$'")
  expected='7|1945-04-07'$'\n''8|1945-08-15'$'\n''9|1945-12-03'
  assert_equals_helper 'Wrong output for any day of year 1945' "$LINENO" "$expected" "$output"
}

function test_process_and_format_statistics_raw_data_without_data()
{
  target_period='1998/04/17'
  statistics_raw_data=''
  process_and_format_statistics_raw_data
  assert_equals_helper 'Should result in an error code' "$LINENO" 2 "$?"
}

function test_process_and_format_statistics_raw_data_with_data()
{
  local expected

  # Add 'list' entries
  statistics_raw_data='1|list|success|1970-01-01|00:00:00|5400'$'\n'
  statistics_raw_data+='2|list|success|1970-01-01|00:00:00|7200'$'\n'
  statistics_raw_data+='3|list|success|1970-01-01|00:00:00|7200'$'\n'
  statistics_raw_data+='4|list|success|1970-01-01|00:00:00|3600'$'\n'
  statistics_raw_data+='5|list|success|1970-01-01|00:00:00|3600'$'\n'
  # Add 'build' entries
  statistics_raw_data+='6|build|success|1970-01-01|00:00:00|1'$'\n'
  statistics_raw_data+='7|build|success|1970-01-01|00:00:00|2'$'\n'
  statistics_raw_data+='8|build|success|1970-01-01|00:00:00|3'$'\n'
  statistics_raw_data+='9|build|success|1970-01-01|00:00:00|4'$'\n'
  statistics_raw_data+='10|build|success|1970-01-01|00:00:00|5'$'\n'
  # Add 'deploy' entries
  statistics_raw_data+='11|deploy|success|1970-01-01|00:00:00|36000'$'\n'
  statistics_raw_data+='12|deploy|success|1970-01-01|00:00:00|36000'$'\n'
  statistics_raw_data+='13|deploy|success|1970-01-01|00:00:00|36000'$'\n'
  statistics_raw_data+='14|deploy|success|1970-01-01|00:00:00|36000'$'\n'
  statistics_raw_data+='15|deploy|success|1970-01-01|00:00:00|36000'$'\n'
  # Add 'modules_deploy' entries
  statistics_raw_data+='16|modules_deploy|success|1970-01-01|00:00:00|1708'$'\n'
  statistics_raw_data+='17|modules_deploy|success|1970-01-01|00:00:00|30996'$'\n'
  statistics_raw_data+='18|modules_deploy|success|1970-01-01|00:00:00|56'$'\n'
  statistics_raw_data+='19|modules_deploy|success|1970-01-01|00:00:00|19809'$'\n'
  statistics_raw_data+='20|modules_deploy|success|1970-01-01|00:00:00|113'$'\n'
  # Add 'uninstall' entries
  statistics_raw_data+='21|uninstall|success|1970-01-01|00:00:00|0'$'\n'
  statistics_raw_data+='22|uninstall|success|1970-01-01|00:00:00|0'$'\n'
  statistics_raw_data+='23|uninstall|success|1970-01-01|00:00:00|0'$'\n'
  statistics_raw_data+='24|uninstall|success|1970-01-01|00:00:00|0'$'\n'
  statistics_raw_data+='25|uninstall|success|1970-01-01|00:00:00|0'

  process_and_format_statistics_raw_data

  expected='List               5 02:00:00 01:00:00 01:30:00'
  assert_equals_helper 'Wrong processing and formatting for List' "$LINENO" "$expected" "${statistics['list']}"

  expected='Build              5 00:00:05 00:00:01 00:00:03'
  assert_equals_helper 'Wrong processing and formatting for Build' "$LINENO" "$expected" "${statistics['build']}"

  expected='Deploy             5 10:00:00 10:00:00 10:00:00'
  assert_equals_helper 'Wrong processing and formatting for Deploy' "$LINENO" "$expected" "${statistics['deploy']}"

  expected='Modules_deploy     5 08:36:36 00:00:56 02:55:36'
  assert_equals_helper 'Wrong processing and formatting for Modules_deploy' "$LINENO" "$expected" "${statistics['modules_deploy']}"

  expected='Uninstall          5 00:00:00 00:00:00 00:00:00'
  assert_equals_helper 'Wrong processing and formatting for Uninstall' "$LINENO" "$expected" "${statistics['uninstall']}"
}

function test_process_and_format_pomodoro_raw_data_without_data()
{
  target_period='day 1998/04/17'
  pomodoro_raw_data=''
  process_and_format_pomodoro_raw_data
  assert_equals_helper 'Should result in an error code' "$LINENO" 2 "$?"
}

function test_process_and_format_pomodoro_raw_data_with_data()
{
  local expected
  local yellow
  local green
  local normal

  # Set color codes for comparing output
  yellow=$(tput setaf 3)
  green=$(tput setaf 2)
  normal=$(tput sgr0)

  # Population the Pomodoro data structures
  pomodoro_raw_data='1|1|tag1|1970-01-01|00:00:00|3600|someDescription'$'\n'
  pomodoro_raw_data+='2|2|tag2|1600-02-29|21:11:12|72000|someDescription'$'\n'
  pomodoro_raw_data+='3|3|tag3|1600-02-29|21:11:12|48000|someDescription'$'\n'
  pomodoro_raw_data+='4|1|tag1|2012-12-31|23:58:00|132|'$'\n'
  pomodoro_raw_data+='5|1|tag1|2023-04-24|12:05:17|30|anotherDescription'
  process_and_format_pomodoro_raw_data

  # Tests for a single tag sessions and metadata
  expected="    (${yellow}1970-01-01 ${green}00:00:00->01:00:00${normal}) [Duration 01:00:00]: someDescription"$'\n'
  expected+="    (${yellow}2012-12-31 ${green}23:58:00->00:00:12${normal}) [Duration 00:02:12]: "$'\n'
  expected+="    (${yellow}2023-04-24 ${green}12:05:17->12:05:47${normal}) [Duration 00:00:30]: anotherDescription"$'\n'
  assert_equals_helper 'Wrong processing and formatting for tag1 sessions' "$LINENO" "$expected" "${pomodoro_sessions['tag1']}"
  expected='- Total focus time: 01:02:42'$'\n'
  expected+='- Number of sessions: 3'
  assert_equals_helper 'Wrong processing and formatting for tag1 metadata' "$LINENO" "$expected" "${pomodoro_metadata['tag1']}"

  # Test for all tags metadata
  expected='- Total focus time from all tags: 34:22:42'$'\n'
  expected+='- Number of sessions from all tags: 5'
  assert_equals_helper 'Wrong processing and formatting for all tags metadata' "$LINENO" "$expected" "${pomodoro_metadata['ALL_TAGS']}"
}

function test_show_report()
{
  local output
  local expected
  local expected_statistics
  local expected_pomodoro

  target_period='year 2007'

  # Expect no output
  options_values['STATISTICS']=''
  options_values['POMODORO']=''
  output=$(show_report)
  assert_equals_helper 'With statistics and Pomodoro flags unset, output should be empty' "$LINENO" '' "$output"

  # Error message for statistics
  options_values['STATISTICS']=1
  statistics_raw_data=''
  output=$(show_report)
  expected="kw doesn't have any statistics of the target period: ${target_period}"
  assert_equals_helper 'No statistics should result in error message' "$LINENO" "$expected" "$output"

  # Error message for Pomodoro
  options_values['STATISTICS']=''
  options_values['POMODORO']=1
  pomodoro_raw_data=''
  output=$(show_report)
  expected="kw doesn't have any Pomodoro data of the target period: ${target_period}"
  assert_equals_helper 'No Pomodoro data should result in error message' "$LINENO" "$expected" "$output"

  # Expect output for statistics
  options_values['POMODORO']=''
  options_values['STATISTICS']=1
  statistics_raw_data=1
  statistics['fake_command1']='fake data 1'
  statistics['fake_command2']=''
  statistics['fake_command3']='fake data 3'
  output=$(show_report)
  expected_statistics='# Statistics Report: year 2007'$'\n'
  expected_statistics+='               Total  Max      Min      Average'$'\n'
  expected_statistics+='fake data 1'$'\n'
  expected_statistics+='fake data 3'
  assert_equals_helper 'Wrong statistics output' "$LINENO" "${expected_statistics}" "$output"

  # Expect output for Pomodoro
  options_values['STATISTICS']=''
  options_values['POMODORO']=1
  pomodoro_raw_data=1
  pomodoro_sessions['tag1']='fake session 1'
  pomodoro_metadata['tag1']='fake metadata 1'
  pomodoro_sessions['tag2']='fake session 2'
  pomodoro_metadata['tag2']='fake metadata 2'
  pomodoro_metadata['ALL_TAGS']='fake metadata all tags'
  output=$(show_report)
  expected_pomodoro='# Pomodoro Report: year 2007'$'\n''fake metadata all tags'$'\n'$'\n'
  expected_pomodoro+='## tag1'$'\n''fake metadata 1'$'\n''- Sessions:'$'\n''fake session 1'$'\n'
  expected_pomodoro+='## tag2'$'\n''fake metadata 2'$'\n''- Sessions:'$'\n''fake session 2'
  assert_equals_helper 'Wrong Pomodoro output' "$LINENO" "${expected_pomodoro}" "$output"

  # Expect output for statistics and Pomodoro
  options_values['STATISTICS']=1
  output=$(show_report)
  expected="${expected_statistics}"$'\n'$'\n'"${expected_pomodoro}"
  assert_equals_helper 'Wrong statistics and Pomodoro output' "$LINENO" "$expected" "$output"
}

function test_save_data_to()
{
  local output
  local expected
  local ret
  local yellow
  local green
  local normal

  # Set color codes for comparing output
  yellow=$(tput setaf 3)
  green=$(tput setaf 2)
  normal=$(tput sgr0)

  # Prepare options
  options_values['MONTH']='1998/04'
  options_values['STATISTICS']=1
  options_values['POMODORO']=1

  # Populate database and data structures
  sqlite3 "${KW_DATA_DIR}/kw.db" < "${DB_FILES}/statistics_and_pomodoro_insert.sql"
  set_raw_data
  process_and_format_statistics_raw_data
  process_and_format_pomodoro_raw_data

  # Use valid path to create valid report file
  save_data_to "${SHUNIT_TMPDIR}/test" > /dev/null 2>&1

  assertTrue "(${LINENO}) We expect to find a test file" "[[ -f ${SHUNIT_TMPDIR}/test ]]"

  # Test contents of valid report file
  output=$(< "${SHUNIT_TMPDIR}/test")
  expected='# Statistics Report: month 1998/04'
  assertTrue "(${LINENO}) We expect to find the statistics report header" "[[ '${output}' =~ '${expected}' ]]"
  expected='               Total  Max      Min      Average'
  assertTrue "(${LINENO}) We expect to find statistics values header" "[[ '${output}' =~ '${expected}' ]]"
  expected='List               3 00:00:01 00:00:01 00:00:01'
  assertTrue "(${LINENO}) Wrong values for 'List' command" "[[ '${output}' =~ '${expected}' ]]"
  expected='# Pomodoro Report: month 1998/04'
  assertTrue "(${LINENO}) We expect to find the Pomodoro report header" "[[ '${output}' =~ '${expected}' ]]"
  expected='- Total focus time from all tags: 01:42:50'$'\n''- Number of sessions from all tags: 5'
  assertTrue "(${LINENO}) Wrong all tags metadata" "[[ '${output}' =~ '${expected}' ]]"
  expected='## tag1'$'\n''- Total focus time: 00:41:08'$'\n''- Number of sessions: 2'
  assertTrue "(${LINENO}) Wrong tag1 metadata" "[[ '${output}' =~ '${expected}' ]]"
  expected="    (${yellow}1998-04-12 ${green}12:12:12->12:32:46${normal}) [Duration 00:20:34]: someDescription"
  assertTrue "(${LINENO}) Wrong tag1 metadata" "[[ '${output}' =~ '${expected}' ]]"

  # Try to use an invalid path.
  output=$(save_data_to '/this/is/An/InvaLid/Path')
  ret="$?"
  assert_equals_helper 'We expect an invalid path error' "$LINENO" 1 "$ret"

  # Try to use a valid path to directory.
  output=$(save_data_to "${SHUNIT_TMPDIR}")
  ret="$?"
  assert_equals_helper 'We expect a directory path to be valid' "$LINENO" 0 "$ret"

  # Verifying that the correct message is displayed.
  expected="The report output was saved in: ${SHUNIT_TMPDIR}/report_output"
  assert_equals_helper 'We expect a valid message' "$LINENO" "$expected" "$output"

  # Verifying that the correct filename is displayed.
  assertTrue "(${LINENO}): We expect to find a test file with the correct name" "[[ -f ${SHUNIT_TMPDIR}/report_output ]]"

  # Try to use an invalid root directory path.
  output=$(save_data_to '/lala/do/not')
  ret="$?"
  assert_equals_helper 'We expect a root path to be invalid' "$LINENO" "$ret" 1

  # Try to use an invalid folder path error.
  output=$(save_data_to '/tmp/folder_not_created/')
  ret="$?"
  assert_equals_helper 'We expect an invalid path error where the folder was not created.' "$LINENO" 1 "$ret"
}

invoke_shunit
