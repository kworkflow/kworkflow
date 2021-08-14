#!/bin/bash

include './src/checkpatch_wrapper.sh'
include './tests/utils.sh'

# Those variables hold the last line execute_checkpatch prints in a code that is
# correct, has 1 warning, has 1 erros and has 1 check, respectively. The sample
# codes used in this test are in tests/samples/

function oneTimeSetUp()
{
  mk_fake_kernel_root "$SHUNIT_TMPDIR"
  cp -f tests/external/checkpatch.pl "$SHUNIT_TMPDIR"/scripts/
  cp -f tests/external/const_structs.checkpatch "$SHUNIT_TMPDIR"/scripts/
  cp -f tests/external/spelling.txt "$SHUNIT_TMPDIR"/scripts/
  cp -r tests/samples "$SHUNIT_TMPDIR"
}

function checkpatch_helper()
{
  local type_msg="$1"
  local CORRECT_MSG="$SEPARATOR"
  local WARNING_MSG='total: 0 errors, 1 warnings, 0 checks, 25 lines checked'
  local ERROR_MSG='total: 1 errors, 0 warnings, 0 checks, 25 lines checked'
  local CHECK_MSG='total: 0 errors, 0 warnings, 1 checks, 26 lines checked'
  local res
  declare -A MSG=(
    ['correct']=CORRECT_MSG
    ['warning']=WARNING_MSG
    ['error']=ERROR_MSG
    ['check']=CHECK_MSG
  )

  res=$(execute_checkpatch "$SHUNIT_TMPDIR/samples/codestyle_$type_msg.c" 2>&1)
  assertTrue "Checkpatch should output: ${!MSG[$type_msg]}" '[[ "$res" =~ "${!MSG[$type_msg]}" ]]'
}

function test_warning()
{
  checkpatch_helper 'warning'
}

function test_error()
{
  checkpatch_helper 'error'
}

function test_checks()
{
  checkpatch_helper 'check'
}

function test_correct()
{
  checkpatch_helper 'correct'
}

function test_invalid_path()
{
  local build_fake_path
  local output
  local ret

  build_fake_path=$(create_invalid_file_path)

  output=$(execute_checkpatch "$build_fake_path")
  ret="$?"
  assertEquals 'We forced an invalid path and we expect an error' '2' "$ret"
}

function test_no_kernel_directory()
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

function test_multiple_files_output()
{
  local delimiter="$SEPARATOR"
  local array=()
  local output

  output=$(execute_checkpatch "$SHUNIT_TMPDIR/samples" 2>&1)

  # Reference: https://www.tutorialkart.com/bash-shell-scripting/bash-split-string/
  s="$output$delimiter"
  while [[ "$s" ]]; do
    array+=("${s%%"$delimiter"*}")
    s=${s#*"$delimiter"}
  done

  size="${#array[@]}"
  # We use three here because we expect one $SEPARATOR from the beginning and
  # other from s="$output$delimiter"
  assertFalse 'We could not find more then two SEPARATOR sequence' '[[ $size -lt "3" ]]'
}

function test_run_checkpatch_in_a_path()
{
  local cmd="perl scripts/checkpatch.pl --no-tree --color=always --strict"
  local patch_path="$TMP_TEST_DIR/samples/test.patch"
  local patch_path="$SHUNIT_TMPDIR/samples/test.patch"
  local output
  local real_path
  local base_msg

  real_path=$(realpath "$patch_path")
  base_msg="Running checkpatch.pl on: $real_path"

  declare -a expected_cmd=(
    "$base_msg"
    "$SEPARATOR"
    "$cmd  $real_path"
  )

  output=$(execute_checkpatch "$patch_path" 'TEST_MODE' 2>&1)
  compare_command_sequence 'expected_cmd' "$output" '1'
}

function test_run_checkpatch_in_a_file()
{
  local cmd="perl scripts/checkpatch.pl --terse --no-tree --color=always --strict  --file"
  local patch_path="$SHUNIT_TMPDIR/samples/codestyle_correct.c"
  local output
  local real_path
  local base_msg

  real_path=$(realpath "$patch_path")
  base_msg="Running checkpatch.pl on: $real_path"

  declare -a expected_cmd=(
    "$base_msg"
    "$SEPARATOR"
    "$cmd  $real_path"
  )

  output=$(execute_checkpatch "$patch_path" 'TEST_MODE' 2>&1)
  compare_command_sequence 'expected_cmd' "$output" '1'
}

invoke_shunit
