#!/bin/bash

. ./src/checkpatch_wrapper.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "warning_Test"
  suite_addTest "error_Test"
  suite_addTest "checks_Test"
  suite_addTest "correct_Test"
  suite_addTest "invalid_path_Test"
  suite_addTest "no_kernel_directory_Test"
  suite_addTest "multiple_files_output_Test"
  suite_addTest "run_checkpatch_in_a_path_Test"
  suite_addTest "run_checkpatch_in_a_file_Test"
}

# Those variables hold the last line execute_checkpatch prints in a code that is
# correct, has 1 warning, has 1 erros and has 1 check, respectively. The sample
# codes used in this test are in tests/samples/
function oneTimeSetUp
{
  mk_fake_kernel_root "$TMP_TEST_DIR"
  cp -f tests/external/checkpatch.pl "$TMP_TEST_DIR"/scripts/
  cp -f tests/external/const_structs.checkpatch "$TMP_TEST_DIR"/scripts/
  cp -f tests/external/spelling.txt "$TMP_TEST_DIR"/scripts/
  cp -r tests/samples "$TMP_TEST_DIR"
}

function oneTimeTearDown
{
  rm -rf "$TMP_TEST_DIR"
}

function checkpatch_helper
{
  local type_msg="$1"
  local CORRECT_MSG="$SEPARATOR"
  local WARNING_MSG='total: 0 errors, 1 warnings, 0 checks, 25 lines checked'
  local ERROR_MSG='total: 1 errors, 0 warnings, 0 checks, 25 lines checked'
  local CHECK_MSG='total: 0 errors, 0 warnings, 1 checks, 26 lines checked'
  local res
  declare -A MSG=( \
      ['correct']=CORRECT_MSG \
      ['warning']=WARNING_MSG \
      ['error']=ERROR_MSG \
      ['check']=CHECK_MSG \
  )

  res=$(execute_checkpatch "$TMP_TEST_DIR/samples/codestyle_$type_msg.c" 2>&1)
  assertTrue "Checkpatch should output: ${!MSG[$type_msg]}" '[[ "$res" =~ "${!MSG[$type_msg]}" ]]'
}

function warning_Test
{
  checkpatch_helper 'warning'
}

function error_Test
{
  checkpatch_helper 'error'
}

function checks_Test
{
  checkpatch_helper 'check'
}

function correct_Test
{
  checkpatch_helper 'correct'
}

function invalid_path_Test
{
  local build_fake_path
  local output
  local ret

  build_fake_path=$(create_invalid_file_path)

  output=$(execute_checkpatch "$build_fake_path")
  ret="$?"
  assertEquals 'We forced an invalid path and we expect an error' '2' "$ret"
}

function no_kernel_directory_Test
{
  local sample_one="$SAMPLES_DIR/codestyle_warning.c"
  local output

  # We want to force an unexpected condition, because of this we change the
  # basic setup but we rebuild it at the end of the test
  oneTimeTearDown

  output=$(execute_checkpatch "$sample_one")
  ret="$?"
  assertFalse 'We forced an invalid path and we expect an error' '[[ $ret != 22 ]]'

  oneTimeSetUp
}

function multiple_files_output_Test
{
  local delimiter="$SEPARATOR"
  local array=()
  local output

  output=$(execute_checkpatch "$TMP_TEST_DIR/samples" 2>&1)

  # Reference: https://www.tutorialkart.com/bash-shell-scripting/bash-split-string/
  s="$output$delimiter"
  while [[ "$s" ]]; do
    array+=( "${s%%"$delimiter"*}" );
    s=${s#*"$delimiter"};
  done;

  size="${#array[@]}"
  # We use three here because we expect one $SEPARATOR from the beginning and
  # other from s="$output$delimiter"
  assertFalse 'We could not find more then two SEPARATOR sequence' '[[ $size -lt "3" ]]'
}

function run_checkpatch_in_a_path_Test
{
  local cmd="perl scripts/checkpatch.pl --no-tree --color=always --strict"
  local patch_path="$TMP_TEST_DIR/samples/test.patch"
  local real_path=$(realpath "$patch_path")
  local base_msg="Running checkpatch.pl on: $real_path"
  local output
  declare -a expected_cmd=(
    "$base_msg"
    "$SEPARATOR"
    "$cmd  $real_path"
  )

  output=$(execute_checkpatch "$patch_path" 'TEST_MODE' 2>&1)
  compare_command_sequence expected_cmd[@] "$output" '1'
}

function run_checkpatch_in_a_file_Test
{
  local cmd="perl scripts/checkpatch.pl --terse --no-tree --color=always --strict  --file"
  local patch_path="$TMP_TEST_DIR/samples/codestyle_correct.c"
  local real_path=$(realpath "$patch_path")
  local base_msg="Running checkpatch.pl on: $real_path"
  local output
  declare -a expected_cmd=(
    "$base_msg"
    "$SEPARATOR"
    "$cmd  $real_path"
  )

  output=$(execute_checkpatch "$patch_path" 'TEST_MODE' 2>&1)
  compare_command_sequence expected_cmd[@] "$output" '1'
}

invoke_shunit
