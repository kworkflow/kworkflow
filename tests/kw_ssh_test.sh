#!/bin/bash

include './src/kw_ssh.sh'
include './tests/utils.sh'

### SSH tests ###
#
# NOTE: We're not testing the ssh command here, just the kw ssh operation
#

function oneTimeSetUp()
{
  export TEST_PATH="$SHUNIT_TMPDIR/test_path"
}

function setUp()
{
  export INVALID_ARG='Invalid arguments'
  export NO_SUCH_FILE='No such file'
  export SSH_OK='ssh -p 3333 127.0.0.1'

  mkdir "$TEST_PATH"

  cp -f 'tests/samples/dmesg' "$TEST_PATH"

  parse_configuration "$KW_CONFIG_SAMPLE"
  populate_remote_info ''
}

function tearDown()
{
  rm -rf "$TEST_PATH"
}

function test_kw_ssh_check_fail_cases()
{
  local args='--lala'
  local ret

  ret=$(kw_ssh "$args")
  assertTrue "($LINENO): We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-m"
  ret=$(kw_ssh $args)
  assertTrue "($LINENO): We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-d="
  ret=$(kw_ssh $args)
  assertTrue "($LINENO): We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-c"
  ret=$(kw_ssh $args)
  assertTrue "($LINENO): We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-s"
  ret=$(kw_ssh $args)
  assertTrue "($LINENO): We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-s="
  ret=$(kw_ssh $args)
  assertTrue "($LINENO): We expected a substring \"$NO_SUCH_FILE\", but we got \"$ret\"" '[[ $ret =~ "$NO_SUCH_FILE" ]]'

  args="--script="
  ret=$(kw_ssh $args)
  assertTrue "($LINENO): We expected a substring \"$NO_SUCH_FILE\", but we got \"$ret\"" '[[ $ret =~ "$NO_SUCH_FILE" ]]'
}

function test_kw_ssh_basic()
{
  ret=$(kw_ssh 2>&1)

  assertTrue "We expected a substring \"$SSH_OK\", but we got \"$ret\"" '[[ $ret =~ "$SSH_OK" ]]'
}

function test_kw_ssh_command()
{
  ret=$(kw_ssh -c="pwd" 2>&1)
  msg="$SSH_OK pwd"
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'

  ret=$(kw_ssh --command="ls /etc/" 2>&1)
  msg="$SSH_OK ls /etc/"
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'
}

function test_kw_ssh_script()
{
  ret=$(kw_ssh -s="/not/a/valid/path/xpto" 2>&1)
  msg="$NO_SUCH_FILE: \"/not/a/valid/path/xpto\""
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'
  ret=$(kw_ssh -s="$TEST_PATH/dmesg" 2>&1)
  msg="$SSH_OK \"bash -s\" -- < $TEST_PATH/dmesg"
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'
}

invoke_shunit
