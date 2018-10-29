#!/bin/bash

. ./src/vm.sh --source-only
. ./tests/utils --source-only

# TODO: unit test for execute_get_maintainer

function suite
{
  suite_addTest "testVmUp"
}

function testVmUp
{
  vm_up &
  if [ $? -ne 0 ]; then
    fail "Expecting the kw VM to be initialized"
    true
    return
  fi
  local res=$(ps -ef --ppid $$ | grep -v "grep" | grep "qemu-system")
  assertNotNull "Expected VM to be up." "$res"
  local id=$(echo $res | awk '{ print $2; }')
  kill -INT $id
  true
}

invoke_shunit
