#!/bin/bash

. ./src/checkpatch_wrapper.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "testWarning"
  suite_addTest "testError"
  suite_addTest "testChecks"
}

# Those variables hold the last line execute_checkpatch prints in a code that is correct, has
# 1 warning, has 1 erros and has 1 check, respectively. The sample codes used in this test are
# in tests/samples/
CORRECT_MSG="========================================================="
WARNING_MSG="total: 0 errors, 1 warnings, 0 checks, 25 lines checked"
ERROR_MSG="total: 1 errors, 0 warnings, 0 checks, 25 lines checked"
CHECK_MSG="total: 0 errors, 0 warnings, 1 checks, 26 lines checked"

declare -A MSG=( \
    ["correct"]=CORRECT_MSG \
    ["warning"]=WARNING_MSG \
    ["error"]=ERROR_MSG \
    ["check"]=CHECK_MSG \
)

function checkpatch
{
  res=$(execute_checkpatch "tests/samples/codestyle_$1.c" 2>&1 | tail -n 1 )
  [[ "$res" != "${!MSG[$1]}" ]] && fail "Checkpatch should output:\n${!MSG[$1]}"
  true # Reset return value
}

function testWarning
{
  checkpatch "warning"
}

function testError
{
  checkpatch "error"
}

function testChecks
{
  checkpatch "check"
}

function testCorrect
{
  checkpatch "correct"
}

invoke_shunit
