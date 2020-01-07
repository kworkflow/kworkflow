#!/bin/bash

. ./src/init.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "init_kw_Test"
}

FAKE_DIR="tests/.tmp"
FAKE_CONFIG_PATH="$FAKE_DIR/.config"

function setUp
{
  export etc_files_path="tests/samples"
  export HOME="$FAKE_DIR"
  export USER="kw_test"
  export EASY_KERNEL_WORKFLOW="kw_dir_test"
  export PWD="$FAKE_CONFIG_PATH/$EASY_KERNEL_WORKFLOW"
  mkdir -p "$FAKE_DIR"
  mkdir -p "$FAKE_CONFIG_PATH/$EASY_KERNEL_WORKFLOW"
}

function tearDown
{
  rm -rf "$FAKE_DIR"
}

function init_kw_Test
{
  local ID
  local kworkflow_content
  local output=$(init_kw)
  local path_config="$FAKE_CONFIG_PATH/$EASY_KERNEL_WORKFLOW/kworkflow.config"

  kworkflow_content=$(cat "$path_config" | grep "$USER" -o | head -n 1)

  ID=1
  assertEquals "($ID)" "$USER" "$kworkflow_content"

  ID=2
  kworkflow_content=$(cat "$path_config" | grep "$EASY_KERNEL_WORKFLOW" -o | head -n 1)
  assertEquals "($ID)" "$EASY_KERNEL_WORKFLOW" "$kworkflow_content"

  ID=3
  export etc_files_path="break/on/purpose"
  output=$(init_kw)
  ret="$?"
  assertEquals "($ID) We forced an error and expected to catch it" "2" "$ret"
}

invoke_shunit
