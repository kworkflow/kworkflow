#!/bin/bash

. ./src/checkpatch_wrapper.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "testWarning"
  suite_addTest "testError"
  suite_addTest "testChecks"
  suite_addTest "testCorrect"
}

# Those variables hold the last line execute_checkpatch prints in a code that is
# correct, has 1 warning, has 1 erros and has 1 check, respectively. The sample
# codes used in this test are in tests/samples/
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

FAKE_KERNEL="tests/.tmp"

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

function checkpatch
{
  res=$(execute_checkpatch "$FAKE_KERNEL/samples/codestyle_$1.c" 2>&1)
  [[ "$res" == *"${!MSG[$1]}" ]]
  assertTrue "Checkpatch should output: ${!MSG[$1]}" $?
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
