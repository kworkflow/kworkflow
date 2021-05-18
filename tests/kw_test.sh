#!/bin/bash

. ./tests/utils --source-only
unset -v KW_LIB_DIR  # to be able to test the developer mode
. ./kw --source-only > /dev/null

function suite
{
  suite_addTest "validate_global_variables_Test"
  suite_addTest "check_kworkflow_global_variable_Test"
  suite_addTest "set_KW_LIB_DIR_in_dev_mode"
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

function set_KW_LIB_DIR_in_dev_mode
{
  lib="${KW_LIB_DIR}/kwlib.sh"
  test -f "${lib}" || fail "kwlib.sh not found (${lib} not found)!"
}

invoke_shunit
