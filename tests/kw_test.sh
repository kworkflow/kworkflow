#!/bin/bash

. ./kw.sh --source-only

function suite
{
  suite_addTest "testHelp"
  suite_addTest "testVariables"
}

function testHelp
{
  HELP_OUTPUT=`kw help | head -n 1`
  assertTrue "Help text not displaying correctly." '[[ $HELP_OUTPUT =~ Usage:\ kw.* ]]'
}

function testVariables
{
  test -z ${EASY_KERNEL_WORKFLOW+x}; assertEquals "Variable EASY_KERNEL_WORKFLOW does not exist." $? 1
  test -z ${src_script_path+x}; assertEquals "Variable src_script_path does not exist." $? 1
  test -z ${external_script_path+x}; assertEquals "Variable external_script_path does not exist." $? 1
}

. ./tests/shunit2
