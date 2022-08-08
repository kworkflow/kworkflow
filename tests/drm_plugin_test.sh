#!/bin/bash

include './src/plugins/subsystems/drm/drm.sh'
include './src/kwlib.sh'
include './tests/utils.sh'

function setUp()
{
  # Create a temporary directory for holding different config file
  export FAKE_DRM_SYSFS="${SHUNIT_TMPDIR}/sys/class/drm"
  export original_dir="$PWD"
  export SYSFS_CLASS_DRM="$FAKE_DRM_SYSFS"

  mkdir -p "$FAKE_DRM_SYSFS"

  cp "${SAMPLES_DIR}/kworkflow_drm_plugin.config" "${SHUNIT_TMPDIR}/kworkflow.config"
  cp "${SAMPLES_DIR}/deploy_remote.config" "${SHUNIT_TMPDIR}/deploy.config"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move into fake kernel directory"
    return
  }

  # Prepare fake sysfs
  mk_fake_sys_class_drm

  # Parser default config file for the average case
  parse_configuration "$KW_CONFIG_SAMPLE"
}

function tearDown()
{
  configurations=()
  configurations[ssh_user]=juca

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move into $original_dir"
    return
  }

  if [[ -d "$SHUNIT_TMPDIR" ]]; then
    rm -rf "$SHUNIT_TMPDIR"
  fi
}

function mk_fake_sys_class_drm()
{
  declare -a fake_dirs=(
    "card0"
    "card0-DP-1"
    "card0-DP-2"
    "card0-DP-3"
    "card0-DVI-D-1"
    "card0-HDMI-A-1"
    "card1"
    "card1-DP-4"
    "card1-DP-5"
    "card1-DP-6"
    "card1-HDMI-A-2"
    "renderD128"
    "renderD129"
    "ttm")

  for dir in "${fake_dirs[@]}"; do
    mkdir -p "${FAKE_DRM_SYSFS}/${dir}"
  done

  touch "${FAKE_DRM_SYSFS}/version"
  touch "${FAKE_DRM_SYSFS}/card0-DP-3/modes"

  cat << END >> "${FAKE_DRM_SYSFS}/card0-DP-3/modes"
1920x2160
2560x1440
1920x1080
1680x1050
1280x1024
1440x900
1280x960
1152x864
1280x720
1440x576
1024x768
1440x480
800x600
720x576
720x480
640x480
720x400
END

  cat << END >> "${FAKE_DRM_SYSFS}/card1-HDMI-A-2/modes"
2560x1440
1920x1080
1280x1024
640x480
720x400
END
}

