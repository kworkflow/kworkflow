#!/bin/bash

include './src/init.sh'
include './tests/utils.sh'

function setUp()
{
  export KW_ETC_DIR="$PWD/tests/samples"
  export KW_SOUND_DIR="$PWD/tests/samples/share/sound/kw"
  export HOME="$SHUNIT_TMPDIR"
  export USER="kw_test"
  export KWORKFLOW="kw_dir_test"
  export PWD="$SHUNIT_TMPDIR/$KWORKFLOW"
  mkdir -p "$SHUNIT_TMPDIR/$KWORKFLOW"
}

function test_init_kw()
{
  local kworkflow_content
  local path="$SHUNIT_TMPDIR/$KWORKFLOW/$KW_DIR"
  local path_config="$path/kworkflow.config"
  local output

  declare -a expected_content=(
    'This arch was not found in the arch directory'
    'You can use --force next time if you want to proceed anyway'
    'Available architectures:'
    'arm64'
    'x86_64'
    "Initialized kworkflow directory in $SHUNIT_TMPDIR/$KWORKFLOW/$KW_DIR based on $USER data"
  )

  output=$(init_kw)
  assertEquals "($LINENO):" 'This command should be run in a kernel tree.' "$output"

  mk_fake_kernel_root "$SHUNIT_TMPDIR/$KWORKFLOW/"
  cd "$SHUNIT_TMPDIR/$KWORKFLOW/" || {
    fail "($LINENO): It was not possible to move to temporary directory"
    return
  }

  output=$(init_kw)
  kworkflow_content=$(grep "$USER" -o "$path_config" | head -n 1)
  assertEquals "($LINENO): USERKW wasn't updated to $USER" "$USER" "$kworkflow_content"

  kworkflow_content=$(grep "$KW_SOUND_DIR" -o "$path_config" | head -n 1)
  assertEquals "($LINENO): SOUNDPATH wasn't updated to $KW_SOUND_DIR" "$KW_SOUND_DIR" "$kworkflow_content"

  output=$(init_kw --force)
  if [[ ! -f "$path_config.old" ]]; then
    fail "($LINENO) We expected to find a 'kworkflow.config.old' file."
  fi

  expect='Initialization aborted!'
  output=$(echo 'n' | init_kw)
  assertEquals "($LINENO): The init proccess didn't abort correctly" "$expect" "$output"

  rm -rf "${path:?}"/*
  output=$(init_kw --arch arm64)
  kworkflow_content=$(grep arch= "$path_config")
  assertEquals "($LINENO):" 'arch=arm64' "$kworkflow_content"

  rm -rf "${path:?}"/*
  output=$(init_kw --arch baroque)
  kworkflow_content=$(grep arch= "$path_config")
  compare_command_sequence 'expected_content' "$output" "($LINENO)"

  output=$(init_kw --arch baroque --force)
  kworkflow_content=$(grep arch= "$path_config")
  assertEquals "($LINENO):" 'arch=baroque' "$kworkflow_content"

  rm -rf "${path:?}"/*
  output=$(init_kw --remote juca@123.456.789.123:2222)
  kworkflow_content=$(grep ssh_user= "$path_config")
  assertEquals "($LINENO)" 'ssh_user=juca' "$kworkflow_content"

  kworkflow_content=$(grep ssh_ip= "$path_config")
  assertEquals "($LINENO)" 'ssh_ip=123.456.789.123' "$kworkflow_content"

  kworkflow_content=$(grep ssh_port= "$path_config")
  assertEquals "($LINENO)" 'ssh_port=2222' "$kworkflow_content"

  rm -rf "${path:?}"/*
  expected_content=('Something went wrong with the remote option'
    'Invalid remote: :8888')
  output=$(init_kw --remote ':8888')
  assertEquals "($LINENO)" '22' "$?"
  compare_command_sequence 'expected_content' "$output" "($LINENO)"

  export KW_ETC_DIR="break/on/purpose"
  output=$(init_kw -f) # avoids the overwrite prompt
  ret="$?"
  assertEquals "($LINENO): We forced an error and expected to catch it" "2" "$ret"
}

function test_parse_init_options()
{
  unset options_values
  declare -gA options_values
  parse_init_options --force
  assertEquals "($LINENO):" '1' "${options_values['FORCE']}"

  unset options_values
  declare -gA options_values
  parse_init_options --arch arm
  assertEquals "($LINENO):" 'arm' "${options_values['ARCH']}"

  unset options_values
  declare -gA options_values
  parse_init_options --not-valid
  assertEquals "($LINENO)" '22' "$?"

  unset options_values
  unset remote_parameters
  declare -gA options_values
  declare -gA remote_parameters
  parse_init_options --remote 'user@127.0.2.1:8888'
  assertEquals "($LINENO):" 'user@127.0.2.1:8888' "${options_values['REMOTE']}"
}

invoke_shunit
