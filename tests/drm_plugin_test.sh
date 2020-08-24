#!/bin/bash

. ./src/plugins/subsystems/drm/drm.sh --source-only
. ./src/kwlib.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "gui_control_Test"
  suite_addTest "drm_manager_Test"
  suite_addTest "get_supported_mode_per_connector_Test"
  #suite_addTest "get_available_connectors_Test"
}

function setUp()
{
  # Create a temporary directory for holding different config file
  local -r current_path="$PWD"
  rm -rf "$TMP_TEST_DIR"
  mkdir -p "$TMP_TEST_DIR"

  cp "$SAMPLES_DIR/kworkflow_drm_plugin.config" "$TMP_TEST_DIR/kworkflow.config"

  # Prepare fake sysfs
  mk_fake_sys_class_drm

  # Parser default config file for the average case
  parse_configuration "$KW_CONFIG_SAMPLE"
}

function tearDown()
{
  configurations=()

  rm -rf "$TMP_TEST_DIR"
}

function drm_manager_Test
{
  local ID

  parse_configuration "$TMP_TEST_DIR/kworkflow.config"

  ID=1
  output=$(drm_manager test_mode --remote --gui-on)
  expected_result="3 1 0 127.0.0.1:3333"
  assertEquals "($ID) Remote and --gui-on:" "$expected_result" "$output"

  ID=2
  output=$(drm_manager test_mode --remote --gui-off)
  expected_result="3 0 1 127.0.0.1:3333"
  assertEquals "($ID) Remote and --gui-off:" "$expected_result" "$output"

  ID=3
  output=$(drm_manager test_mode --gui-on)
  expected_result="3 1 0 127.0.0.1:3333"
  assertEquals "($ID) just --gui-on:" "$expected_result" "$output"

  ID=4
  output=$(drm_manager test_mode --gui-off)
  expected_result="3 0 1 127.0.0.1:3333"
  assertEquals "($ID) just --gui-off:" "$expected_result" "$output"

  # Invalid options
  ID=5
  output=$(drm_manager test_mode --vm --gui-on)
  assertEquals "($ID) Should not accept --vm:" "$?" "22"
}

function gui_control_Test
{
  local gui_on_cmd='systemctl isolate graphical.target'
  local gui_off_cmd='systemctl isolate multi-user.target'
  local bind_cmd='for i in /sys/class/vtconsole/*/bind; do echo 1 > $i; done; sleep 0.5'
  local unbind_cmd='for i in /sys/class/vtconsole/*/bind; do echo 0 > $i; done; sleep 0.5'
  local output
  local ID

  tearDown # We want to test the default cases first
  # REMOTE = 3
  ID=1
  ssh_part='ssh -p 8888 root@127.0.0.1'
  full_turn_on_gui_cmd="$ssh_part \"$gui_on_cmd\""
  full_bind_cmd="$ssh_part '$bind_cmd'"

  declare -a expected_cmd_seq=(
    "$full_turn_on_gui_cmd"
    "$full_bind_cmd"
  )

  output=$(gui_control 'ON' '3' '127.0.0.1:8888' 'TEST_MODE')
  compare_command_sequence expected_cmd_seq[@] "$output" "$ID"

  ID=2
  full_turn_off_gui_cmd="$ssh_part \"$gui_off_cmd\""
  full_unbind_cmd="$ssh_part '$unbind_cmd'"

  declare -a expected_cmd_seq=(
    "$full_turn_off_gui_cmd"
    "$full_unbind_cmd"
  )

  output=$(gui_control 'OFF' '3' '127.0.0.1:8888' 'TEST_MODE')
  compare_command_sequence expected_cmd_seq[@] "$output" "$ID"

  ID=3
  # Test with config file
  parse_configuration "$KW_CONFIG_SAMPLE"

  gui_off_cmd='turn off'
  ssh_part='ssh -p 22 root@localhost'
  full_turn_off_gui_cmd="$ssh_part \"$gui_off_cmd\""
  full_unbind_cmd="$ssh_part '$unbind_cmd'"

  declare -a expected_cmd_seq=(
    "$full_turn_off_gui_cmd"
    "$full_unbind_cmd"
  )

  output=$(gui_control 'OFF' '3' '' 'TEST_MODE')
  compare_command_sequence expected_cmd_seq[@] "$output" "$ID"

  ID=4
  gui_on_cmd='turn on'
  full_turn_on_gui_cmd="$ssh_part \"$gui_on_cmd\""
  full_bind_cmd="$ssh_part '$bind_cmd'"

  declare -a expected_cmd_seq=(
    "$full_turn_on_gui_cmd"
    "$full_bind_cmd"
  )

  output=$(gui_control 'ON' '3' '' 'TEST_MODE')
  compare_command_sequence expected_cmd_seq[@] "$output" "$ID"
}

function get_available_connectors_Test
{
  local ID
  export SYSFS_CLASS_DRM="$FAKE_DRM_SYSFS"

  declare -a expected_output=(
    "[local] Card1 supports:"
    "DP"
    "DP"
    "HDMI"
    "DP"
    "[local] Card0 supports:"
    "DP"
    "DP"
    "DP"
    "HDMI"
    "DVI"
  )

  ID=1
  output=$(get_available_connectors 2)
  compare_command_sequence expected_output[@] "$output" "$ID"
}

function get_supported_mode_per_connector_Test
{
  declare -a expected_output=(
    "Modes per card"
    "tests/.tmp/card0-DP-3:"
    "1920x2160"
    "2560x1440"
    "1920x1080"
    "1680x1050"
    "1280x1024"
    "1440x900"
    "1280x960"
    "1152x864"
    "1280x720"
    "1440x576"
    "1024x768"
    "1440x480"
    "800x600"
    "720x576"
    "720x480"
    "640x480"
    "720x400"
    ""
    "tests/.tmp/card1-HDMI-A-2:"
    "2560x1440"
    "1920x1080"
    "1280x1024"
    "640x480"
    "720x400"
  )

  ID=1

  export SYSFS_CLASS_DRM="$FAKE_DRM_SYSFS"
  output=$(get_supported_mode_per_connector 2)
  compare_command_sequence expected_output[@] "$output" "$ID"
}

invoke_shunit