function test_drm_parser_options()
{
  parse_drm_options --remote 'jozzi@something:3232'
  assertEquals "($LINENO)" 'something' "${remote_parameters['REMOTE_IP']}"
  assertEquals "($LINENO)" '3232' "${remote_parameters['REMOTE_PORT']}"
  assertEquals "($LINENO)" 'jozzi' "${remote_parameters['REMOTE_USER']}"
  assertEquals "($LINENO)" 3 "${options_values['TARGET']}"

  parse_drm_options --local
  assertEquals "($LINENO)" 2 "${options_values['TARGET']}"

  assertEquals "($LINENO)" '' "${options_values['GUI_ON']}"
  assertEquals "($LINENO)" '' "${options_values['GUI_OFF']}"
  assertEquals "($LINENO)" '' "${options_values['CONN_AVAILABLE']}"
  assertEquals "($LINENO)" '' "${options_values['MODES_AVAILABLE']}"

  parse_drm_options --gui-on
  assertEquals "($LINENO)" 1 "${options_values['GUI_ON']}"

  parse_drm_options --gui-off
  assertEquals "($LINENO)" 1 "${options_values['GUI_OFF']}"

  parse_drm_options --conn-available
  assertEquals "($LINENO)" 1 "${options_values['CONN_AVAILABLE']}"

  parse_drm_options --modes
  assertEquals "($LINENO)" 1 "${options_values['MODES_AVAILABLE']}"

  parse_drm_options --load-module 'amdgpu'
  assertEquals "($LINENO)" 'amdgpu' "${options_values['LOAD_MODULE']}"

  # Validate module load
  parse_drm_options --load-module 'amdgpu:dc=0'
  assertEquals "($LINENO)" 'amdgpu:dc=0' "${options_values['LOAD_MODULE']}"

  parse_drm_options --load-module 'amdgpu:dc=0,cik_support=1'
  assertEquals "($LINENO)" 'amdgpu:dc=0,cik_support=1' "${options_values['LOAD_MODULE']}"

  parse_drm_options --load-module 'amdgpu:dc=0,cik_support=1,vkms'
  assertEquals "($LINENO)" 'amdgpu:dc=0,cik_support=1,vkms' "${options_values['LOAD_MODULE']}"

  parse_drm_options --load-module 'amdgpu:dc=0,cik_support=1,vkms:enable_writeback=1'
  assertEquals "($LINENO)" 'amdgpu:dc=0,cik_support=1,vkms:enable_writeback=1' "${options_values['LOAD_MODULE']}"

  parse_drm_options --load-module 'amdgpu:dc=0,cik_support=1,vkms:enable_writeback=1,enable_overlay=0'
  assertEquals "($LINENO)" 'amdgpu:dc=0,cik_support=1,vkms:enable_writeback=1,enable_overlay=0' "${options_values['LOAD_MODULE']}"

  # Validate unload module
  parse_drm_options --unload-module 'amdgpu'
  assertEquals "($LINENO)" 'amdgpu' "${options_values['UNLOAD_MODULE']}"

  parse_drm_options --unload-module='amdgpu,drm'
  assertEquals "($LINENO)" 'amdgpu,drm' "${options_values['UNLOAD_MODULE']}"
}

