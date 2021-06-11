#!/bin/bash

include './src/plugins/subsystems/drm/drm.sh'
include './src/kwlib.sh'
include './tests/utils'

function suite()
{
  suite_addTest "gui_control_Test"
  suite_addTest "drm_manager_Test"
  suite_addTest "get_supported_mode_per_connector_Test"
  #suite_addTest "get_available_connectors_Test"
  suite_addTest "module_control_Test"
  suite_addTest "convert_module_info_Test"
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

function drm_manager_Test()
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

function gui_control_Test()
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

function get_available_connectors_Test()
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

function get_supported_mode_per_connector_Test()
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

function module_control_Test()
{
  local ID
  local default_ssh="ssh -p 22 root@localhost"

  ID=1
  expected="sudo bash -c \"modprobe  amdgpu\""
  output=$(module_control "LOAD" "2" "" "amdgpu" "TEST_MODE")
  assertEquals "$ID - Simple module load" "$expected" "$output"

  ID=2
  expected="sudo bash -c \"modprobe  amdgpu && modprobe  vkms\""
  output=$(module_control "LOAD" "2" "" "amdgpu;vkms" "TEST_MODE")
  assertEquals "$ID - Load two different modules" "$expected" "$output"

  ID=3
  expected="sudo bash -c \"modprobe  amdgpu tmz=1 dc=1  && modprobe  vkms enable_cursor=1 \""
  output=$(module_control "LOAD" "2" "" "amdgpu:tmz=1,dc=1;vkms:enable_cursor=1" "TEST_MODE")
  assertEquals "$ID - Load modules with parameters" "$expected" "$output"

  ID=4
  expected="sudo bash -c \"modprobe  amdgpu tmz=1 dc=1  && modprobe  vkms enable_cursor=1 \""
  output=$(module_control "LOAD" "2" "" "amdgpu:tmz=1,dc=1;vkms:enable_cursor=1" "TEST_MODE")
  assertEquals "$ID - Load modules with parameters" "$expected" "$output"

  ID=5
  expected="sudo bash -c \"modprobe -r amdgpu\""
  output=$(module_control "UNLOAD" "2" "" "amdgpu" "TEST_MODE")
  assertEquals "$ID - Load modules with parameters" "$expected" "$output"

  ID=6
  expected="sudo bash -c \"modprobe -r amdgpu && modprobe -r vkms\""
  output=$(module_control "UNLOAD" "2" "" "amdgpu;vkms" "TEST_MODE")
  assertEquals "$ID - Load modules with parameters" "$expected" "$output"

  ID=7
  output=$(module_control "UNLOAD" "2" "" "" "TEST_MODE")
  assertEquals "$ID - It is required the driver name" "22" "$?"

  ID=8
  output=$(module_control "LOAD" "2" "" "" "TEST_MODE")
  assertEquals "$ID - It is required the driver name" "22" "$?"

  ID=9
  expected="$default_ssh \"modprobe  amdgpu && modprobe  vkms\""
  output=$(module_control "LOAD" "3" "" "amdgpu;vkms" "TEST_MODE")
  assertEquals "$ID - Load modules with parameters" "$expected" "$output"

  ID=10
  expected="$default_ssh \"modprobe -r amdgpu && modprobe -r vkms\""
  output=$(module_control "UNLOAD" "3" "" "amdgpu;vkms" "TEST_MODE")
  assertEquals "$ID - Load modules with parameters" "$expected" "$output"
}
#compare_command_sequence expected_cmd[@] "$output" "$ID"

function convert_module_info_Test()
{
  local ID

  ID=1
  output=$(convert_module_info "LOAD" "amdgpu;vkms")
  expected="modprobe  amdgpu && modprobe  vkms"
  assertEquals "$ID" "$expected" "$output"

  ID=2
  output=$(convert_module_info "LOAD" "amdgpu;vkms;lala;xpto")
  expected="modprobe  amdgpu && modprobe  vkms && modprobe  lala && modprobe  xpto"
  assertEquals "$ID" "$expected" "$output"

  ID=3
  output=$(convert_module_info "LOAD" "amdgpu:dc=0,emu_mode=1,vm_debug=0;vkms enable_cursor=1")
  expected="modprobe  amdgpu dc=0 emu_mode=1 vm_debug=0  && modprobe  vkms enable_cursor=1"
  assertEquals "$ID" "$expected" "$output"

  ID=4
  output=$(convert_module_info "UNLOAD" "amdgpu;vkms;xpto")
  expected="modprobe -r amdgpu && modprobe -r vkms && modprobe -r xpto"
  assertEquals "$ID" "$expected" "$output"

  ID=5
  output=$(convert_module_info "LOAD" "")
  assertEquals "$ID" "$?" "22"
}

invoke_shunit
