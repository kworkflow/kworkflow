#!/usr/bin/env bash

include './scripts/profiler.sh' > '/dev/null' 2>&1
include './tests/unit/utils.sh'

function setUp() {
  export ORIGINAL_PATH="$PWD"

  declare -ga full_profile

  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO): setUp(): It was not possible to move into ${SHUNIT_TMPDIR}"
    return
  }
}

function tearDown() {
  unset full_profile

  cd "${ORIGINAL_PATH}" || {
    fail "($LINENO): tearDown(): It was not possible to move into ${ORIGINAL_PATH}"
    return
  }
}

function test_process_csv_files_full_single_threaded() {
  local list_of_csv_filepaths="${SAMPLES_DIR}/scripts/profiler/single_threaded/0.csv"
  local expected

  process_csv_files "$list_of_csv_filepaths" 'full'

  assert_equals_helper 'Wrong number of threads' "$LINENO" 1 "${#full_profile[@]}"

  expected='--> foo'$'\n'
  expected+='  1.000 milliseconds'$'\n'
  expected+='  --> bar'$'\n'
  expected+='    11.000 milliseconds'$'\n'
  expected+='  <-- bar'$'\n'
  expected+='  8.000 milliseconds'$'\n'
  expected+='  --> foobar'$'\n'
  expected+='    251.000 milliseconds'$'\n'
  expected+='<---- foobar'$'\n'
  assert_equals_helper 'Wrong profile of thread 0' "$LINENO" "$expected" "${full_profile[0]}"
}

function test_process_csv_files_full_multi_threaded() {
  local list_of_csv_filepaths
  local expected

  list_of_csv_filepaths+="${SAMPLES_DIR}/scripts/profiler/multi_threaded/2.csv"$'\n'
  list_of_csv_filepaths+="${SAMPLES_DIR}/scripts/profiler/multi_threaded/1.csv"$'\n'
  list_of_csv_filepaths+="${SAMPLES_DIR}/scripts/profiler/multi_threaded/0.csv"
  process_csv_files "$list_of_csv_filepaths" 'full'

  assert_equals_helper 'Wrong number of threads' "$LINENO" 3 "${#full_profile[@]}"

  expected='--> foo'$'\n'
  expected+='  1.000 milliseconds'$'\n'
  expected+='  --> bar'$'\n'
  expected+='    11.000 milliseconds'$'\n'
  expected+='  <-- bar'$'\n'
  expected+='  8.000 milliseconds'$'\n'
  expected+='  --> foobar'$'\n'
  expected+='    251.000 milliseconds'$'\n'
  expected+='<---- foobar'$'\n'
  assert_equals_helper 'Wrong profile of thread 0' "$LINENO" "$expected" "${full_profile[0]}"

  expected='--> rec'$'\n'
  expected+='  .500 milliseconds'$'\n'
  expected+='  --> rec'$'\n'
  expected+='    .500 milliseconds'$'\n'
  expected+='    --> rec'$'\n'
  expected+='      1.000 milliseconds'$'\n'
  expected+='    <-- rec'$'\n'
  expected+='    2.050 milliseconds'$'\n'
  expected+='  <-- rec'$'\n'
  expected+='  2.180 milliseconds'$'\n'
  expected+='<-- rec'$'\n'
  assert_equals_helper 'Wrong profile of thread 1' "$LINENO" "$expected" "${full_profile[1]}"

  expected='--> foo'$'\n'
  expected+='  .002 milliseconds'$'\n'
  expected+='<-- foo'$'\n'
  expected+='.010 milliseconds'$'\n'
  expected+='--> bar'$'\n'
  expected+='  .200 milliseconds'$'\n'
  expected+='<-- bar'$'\n'
  expected+='.898 milliseconds'$'\n'
  expected+='--> foobar'$'\n'
  expected+='  1.111 milliseconds'$'\n'
  expected+='<-- foobar'$'\n'
  assert_equals_helper 'Wrong profile of thread 2' "$LINENO" "$expected" "${full_profile[2]}"
}

function test_display_full_profile() {
  local list_of_csv_filepaths
  local output
  local expected

  full_profile[0]='foo'
  full_profile[1]='bar'
  full_profile[2]='foobar'

  output=$(display_full_profile)
  expected='Thread nr. 0'$'\n'
  expected+='###############'$'\n'
  expected+='foo'$'\n'
  expected+='Thread nr. 1'$'\n'
  expected+='###############'$'\n'
  expected+='bar'$'\n'
  expected+='Thread nr. 2'$'\n'
  expected+='###############'$'\n'
  expected+='foobar'
  assert_equals_helper 'Wrong profile displayed' "$LINENO" "$expected" "$output"
}

invoke_shunit