function test_gui_control_remote()
{
  local gui_on_cmd='systemctl isolate graphical.target'
  local gui_off_cmd='systemctl isolate multi-user.target'
  local bind_cmd='for i in /sys/class/vtconsole/*/bind; do printf "%s\n" 1 > $i; done; sleep 0.5'
  local unbind_cmd='for i in /sys/class/vtconsole/*/bind; do printf "%s\n" 0 > $i; done; sleep 0.5'
  local output

  # Remote
  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='8888'
  remote_parameters['REMOTE_USER']='juca'

  tearDown # We want to test the default cases first
  # REMOTE = 3
  ssh_part="ssh -p 8888 juca@127.0.0.1"
  full_turn_on_gui_cmd="${ssh_part} sudo \"${gui_on_cmd}\""
  full_bind_cmd="${ssh_part} 'sudo bash -c '\''${bind_cmd}'\'"

  declare -a expected_cmd_seq=(
    "$full_turn_on_gui_cmd"
    "$full_bind_cmd"
  )

  output=$(gui_control 'ON' '3' '127.0.0.1:8888' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd_seq' "$output"

  full_turn_off_gui_cmd="${ssh_part} sudo \"${gui_off_cmd}\""
  full_unbind_cmd="$ssh_part 'sudo bash -c '\''${unbind_cmd}'\'"

  declare -a expected_cmd_seq=(
    "$full_turn_off_gui_cmd"
    "$full_unbind_cmd"
  )

  output=$(gui_control 'OFF' '3' '127.0.0.1:8888' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd_seq' "$output"

  # Test with config file
  parse_configuration "$KW_CONFIG_SAMPLE"

  # Remote
  remote_parameters['REMOTE_PORT']='3333'

  gui_off_cmd='turn off'
  ssh_part="ssh -p 3333 juca@127.0.0.1"
  full_turn_off_gui_cmd="${ssh_part} sudo \"${gui_off_cmd}\""
  full_unbind_cmd="${ssh_part} 'sudo bash -c '\''${unbind_cmd}'\'"

  declare -a expected_cmd_seq=(
    "$full_turn_off_gui_cmd"
    "$full_unbind_cmd"
  )

  output=$(gui_control 'OFF' '3' '' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd_seq' "$output"

  gui_on_cmd='turn on'
  full_turn_on_gui_cmd="${ssh_part} sudo \"${gui_on_cmd}\""
  full_bind_cmd="${ssh_part} 'sudo bash -c '\''${bind_cmd}'\'"

  declare -a expected_cmd_seq=(
    "$full_turn_on_gui_cmd"
    "$full_bind_cmd"
  )

  output=$(gui_control 'ON' '3' '' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd_seq' "$output"
}

function test_gui_control_local()
{
  local gui_on_cmd='systemctl isolate graphical.target'
  local gui_off_cmd='systemctl isolate multi-user.target'
  local bind_cmd='for i in /sys/class/vtconsole/*/bind; do printf "%s\n" 1 > $i; done; sleep 0.5'
  local unbind_cmd='for i in /sys/class/vtconsole/*/bind; do printf "%s\n" 0 > $i; done; sleep 0.5'
  local output

  configurations[gui_on]="$gui_on_cmd"
  configurations[gui_off]="$gui_off_cmd"

  declare -a expected_cmd_seq=(
    "sudo ${gui_on_cmd}"
    "sudo ${bind_cmd}"
  )

  output=$(gui_control 'ON' '2' '' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd_seq' "$output"

  declare -a expected_cmd_seq=(
    "sudo ${gui_off_cmd}"
    "sudo ${unbind_cmd}"
  )

  output=$(gui_control 'OFF' '2' '' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd_seq' "$output"
}

function test_get_available_connectors_local()
{
  local output

  declare -a expected_output=(
    '[local] Card1 supports:'
    'DP'
    'DP'
    'DP'
    'HDMI'
    '[local] Card0 supports:'
    'DP'
    'DP'
    'DP'
    'DVI'
    'HDMI'
  )

  # Local
  output=$(get_available_connectors '2' '' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"
}

function test_get_available_connectors_remote()
{
  local output

  # Remote
  output=$(
    function cmd_remotely()
    {
      printf '/sys/class/drm/card0-%s-1\n' 'DP'
      printf '/sys/class/drm/card0-%s-1\n' 'eDP'
    }
    get_available_connectors '3' '' 'TEST_MODE'
  )

  declare -a expected_output=(
    '[remote] Card0 supports:'
    'DP'
    'eDP'
  )
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"
}

function test_get_supported_mode_per_connector()
{
  declare -a expected_output=(
    "Modes per card"
    "${SHUNIT_TMPDIR}/card0-DP-3:"
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
    "${SHUNIT_TMPDIR}/card1-HDMI-A-2:"
    "2560x1440"
    "1920x1080"
    "1280x1024"
    "640x480"
    "720x400"
  )

  export SYSFS_CLASS_DRM="$FAKE_DRM_SYSFS"
  output=$(get_supported_mode_per_connector 2)
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"
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

function test_convert_module_info()
{
  output=$(convert_module_info "LOAD" "amdgpu;vkms")
  expected="modprobe  amdgpu && modprobe  vkms"
  assertEquals "$LINENO" "$expected" "$output"

  output=$(convert_module_info "LOAD" "amdgpu;vkms;lala;xpto")
  expected="modprobe  amdgpu && modprobe  vkms && modprobe  lala && modprobe  xpto"
  assertEquals "$LINENO" "$expected" "$output"

  output=$(convert_module_info "LOAD" "amdgpu:dc=0,emu_mode=1,vm_debug=0;vkms enable_cursor=1")
  expected="modprobe  amdgpu dc=0 emu_mode=1 vm_debug=0  && modprobe  vkms enable_cursor=1"
  assertEquals "$LINENO" "$expected" "$output"

  output=$(convert_module_info "UNLOAD" "amdgpu;vkms;xpto")
  expected="modprobe -r amdgpu && modprobe -r vkms && modprobe -r xpto"
  assertEquals "$LINENO" "$expected" "$output"

  output=$(convert_module_info "LOAD" "")
  assertEquals "$LINENO" "$?" "22"
}

invoke_shunit
