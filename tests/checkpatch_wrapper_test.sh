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
}

FAKE_KERNEL="tests/.tmp"

# Those variables hold the last line execute_checkpatch prints in a code that is
# correct, has 1 warning, has 1 erros and has 1 check, respectively. The sample
# codes used in this test are in tests/samples/
CORRECT_MSG="$SEPARATOR"
WARNING_MSG="total: 0 errors, 1 warnings, 0 checks, 25 lines checked"
ERROR_MSG="total: 1 errors, 0 warnings, 0 checks, 25 lines checked"
CHECK_MSG="total: 0 errors, 0 warnings, 1 checks, 26 lines checked"

declare -A MSG=( \
    ["correct"]=CORRECT_MSG \
    ["warning"]=WARNING_MSG \
    ["error"]=ERROR_MSG \
    ["check"]=CHECK_MSG \
)

# Note:
# This function explores some exciting features from bash that deserve a
# highlight. Here we have the use of indirect references in ${!MSG[$1]}
# (indicated by "!"), we basically access values in the array MSG that, in its
# turn, evaluate the constant value (WARNING_MSG, ERROR_MSG, etc).
function checkpatch
{
  local res

  res=$(execute_checkpatch "$FAKE_KERNEL/samples/codestyle_$1.c" 2>&1)
  [[ "$res" =~ "${!MSG[$1]}" ]]
  assertTrue "Checkpatch should output: ${!MSG[$1]}" $?
}

function oneTimeSetUp
{
  mk_fake_kernel_root "$FAKE_KERNEL"
  cp -f tests/external/checkpatch.pl "$FAKE_KERNEL"/scripts/
  cp -f tests/external/const_structs.checkpatch "$FAKE_KERNEL"/scripts/
  cp -f tests/external/spelling.txt "$FAKE_KERNEL"/scripts/
  cp -r tests/samples "$FAKE_KERNEL"
}

function oneTimeTearDown
{
  rm -rf "$FAKE_KERNEL"
}

function warning_Test
{
  checkpatch "warning"
}

function error_Test
{
  checkpatch "error"
}

function checks_Test
{
  checkpatch "check"
}

function correct_Test
{
  checkpatch "correct"
}

function invalid_path_Test
{
  local build_fake_path
  local output
  local ret

  build_fake_path="$RANDOM/$RANDOM/$RANDOM/xptolala"

  output=$(execute_checkpatch "$build_fake_path")
  ret="$?"
  if [[ "$ret" != 22 ]]; then
    assertFalse "We forced an invalid path and we expect an error" "$?"
  fi
}

function no_kernel_directory_Test
{
  local output
  local sample_one="tests/samples/codestyle_warning.c"

  # We want to force an unexpected condition, because of this we change the
  # basic setup but we rebuild it at the end of the test
  oneTimeTearDown

  output=$(execute_checkpatch "$sample_one")
  ret="$?"
  if [[ "$ret" != 22 ]]; then
    assertFalse "We forced an invalid path and we expect an error" "$?"
  fi

  oneTimeSetUp
}

function multiple_files_output_Test
{
  local output
  local delimiter="$SEPARATOR"
  local array=()

  output=$(execute_checkpatch "$FAKE_KERNEL/samples" 2>&1)

  # Reference: https://www.tutorialkart.com/bash-shell-scripting/bash-split-string/
  s="$output$delimiter"
  while [[ "$s" ]]; do
    array+=( "${s%%"$delimiter"*}" );
    s=${s#*"$delimiter"};
  done;

  size="${#array[@]}"
  # We use three here because we expect one $SEPARATOR from the beginning and
  # other from s="$output$delimiter"
  if [[ "$size" -lt "3" ]]; then
    assertTrue "We could not find more then two SEPARATOR sequence"
  fi
}

invoke_shunit
