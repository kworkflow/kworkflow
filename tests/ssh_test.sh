#!/bin/bash

#
# NOTE: We're not testing the ssh command here, just the kw ssh operation
#

. ./src/vm.sh --source-only
. ./tests/utils --source-only

INVALID_ARG="Invalid arguments"
NO_SUCH_FILE="No such file"
TEST_PATH="tests/.tmp"

SSH_OK="ssh -p 3333 127.0.0.1"

function suite()
{
  suite_addTest "vm_ssh_check_fail_cases_Test"
  suite_addTest "vm_ssh_basic_Test"
  suite_addTest "vm_ssh_command_Test"
  suite_addTest "vm_ssh_script_Test"
}

function setupSsh()
{
  local -r current_path=$PWD

  rm -rf $TEST_PATH

  mkdir -p $TEST_PATH

  cp -f tests/samples/kworkflow.config $TEST_PATH
  cp -f tests/samples/dmesg $TEST_PATH

  cd $TEST_PATH
  load_configuration
  cd $current_path
}

function tearDownSsh()
{
  rm -rf $TEST_PATH
}

function vm_ssh_check_fail_cases_Test()
{
  setupSsh

  local args="--lala"
  local ret=$(vm_ssh $args)

  assertTrue "We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-m"
  ret=$(vm_ssh $args)
  assertTrue "We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-d="
  ret=$(vm_ssh $args)
  assertTrue "We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-c"
  ret=$(vm_ssh $args)
  assertTrue "We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-s"
  ret=$(vm_ssh $args)
  assertTrue "We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-s="
  ret=$(vm_ssh $args)
  assertTrue "We expected a substring \"$NO_SUCH_FILE\", but we got \"$ret\"" '[[ $ret =~ "$NO_SUCH_FILE" ]]'

  args="--script="
  ret=$(vm_ssh $args)
  assertTrue "We expected a substring \"$NO_SUCH_FILE\", but we got \"$ret\"" '[[ $ret =~ "$NO_SUCH_FILE" ]]'

  tearDownSsh
}

function vm_ssh_basic_Test()
{
  setupSsh

  ret=$(vm_ssh 2>&1)

  assertTrue "We expected a substring \"$SSH_OK\", but we got \"$ret\"" '[[ $ret =~ "$SSH_OK" ]]'

  tearDownSsh
}

function vm_ssh_command_Test()
{
  setupSsh

  ret=$(vm_ssh -c="pwd" 2>&1)
  msg="$SSH_OK pwd"
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'

  ret=$(vm_ssh --command="ls /etc/" 2>&1)
  msg="$SSH_OK ls /etc/"
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'

  tearDownSsh
}

function vm_ssh_script_Test()
{
  setupSsh

  ret=$(vm_ssh -s="/not/a/valid/path/xpto" 2>&1)
  msg="$NO_SUCH_FILE: \"/not/a/valid/path/xpto\""
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'

  ret=$(vm_ssh -s="$TEST_PATH/dmesg" 2>&1)
  msg="$SSH_OK \"bash -s\" -- < $TEST_PATH/dmesg"
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'

  tearDownSsh
}

invoke_shunit
