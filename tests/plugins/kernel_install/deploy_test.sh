#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "cmd_manager_Test"
  suite_addTest "ask_yN_Test"
}

function oneTimeSetUp
{
  mock_target_machine "$TMP_TEST_DIR"
}

function oneTimeTearDown
{
  rm -rf "$TMP_TEST_DIR"
}

declare -r TEST_ROOT_PATH="$PWD"

function setUp
{
  local current_path="$PWD"
  export HOME="$TMP_TEST_DIR"
  # Usually, we want to include external scripts at the beginning of the file;
  # however, in this particular case, we are simulating a remote machine
  # deployment that requires including the file after changing the value of the
  # home variable.
  . ./src/plugins/kernel_install/deploy.sh --source-only > /dev/null
}

function tearDown
{
  cd "$TEST_ROOT_PATH"
}

function cmd_manager_Test
{
  local count=0
  local current_path="$PWD"

  output=$(cmd_manager "TEST_MODE" "ls something")
  assert_equals_helper "TEST_MODE" "$LINENO" "ls something" "$output"
}

function ask_yN_Test
{
  local count=0
  local current_path="$PWD"

  output=$(echo 'y' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "1" "$output"

  output=$(echo 'Y' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "1" "$output"

  output=$(echo 'Yes' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "1" "$output"

  output=$(echo 'Sim' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "0" "$output"

  output=$(echo 'No' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "0" "$output"

  output=$(echo 'N' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "0" "$output"
}

invoke_shunit
