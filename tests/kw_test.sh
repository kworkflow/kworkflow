#!/bin/bash

include './tests/utils'
unset -v KW_LIB_DIR  # to be able to test the developer mode
include './kw' > /dev/null
# when imported kw prints the help function and we don´t want
# to polute our test results, so we redirect its output to /dev/null

function suite
{
  suite_addTest "validate_global_variables_Test"
  suite_addTest "check_kworkflow_global_variable_Test"
  suite_addTest 'set_KW_LIB_DIR_in_dev_mode_Test'
}

function validate_global_variables_Test
{
  VARS=( KWORKFLOW KW_LIB_DIR )
  for v in "${VARS[@]}"; do
    test -z ${!v+x}; assertEquals "Variable $v should exist." $? 1
  done
}

function check_kworkflow_global_variable_Test
{
  VARS=( KWORKFLOW )
  for v in "${VARS[@]}"; do
    [[ $(declare -p $v)  =~ ^declare\ -[aAilrtu]*x[aAilrtu]*\  ]] ||
      fail "Variable $v should have been exported"
  done
}

function set_KW_LIB_DIR_in_dev_mode_Test
{
  lib="${KW_LIB_DIR}/kwlib.sh"
  test -f "${lib}" || fail "kwlib.sh not found (${lib} not found)!"
}

invoke_shunit
