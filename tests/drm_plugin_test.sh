#!/bin/bash

include './src/plugins/subsystems/drm/drm.sh'
include './src/kwlib.sh'
include './tests/utils.sh'

function setUp()
{
  # Create a temporary directory for holding different config file
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
  configurations[ssh_user]=juca

  rm -rf "$TMP_TEST_DIR"
}

function test_drm_manager()
{
  local output

  parse_configuration "$TMP_TEST_DIR/kworkflow.config"

  output=$(drm_manager test_mode --remote --gui-on)
  expected_result='3 1 0 127.0.0.1 3333'
  assertEquals "($LINENO) Remote and --gui-on:" "$expected_result" "$output"

  output=$(drm_manager test_mode --remote --gui-off)
  expected_result='3 0 1 127.0.0.1 3333'
  assertEquals "($LINENO) Remote and --gui-off:" "$expected_result" "$output"

  output=$(drm_manager test_mode --gui-on)
  expected_result='3 1 0 127.0.0.1 3333'
  assertEquals "($LINENO) just --gui-on:" "$expected_result" "$output"

  output=$(drm_manager test_mode --gui-off)
  expected_result='3 0 1 127.0.0.1 3333'
  assertEquals "($LINENO) just --gui-off:" "$expected_result" "$output"

  # Invalid options
  output=$(drm_manager test_mode --vm --gui-on)
  assertEquals "($LINENO) Should not accept --vm:" "$?" 22
}

function test_gui_control()
{
  local gui_on_cmd='systemctl isolate graphical.target'
  local gui_off_cmd='systemctl isolate multi-user.target'
  local bind_cmd='for i in /sys/class/vtconsole/*/bind; do printf "%s\n" 1 > $i; done; sleep 0.5'
  local unbind_cmd='for i in /sys/class/vtconsole/*/bind; do printf "%s\n" 0 > $i; done; sleep 0.5'
  local output
  local ID

  tearDown # We want to test the default cases first
  # REMOTE = 3
  ID=1
  ssh_part="ssh -p 8888 juca@127.0.0.1"
  full_turn_on_gui_cmd="$ssh_part sudo \"$gui_on_cmd\""
  full_bind_cmd="$ssh_part 'sudo bash -c '\''$bind_cmd'\'"

  declare -a expected_cmd_seq=(
    "$full_turn_on_gui_cmd"
    "$full_bind_cmd"
  )

  output=$(gui_control 'ON' '3' '127.0.0.1:8888' 'TEST_MODE')
  compare_command_sequence 'expected_cmd_seq' "$output" "$ID"

  ID=2
  full_turn_off_gui_cmd="$ssh_part sudo \"$gui_off_cmd\""
  full_unbind_cmd="$ssh_part 'sudo bash -c '\''$unbind_cmd'\'"

  declare -a expected_cmd_seq=(
    "$full_turn_off_gui_cmd"
    "$full_unbind_cmd"
  )

  output=$(gui_control 'OFF' '3' '127.0.0.1:8888' 'TEST_MODE')
  compare_command_sequence 'expected_cmd_seq' "$output" "$ID"

  ID=3
  # Test with config file
  parse_configuration "$KW_CONFIG_SAMPLE"

  gui_off_cmd='turn off'
  ssh_part="ssh -p 3333 juca@127.0.0.1"
  full_turn_off_gui_cmd="$ssh_part sudo \"$gui_off_cmd\""
  full_unbind_cmd="$ssh_part 'sudo bash -c '\''$unbind_cmd'\'"

  declare -a expected_cmd_seq=(
    "$full_turn_off_gui_cmd"
    "$full_unbind_cmd"
  )

  output=$(gui_control 'OFF' '3' '' 'TEST_MODE')
  compare_command_sequence 'expected_cmd_seq' "$output" "$ID"

  ID=4
  gui_on_cmd='turn on'
  full_turn_on_gui_cmd="$ssh_part sudo \"$gui_on_cmd\""
  full_bind_cmd="$ssh_part 'sudo bash -c '\''$bind_cmd'\'"

  declare -a expected_cmd_seq=(
    "$full_turn_on_gui_cmd"
    "$full_bind_cmd"
  )

  output=$(gui_control 'ON' '3' '' 'TEST_MODE')
  compare_command_sequence 'expected_cmd_seq' "$output" "$ID"
}

function test_get_supported_mode_per_connector()
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
  compare_command_sequence 'expected_output' "$output" "$ID"
}

function test_module_control()
{
  local default_ssh='ssh -p 3333 juca@127.0.0.1 sudo'

  expected="sudo bash -c \"modprobe  amdgpu\""
  output=$(module_control "LOAD" "2" "" "amdgpu" "TEST_MODE")
  assertEquals "($LINENO): Simple module load" "$expected" "$output"

  expected="sudo bash -c \"modprobe  amdgpu && modprobe  vkms\""
  output=$(module_control "LOAD" "2" "" "amdgpu;vkms" "TEST_MODE")
  assertEquals "($LINENO): Load two different modules" "$expected" "$output"

  expected="sudo bash -c \"modprobe  amdgpu tmz=1 dc=1  && modprobe  vkms enable_cursor=1 \""
  output=$(module_control "LOAD" "2" "" "amdgpu:tmz=1,dc=1;vkms:enable_cursor=1" "TEST_MODE")
  assertEquals "($LINENO): Load modules with parameters" "$expected" "$output"

  expected="sudo bash -c \"modprobe  amdgpu tmz=1 dc=1  && modprobe  vkms enable_cursor=1 \""
  output=$(module_control "LOAD" "2" "" "amdgpu:tmz=1,dc=1;vkms:enable_cursor=1" "TEST_MODE")
  assertEquals "($LINENO): Load modules with parameters" "$expected" "$output"

  expected="sudo bash -c \"modprobe -r amdgpu\""
  output=$(module_control "UNLOAD" "2" "" "amdgpu" "TEST_MODE")
  assertEquals "($LINENO): Load modules with parameters" "$expected" "$output"

  expected="sudo bash -c \"modprobe -r amdgpu && modprobe -r vkms\""
  output=$(module_control "UNLOAD" "2" "" "amdgpu;vkms" "TEST_MODE")
  assertEquals "($LINENO): Load modules with parameters" "$expected" "$output"

  output=$(module_control "UNLOAD" "2" "" "" "TEST_MODE")
  assertEquals "($LINENO): It is required the driver name" "22" "$?"

  output=$(module_control "LOAD" "2" "" "" "TEST_MODE")
  assertEquals "($LINENO): It is required the driver name" "22" "$?"

  expected="$default_ssh \"modprobe  amdgpu && modprobe  vkms\""
  output=$(module_control "LOAD" "3" "" "amdgpu;vkms" "TEST_MODE")
  assertEquals "($LINENO): Load modules with parameters" "$expected" "$output"

  expected="$default_ssh \"modprobe -r amdgpu && modprobe -r vkms\""
  output=$(module_control "UNLOAD" "3" "" "amdgpu;vkms" "TEST_MODE")
  assertEquals "($LINENO): Load modules with parameters" "$expected" "$output"
}
#compare_command_sequence 'expected_cmd' "$output" "$ID"

function test_convert_module_info()
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
