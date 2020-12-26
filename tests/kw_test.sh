#!/bin/bash

. ./tests/utils --source-only
. ./kw --source-only > /dev/null

function suite
{
  suite_addTest "testVariables"
  suite_addTest "testExported"
}

function testVariables
{
  VARS=( KWORKFLOW KW_LIB_DIR )
  for v in "${VARS[@]}"; do
    test -z ${!v+x}; assertEquals "Variable $v should exist." $? 1
  done
}

function testExported
{
  VARS=( KWORKFLOW )
  for v in "${VARS[@]}"; do
    [[ $(declare -p $v)  =~ ^declare\ -[aAilrtu]*x[aAilrtu]*\  ]] ||
      fail "Variable $v should have been exported"
  done
}

invoke_shunit
