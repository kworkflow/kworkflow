#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "human_list_installed_kernels_Test"
  suite_addTest "comman_list_installed_kernels_Test"
  suite_addTest "cmd_manager_Test"
  suite_addTest "ask_yN_Test"
}

declare -r TEST_ROOT_PATH="$PWD"

function setUp
{
  rm -rf "$TMP_TEST_DIR"

  local current_path="$PWD"

  mk_fake_boot "$TMP_TEST_DIR"
}

function tearDown()
{
  rm -rf "$TMP_TEST_DIR"
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


function human_list_installed_kernels_Test
{
  local count=0

  declare -a expected_out=(
    "" # Extra espace in the beginning
    "5.5.0-rc2-VKMS+"
    "5.6.0-rc2-AMDGPU+"
    "linux"
  )

  output=$(list_installed_kernels "0" "$TMP_TEST_DIR")
  while read out; do
    assertEquals "$count - Expected kernel list" "${expected_out[$count]}" "$out"
    ((count++))
  done <<< "$output"
}

function comman_list_installed_kernels_Test
{
  local count=0

  declare -a expected_out=(
    "" # Extra espace in the beginning
    "5.5.0-rc2-VKMS+,5.6.0-rc2-AMDGPU+,linux"
  )

  output=$(list_installed_kernels "1" "$TMP_TEST_DIR")
  while read out; do
    assertEquals "$count - Expected kernel list" "${expected_out[$count]}" "$out"
    ((count++))
  done <<< "$output"

}

invoke_shunit
