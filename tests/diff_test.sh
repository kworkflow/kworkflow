#!/bin/bash

. ./src/diff.sh --source-only
. ./tests/utils --source-only

function suite()
{
  suite_addTest "diff_side_by_side_Test"
  suite_addTest "diff_manager_Test"
}

function diff_side_by_side_Test()
{
  local ID
  local columns=$(tput cols)
  local file_1="$SAMPLES_DIR/MAINTAINERS"
  local file_2="$SAMPLES_DIR/dmesg"
  local diff_cmd="diff -y --color=always --width=$columns $file_1 $file_2 | less -R"

  declare -a expected_cmd=(
    "$diff_cmd"
  )

  ID=1
  output=$(diff_side_by_side "$file_1" "$file_2" 1 'TEST_MODE')
  compare_command_sequence expected_cmd[@] "$output" "$ID"

  ID=2
  diff_cmd="diff -y --color=always --width=$columns $file_1 $file_2"
  declare -a expected_cmd=(
    "$diff_cmd"
  )

  output=$(diff_side_by_side "$file_1" "$file_2" 0 'TEST_MODE')
  compare_command_sequence expected_cmd[@] "$output" "$ID"

  ID=3
  output=$(diff_side_by_side 'an_invalid_file' "$file_2" 0 'TEST_MODE')
  ret="$?"
  assertEquals "($ID) Expected 22" "22" "$ret"

  output=$(diff_side_by_side 'an_invalid_file' 'another_invalid_file' 0 'TEST_MODE')
  ret="$?"
  assertEquals "($ID) Expected 22" "22" "$ret"

}

function diff_manager_Test()
{
  local ID
  local file_1="$SAMPLES_DIR/MAINTAINERS"
  local file_2="$SAMPLES_DIR/dmesg"

  ID=1
  output=$(diff_manager 'file_1' 'file_2')
  ret="$?"
  assertEquals "($ID) Expected 2" '2' "$ret"

  ID=2
  expected_result="$file_1 $file_2 1"
  output=$(diff_manager 'test_mode' "$file_1" "$file_2")
  ret="$?"
  assertEquals "($ID) Default option:" "$expected_result" "$output"

  ID=3
  expected_result="$file_1 $file_2 0"
  output=$(diff_manager 'test_mode' '--no-interactive' "$file_1" "$file_2")
  ret="$?"
  assertEquals "($ID) Default option:" "$expected_result" "$output"
}

invoke_shunit
