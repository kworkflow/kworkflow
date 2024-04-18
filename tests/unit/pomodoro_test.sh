#!/bin/bash

include './src/pomodoro.sh'
include './src/lib/kw_db.sh'
include './tests/unit/utils.sh'

function oneTimeSetUp()
{
  declare -g DB_FILES
  DB_FILES="$(realpath './tests/unit/samples/db_files')"
  export KW_DATA_DIR="${SHUNIT_TMPDIR}"
  KW_DB_DIR="$(realpath './database')"
}

function setUp()
{
  declare -gA options_values

  setupDatabase
}

function tearDown()
{
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

function test_show_active_pomodoro_timebox()
{
  local columns='("tag_name","date","time","duration")'
  local values
  local current_timestamp
  local timestamp
  local start_date
  local start_time
  local timezone
  local output
  declare -a expected=()

  # We need to manipulate timezones to assure that these tests are timezone independent
  timezone=$(date '+%z')
  timezone="${timezone::-2}"
  # shellcheck disable=SC2076
  if [[ "$timezone" =~ '+' ]]; then
    timezone="-${timezone:1}"
  else
    timezone="+${timezone:1}"
  fi

  # shellcheck disable=SC2317
  function get_timestamp_sec()
  {
    # 2075/08/05 12:11:40 UTC
    printf '%s\n' '3332232700'
  }

  # No active timebox
  current_timestamp=$(date '+%s')
  timestamp=$((current_timestamp - 3600))
  timestamp=$(TZ="UTC${timezone}" date -d @"${timestamp}" '+%Y/%m/%d %H:%M:%S')
  start_date=$(printf '%s' "${timestamp}" | sed 's/\//-/g' | cut -d ' ' -f1)
  start_time=$(printf '%s' "${timestamp}" | cut -d ' ' -f2)
  values="('fake_tag','${start_date}','${start_time}','3599')"
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO 'pomodoro_report' ${columns} VALUES ${values} ;"
  output=$(show_active_pomodoro_timebox)
  expected=()
  compare_command_sequence 'Should not have any active timebox' "$LINENO" 'expected' "$output"

  # One active timebox
  # 2075/08/05 12:09:17 UTC
  timestamp=3332232557
  timestamp=$(TZ="UTC${timezone}" date -d @"${timestamp}" '+%Y/%m/%d %H:%M:%S')
  start_date=$(printf '%s' "${timestamp}" | sed 's/\//-/g' | cut -d ' ' -f1)
  start_time=$(printf '%s' "${timestamp}" | cut -d ' ' -f2)
  values="('fake_tag','${start_date}','${start_time}','3600')"
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO 'pomodoro_report' ${columns} VALUES ${values} ;"
  output=$(show_active_pomodoro_timebox)
  start_date=$(printf '%s' "${timestamp}" | cut -d ' ' -f1)
  expected=(
    "Started at: ${start_time} [${start_date}]"
    '- Elapsed time: 00:02:23'
    '- You still have 00:57:37'
  )
  compare_command_sequence 'Should have one active timebox' "$LINENO" 'expected' "$output"

  # Multiple active timebox
  # 2075/08/05 12:10:30 UTC
  timestamp=3332232630
  timestamp=$(TZ="UTC${timezone}" date -d @"${timestamp}" '+%Y/%m/%d %H:%M:%S')
  start_date=$(printf '%s' "${timestamp}" | sed 's/\//-/g' | cut -d ' ' -f1)
  start_time=$(printf '%s' "${timestamp}" | cut -d ' ' -f2)
  values="('fake_tag','${start_date}','${start_time}','120')"
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO 'pomodoro_report' ${columns} VALUES ${values} ;"
  output=$(show_active_pomodoro_timebox)
  start_date=$(printf '%s' "${timestamp}" | cut -d ' ' -f1)
  expected+=(
    "Started at: ${start_time} [${start_date}]"
    '- Elapsed time: 00:01:10'
    '- You still have 00:00:50'
  )
  compare_command_sequence 'Should have two active timeboxes' "$LINENO" 'expected' "$output"
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

  parse_pomodoro '--verbose'
  assert_equals_helper 'Show a detailed output' "$LINENO" "${options_values['VERBOSE']}" '1'
}

function test_register_data_for_report()
{
  local start_date
  local output
  declare -a output_array

  # Case 1: no description
  options_values['TAG']='Testing 1,2,3'
  options_values['TIMER']='30m'
  options_values['DESCRIPTION']=''
  start_date=$(date +%Y-%m-%d)
  register_data_for_report
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT * FROM pomodoro_report WHERE id IS 1 ;")
  # output_array is (<id> <tag_id> <tag_name> <start_date> <start_time> <duration> <description>)
  IFS='|' read -ra output_array <<< "$output"
  assert_equals_helper 'Tag name inserted is wrong' "$LINENO" "${options_values['TAG']}" "${output_array[2]}"
  assert_equals_helper 'Start date inserted is wrong' "$LINENO" "${start_date}" "${output_array[3]}"
  assert_equals_helper 'Duration  inserted is wrong' "$LINENO" 1800 "${output_array[5]}"
  assert_equals_helper 'Description should be empty' "$LINENO" '' "${output_array[6]}"

  # Case 2: with description
  options_values['TAG']='3,2,1 gnitseT'
  options_values['TIMER']='12h'
  options_values['DESCRIPTION']='Simple description'
  start_date=$(date +%Y-%m-%d)
  register_data_for_report
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT * FROM pomodoro_report WHERE id IS 2 ;")
  # output_array is (<id> <tag_id> <tag_name> <start_date> <start_time> <duration> <description>)
  IFS='|' read -ra output_array <<< "$output"
  assert_equals_helper 'Tag name inserted is wrong' "$LINENO" "${options_values['TAG']}" "${output_array[2]}"
  assert_equals_helper 'Start date inserted is wrong' "$LINENO" "${start_date}" "${output_array[3]}"
  assert_equals_helper 'Duration inserted is wrong' "$LINENO" 43200 "${output_array[5]}"
  assert_equals_helper 'Description inserted is wrong' "$LINENO" "${options_values['DESCRIPTION']}" "${output_array[6]}"
}

function test_register_tag()
{
  local output

  declare -a expected_content=(
    'tag 1'
    'tag 2'
  )

  register_tag '' 'tag 1'
  register_tag '' 'tag 2'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name FROM tag ;")

  compare_command_sequence '' "$LINENO" 'expected_content' "$output"

  # Try to register the same tag
  register_tag '' 'tag 2'
  compare_command_sequence '' "$LINENO" 'expected_content' "$output"

  # Try to register an empty tag
  register_tag '' ''
  compare_command_sequence '' "$LINENO" 'expected_content' "$output"
}

function test_is_tag_already_registered()
{
  is_tag_already_registered '' 'Tag 0'
  assertNotEquals "$LINENO: We should not get a success" "$?" 0

  is_tag_already_registered '' ''
  assertNotEquals "$LINENO: We should not get a success" "$?" 0

  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO tag ('name') VALUES ('Tag 0') ;"
  is_tag_already_registered '' 'Tag 0'
  assertEquals "$LINENO: We expect to find Tag 0" "$?" 0
}

function test_get_tag_name()
{
  local output
  local expected

  get_tag_name ''
  assert_equals_helper 'Empty string should be detected' "$LINENO" '22' "$?"

  output=$(get_tag_name 'Some tag')
  expected='Some tag'
  assert_equals_helper 'Should return same value if it is not a number' "$LINENO" "$expected" "$output"

  register_tag '' 'tag 1'
  register_tag '' 'tag 2'
  register_tag '' 'tag 3'
  register_tag '' 'tag 4'

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

function test_show_tags()
{
  local output
  local expected
  local values

  output=$(show_tags)
  expected='You did not register any tag yet'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  # Testing both the right tag names and the order by ID
  values="('DDDDDDD'), ('BBBBBBB'), ('CCCCCCC'), ('AAAAAAA')"
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO tag ('name') VALUES ${values} ;"
  output=$(show_tags)
  expected='TAGS:'$'\n'
  expected+='ID  Name   '$'\n'
  expected+='--  -------'$'\n'
  expected+='1   DDDDDDD'$'\n'
  expected+='2   BBBBBBB'$'\n'
  expected+='3   CCCCCCC'$'\n'
  expected+='4   AAAAAAA'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  # Testing addition of tag
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO tag ('name') VALUES ('1111111') ;"
  output=$(show_tags)
  expected='TAGS:'$'\n'
  expected+='ID  Name   '$'\n'
  expected+='--  -------'$'\n'
  expected+='1   DDDDDDD'$'\n'
  expected+='2   BBBBBBB'$'\n'
  expected+='3   CCCCCCC'$'\n'
  expected+='4   AAAAAAA'$'\n'
  expected+='5   1111111'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  # Testing removal of tag (although not allowed it is valid to test)
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "DELETE FROM tag WHERE id=1 OR id=3 ;"
  output=$(show_tags)
  expected='TAGS:'$'\n'
  expected+='ID  Name   '$'\n'
  expected+='--  -------'$'\n'
  expected+='2   BBBBBBB'$'\n'
  expected+='4   AAAAAAA'$'\n'
  expected+='5   1111111'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
}

function test_get_last_args()
{
  local expected_error

  printf "" > "/tmp/last_pomodoro"
  get_last_args
  assert_equals_helper 'Empty pomodoro file should return 22' "$LINENO" 22 "$?"
  expected_error='No last pomodoro command found'
  assert_equals_helper 'Incorrect error message' "$LINENO" "$expected_error" ${options_values[ERROR]}

  rm /tmp/last_pomodoro
  get_last_args
  assert_equals_helper 'Missing pomodoro file should return 22' "$LINENO" 22 "$?"
  expected_error='No last pomodoro command found'
  assert_equals_helper 'Incorrect error message' "$LINENO" "$expected_error" ${options_values[ERROR]}

  printf '-t 30m -g "New tag" -d "I know how to reproduce the bug!"' > "/tmp/last_pomodoro"
  get_last_args
  assert_equals_helper 'Valid argument should return 0' "$LINENO" 0 "$?"
}

function test_store_last_args()
{
  local expected_error

  store_last_args ''
  assert_equals_helper 'Empty string should return 22' "$LINENO" 22 "$?"
  expected_error='Received empty arguments string'
  asset_equals_helper 'Incorrect error message' "$LINENO" "$expected_error" "${options_value[ERROR]}"

  store_last_args '-t 30m -g "New tag" -d "I know how to reproduce the bug!"'
  assert_equals_helper 'Valid argument should return 0' "$LINENO" 0 "$?"
}

invoke_shunit
