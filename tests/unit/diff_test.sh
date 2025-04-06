#!/usr/bin/env bash

include './src/diff.sh'
include './tests/unit/utils.sh'

function test_diff_main() {
  local file_1="$SAMPLES_DIR/MAINTAINERS"
  local file_2="$SAMPLES_DIR/dmesg"

  output=$(diff_main 'file_1' 'file_2')
  ret="$?"
  assertEquals "($LINENO) Expected 2" '2' "$ret"

  expected_result="$file_1 $file_2 1"
  output=$(diff_main "$file_1" "$file_2" 1 'test_mode')
  ret="$?"
  assertEquals "($LINENO) Default option:" "$expected_result" "$output"

  expected_result="$file_1 $file_2 0"
  output=$(diff_main "$file_1" "$file_2" 0 '--no-interactive' 'test_mode')
  ret="$?"
  assertEquals "($LINENO) Default option:" "$expected_result" "$output"
}

function test_diff_folders() {
  local folder_1="${SAMPLES_DIR}/external"
  local folder_2="${SAMPLES_DIR}/first_set_of_bytes_from_disk"

  # TODO: We need to investigate this LANG part. Ideally, we don't want it here
  output=$(LANG=en_US.UTF-8 diff_folders "$folder_1" "$folder_2")
  assertEquals "Only in ${folder_1}: get_maintainer.pl" "$output"
}

function test_diff_folders_no_difference() {
  local folder_1="${SAMPLES_DIR}/db_files"
  local folder_2="${SAMPLES_DIR}/db_files"

  output=$(diff_folders "$folder_1" "$folder_2")
  assertEquals "" "$output"
}

function test_diff_folders_invalid_path() {
  local folder_1="${SAMPLES_DIR}/db_files"
  local folder_2="${SAMPLES_DIR}/first_set_of_bytes_from_disk"

  output=$(diff_folders 'an_invalid_file' "$folder_2")
  assertEquals "($LINENO) Expected 22" 22 "$?"

  output=$(diff_folders 'an_invalid_file' 'another_invalid_file')
  assertEquals "($LINENO) Expected 22" 22 "$?"
}

function test_diff_side_by_side() {
  local file_1="$SAMPLES_DIR/MAINTAINERS"
  local file_2="$SAMPLES_DIR/dmesg"
  local columns
  local diff_cmd

  [[ "$TERM" == '' || "$TERM" == 'dumb' ]] && TPUTTERM=' -T xterm-256color'
  columns=$(eval tput"${TPUTTERM}" cols)
  diff_cmd="diff -y --color=always --width=$columns $file_1 $file_2 | less --RAW-CONTROL-CHARS"

  declare -a expected_cmd=(
    "$diff_cmd"
  )

  output=$(diff_side_by_side "$file_1" "$file_2" 1 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  diff_cmd="diff -y --color=always --width=$columns $file_1 $file_2"
  declare -a expected_cmd=(
    "$diff_cmd"
  )

  output=$(diff_side_by_side "$file_1" "$file_2" 0 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  output=$(diff_side_by_side 'an_invalid_file' "$file_2" 0 'TEST_MODE')
  ret="$?"
  assertEquals "($LINENO) Expected 22" "22" "$ret"

  output=$(diff_side_by_side 'an_invalid_file' 'another_invalid_file' 0 'TEST_MODE')
  ret="$?"
  assertEquals "($LINENO) Expected 22" "22" "$ret"

}

function test_parse_diff_options() {
  # shellcheck disable=SC2317
  function reset_options_values() {
    unset options_values
    declare -gA options_values
  }

  reset_options_values
  parse_diff_options
  assert_equals_helper 'Expect diff help message' \
    "($LINENO):" '0' $?

  reset_options_values
  parse_diff_options --no-interactive
  assert_equals_helper 'Set no interactivity' \
    "($LINENO):" '0' "${options_values['INTERACTIVE']}"

  reset_options_values
  parse_diff_options --verbose
  assert_equals_helper 'Set verbose mode' \
    "($LINENO):" '1' "${options_values['VERBOSE']}"

  reset_options_values
  parse_diff_options test_mode
  assert_equals_helper 'Set test mode' \
    "($LINENO):" 'TEST_MODE' "${options_values['TEST_MODE']}"
}

invoke_shunit
