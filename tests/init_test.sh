#!/bin/bash

include './src/init.sh'
include './tests/utils.sh'

FAKE_DIR="tests/.tmp"
FAKE_CONFIG_PATH="$FAKE_DIR/.config"

function setUp()
{
  export KW_ETC_DIR="tests/samples"
  export KW_SHARE_SOUND_DIR="tests/samples/share/sound/kw"
  export HOME="$FAKE_DIR"
  export USER="kw_test"
  export KWORKFLOW="kw_dir_test"
  export PWD="$FAKE_CONFIG_PATH/$KWORKFLOW"
  mkdir -p "$FAKE_DIR"
  mkdir -p "$FAKE_CONFIG_PATH/$KWORKFLOW"
}

function tearDown()
{
  rm -rf "$FAKE_DIR"
}

function test_init_kw()
{
  local kworkflow_content
  local path_config="$FAKE_CONFIG_PATH/$KWORKFLOW/kworkflow.config"
  local output

  output=$(init_kw)

  kworkflow_content=$(grep "$USER" -o "$path_config" | head -n 1)

  assertEquals "($LINENO): USERKW wasn't updated to $USER" "$USER" "$kworkflow_content"

  kworkflow_content=$(grep "$KW_SHARE_SOUND_DIR" -o "$path_config" | head -n 1)
  assertEquals "($LINENO): SOUNDPATH wasn't updated to $KW_SHARE_SOUND_DIR" "$KW_SHARE_SOUND_DIR" "$kworkflow_content"

  export KW_ETC_DIR="break/on/purpose"
  output=$(init_kw)
  ret="$?"
  assertEquals "($LINENO): We forced an error and expected to catch it" "2" "$ret"
}

invoke_shunit
