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
  export original_dir="$PWD"
}

function setUp()
{
  export INVALID_ARG='Invalid arguments'
  export NO_SUCH_FILE='No such file'
  export SSH_OK='ssh -p 3333 juca@127.0.0.1'

  mkdir -p "$TEST_PATH"
  mkdir -p "${SHUNIT_TMPDIR}/.kw"
  cp "${KW_REMOTE_SAMPLES_DIR}/remote.config" "${SHUNIT_TMPDIR}/.kw"
  cp -f 'tests/samples/dmesg' "$TEST_PATH"

  parse_configuration "$KW_CONFIG_SAMPLE"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  populate_remote_info ''
}

function tearDown()
{
  cd "$original_dir" || {
    fail "($LINENO) It was not possible to back to the kw folder"
    return
  }
}

function test_parser_ssh_options()
{
  local ret
  local substring_output
  local error

  parser_ssh_options --lala
  ret="$?"
  assertTrue "($LINENO): We expected a 22 for --lala parameter" '[[ $ret -eq 22 ]]'

  parser_ssh_options -m
  ret="$?"
  assertTrue "($LINENO): We expected a 22 for -m parameter" '[[ $ret -eq 22 ]]'

  parser_ssh_options -c
  substring_output="ssh: option requires an argument -- 'c'"
  error="${options_values['ERROR']}"
  assertTrue "($LINENO): We should fail since -c expects a parameter" \
    '[[ $substring_output =~ $error ]]'

  parser_ssh_options -s
  substring_output="ssh: option requires an argument -- 's'"
  error="${options_values['ERROR']}"
  assertTrue "($LINENO): We expected a failure since -s expected a parameter" \
    '[[ $substring_output =~ $error ]]'
}

function test_kw_ssh_no_parameter()
{
  local output

  declare -a expected_cmd=(
    "ssh -q -o BatchMode=yes -o ConnectTimeout=5 -F ${SHUNIT_TMPDIR}/.kw/remote.config origin exit"
    "ssh -F ${SHUNIT_TMPDIR}/.kw/remote.config origin"
  )

  # Remote
  output=$(kw_ssh test_mode)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_kw_ssh_command()
{
  local output

  declare -a expected_cmd=(
    "ssh -q -o BatchMode=yes -o ConnectTimeout=5 -F ${SHUNIT_TMPDIR}/.kw/remote.config origin exit"
    "ssh -F ${SHUNIT_TMPDIR}/.kw/remote.config origin pwd"
  )

  output=$(kw_ssh test_mode -c 'pwd')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  output=$(kw_ssh test_mode --command "ls /etc/" 2>&1)
  expected_cmd[1]="ssh -F ${SHUNIT_TMPDIR}/.kw/remote.config origin ls /etc/"
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_kw_ssh_script()
{
  local output
  local msg

  ret=$(kw_ssh test_mode -s "/not/a/valid/path/xpto" 2>&1)
  msg="$NO_SUCH_FILE: /not/a/valid/path/xpto"
  assertTrue "($LINENO): We expected a substring '$msg', but we got '$ret'" \
    '[[ $ret =~ "$msg" ]]'

  declare -a expected_cmd=(
    "ssh -q -o BatchMode=yes -o ConnectTimeout=5 -F ${SHUNIT_TMPDIR}/.kw/remote.config origin exit"
    "ssh -F ${SHUNIT_TMPDIR}/.kw/remote.config origin \"bash -s\" -- < $TEST_PATH/dmesg"
  )

  output=$(kw_ssh test_mode -s "${TEST_PATH}/dmesg" 2>&1)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

invoke_shunit
