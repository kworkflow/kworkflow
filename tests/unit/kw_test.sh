#!/usr/bin/env bash

include './tests/unit/utils.sh'
unset -v KW_LIB_DIR # to be able to test the developer mode
include './kw' > /dev/null
# when imported kw prints the help function and we don´t want
# to polute our test results, so we redirect its output to /dev/null

function test_validate_global_variables()
{
  VARS=(KWORKFLOW KW_LIB_DIR)
  for v in "${VARS[@]}"; do
    test -z ${!v+x}
    assertEquals "Variable ${v} should exist." 1 $?
  done
}

function test_check_kworkflow_global_variable()
{
  VARS=(KWORKFLOW)
  for v in "${VARS[@]}"; do
    [[ $(declare -p "$v") =~ ^declare\ -[aAilrtu]*x[aAilrtu]*\  ]] ||
      fail "Variable $v should have been exported"
  done
}

function test_set_KW_LIB_DIR_in_dev_mode()
{
  lib="${KW_LIB_DIR}/lib/kwlib.sh"
  test -f "${lib}" || fail "kwlib.sh not found (${lib} not found)!"
}

invoke_shunit
