#!/bin/bash

. ./kw.sh --source-only

function suite
{
  suite_addTest "testHelp"
  suite_addTest "testVariables"
  suite_addTest "testExported"
}

function testHelp
{
  HELP_OUTPUT=`kw help | head -n 1`
  assertTrue "Help text not displaying correctly." '[[ $HELP_OUTPUT =~ Usage:\ kw.* ]]'
}

function testVariables
{
  VARS=( EASY_KERNEL_WORKFLOW src_script_path external_script_path )
  for v in "${VARS[@]}"; do
    test -z ${!v+x}; assertEquals "Variable $v does not exist." $? 1
  done
}

function testExported
{
  VARS=( EASY_KERNEL_WORKFLOW )
  for v in "${VARS[@]}"; do
    [[ $(declare -p $v)  =~ ^declare\ -[aAilrtu]*x[aAilrtu]*\  ]] ||
      fail "Variable $v was not exported"
  done
}

. ./tests/shunit2
