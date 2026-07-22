#!/usr/bin/env bash

include './src/get_device_info.sh'
include './tests/unit/utils.sh'

function oneTimeSetUp()
{
  shopt -s expand_aliases
}

function setUp()
{
  options_values['TARGET']="$LOCAL_TARGET"
  remote_parameters['REMOTE_USER']='john'
  remote_parameters['REMOTE_IP']='something'
  remote_parameters['REMOTE_PORT']='2222'
  RAW_JSON=''
  unset gpus
  declare -ga gpus
}

declare -gA configurations
configurations[ssh_user]=john

function test_get_ram_from_local()
{
  local cmd
  local output

  cmd='inxi --tty --width 1 --color 0 --memory-short'
  output=$(get_ram "$LOCAL_TARGET" 'VERBOSE')
  assert_equals_helper 'Local target RAM info gathering command did not match expectation' "($LINENO)" "$cmd" "$output"
}

function test_get_cpu_local()
{
  local output

  declare -a expected_cmd=(
    'inxi --tty --width 1 --color 0 --cpu'
    'uname --machine'
  )

  output=$(get_cpu 2 'TEST_MODE')

  compare_command_sequence 'inxi or unamed or both failed' "$LINENO" 'expected_cmd' "$output"
}

function test_get_cpu_remote()
{
  local output

  declare -a expected_cmd=(
    'inxi --tty --width 1 --color 0 --cpu'
    'uname --machine'
  )

  output=$(get_cpu 3 'TEST_MODE')

  compare_command_sequence 'inxi or unamed or both failed' "$LINENO" 'expected_cmd' "$output"
}

function test_get_disk()
{
  local cmd
  local output
  local expected_cmd

  expected_cmd='inxi --tty --width 1 --color 0 --partitions-full'
  output=$(get_disk 2 'TEST_MODE')

  assert_equals_helper 'Get disk did not match the expected command' "(${LINENO})" "$expected_cmd" "$output"
}

function test_get_motherboard()
{
  local cmd
  local output

  cmd='inxi --tty --width 1 --color 0 --machine'
  output=$(get_motherboard 2 'TEST_MODE')
  assert_equals_helper 'Wrong base ixi command' "(${LINENO})" "$cmd" "$output"
}

function test_get_chassis()
{
  local cmd
  local output

  cmd='inxi --tty --width 1 --color 0 --machine'
  output=$(get_chassis 2 'TEST_MODE')
  assert_equals_helper 'Wrong base inxi command' "($LINENO)" "$cmd" "$output"
}

function test_parse_dri_state_gnome_with_wayland()
{
  local dri_state_folder="$SHUNIT_TMPDIR"
  local original="$PWD"
  local expected_result_crtc_0=''
  local expected_result_crtc_1=''
  local raw_state=''

  cp "${SAMPLES_DIR}/dri/STATE_WAYLAND_GNOME" "$dri_state_folder"

  cd "$dri_state_folder" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  raw_state=$(< STATE_WAYLAND_GNOME)

  unset crtcs
  declare -gA crtcs
  parse_dri_state "$raw_state"

  expected_result_crtc_0='type=primary;resolution=3840x2160;color_encoding=ITU-R BT.601 YCbCr;refresh_rate=60;connector=DP-1;'
  expected_result_crtc_1='type=primary;resolution=2560x1440;color_encoding=ITU-R BT.601 YCbCr;refresh_rate=120;connector=DP-3;'

  assert_equals_helper 'Wrong match for crtc 0' "(${LINENO})" "$expected_result_crtc_0" "${crtcs['crtc-0']}"
  assert_equals_helper 'Wrong match for crtc 1' "(${LINENO})" "$expected_result_crtc_1" "${crtcs['crtc-1']}"

  cd "$original" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_parse_dri_state_gnome_with_x11()
{
  local dri_state_folder="$SHUNIT_TMPDIR"
  local original="$PWD"
  local expected_result_crtc_0=''
  local expected_result_crtc_1=''
  local raw_state=''

  cp "${SAMPLES_DIR}/dri/STATE_X11_GNOME" "$dri_state_folder"

  cd "$dri_state_folder" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  raw_state=$(< STATE_X11_GNOME)

  unset crtcs
  declare -gA crtcs
  parse_dri_state "$raw_state"

  expected_result_crtc_0='type=primary;resolution=7680x2160;color_encoding=ITU-R BT.601 YCbCr;refresh_rate=60;connector=DP-1;'
  expected_result_crtc_1='type=primary;resolution=7680x2160;color_encoding=ITU-R BT.601 YCbCr;refresh_rate=60;connector=DP-3;'

  assert_equals_helper 'Wrong match for crtc 0' "(${LINENO})" "$expected_result_crtc_0" "${crtcs['crtc-0']}"
  assert_equals_helper 'Wrong match for crtc 1' "(${LINENO})" "$expected_result_crtc_1" "${crtcs['crtc-1']}"

  cd "$original" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_check_inxi_version_local_above_minimum()
{
  function inxi()
  {
    printf '%s' '3.3.40'
  }

  check_inxi_version 'SILENT' 2
  assertEquals "(${LINENO}) Version above minimum should return 0" 0 "$?"
}

function test_check_inxi_version_local_exact_minimum()
{
  function inxi()
  {
    printf '%s' '3.3.34'
  }

  check_inxi_version 'SILENT' 2
  assertEquals "(${LINENO}) Version equal to minimum should return 0" 0 "$?"
}

function test_check_inxi_version_local_below_minimum()
{
  function inxi()
  {
    printf '%s' '3.3.33'
  }

  check_inxi_version 'SILENT' 2
  assertEquals "(${LINENO}) Version below minimum should return 1" 1 "$?"
}

function test_check_inxi_version_remote_above_minimum()
{
  function cmd_remotely()
  {
    printf '%s' '3.3.35'
  }

  check_inxi_version 'SILENT' 3
  assertEquals "(${LINENO}) Remote version above minimum should return 0" 0 "$?"
}

function test_get_jq_cmd_memory_total()
{
  local raw_json
  local jq_cmd
  local output

  raw_json=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")
  jq_cmd=$(get_jq_cmd 'Memory' 'total')
  output=$(eval "${jq_cmd} <<< '${raw_json}'")

  assert_equals_helper 'Memory total did not match sample' "(${LINENO})" '16 GiB' "$output"
}

function test_get_jq_cmd_memory_type()
{
  local raw_json
  local jq_cmd
  local output

  raw_json=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")
  jq_cmd=$(get_jq_cmd 'Memory' 'type')
  output=$(eval "${jq_cmd} <<< '${raw_json}'")

  assert_equals_helper 'Memory type did not match sample' "(${LINENO})" 'DDR4' "$output"
}

function test_get_jq_cmd_cpu_model()
{
  local raw_json
  local jq_cmd
  local output

  raw_json=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")
  jq_cmd=$(get_jq_cmd 'CPU' 'model')
  output=$(eval "${jq_cmd} <<< '${raw_json}'")

  assert_equals_helper 'CPU model did not match sample' "(${LINENO})" \
    'AMD Ryzen 5 5600G with Radeon Graphics' "$output"
}

function test_get_jq_cmd_cpu_avg_speed()
{
  local raw_json
  local jq_cmd
  local output

  raw_json=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")
  jq_cmd=$(get_jq_cmd 'CPU' 'avg')
  output=$(eval "${jq_cmd} <<< '${raw_json}'")

  assert_equals_helper 'CPU average speed did not match sample' "(${LINENO})" '2976' "$output"
}

function test_get_desktop_environment_local_cmd()
{
  local ux_regx
  local expected_cmd
  local output

  ux_regx="'gnome-shell\$|kde|mate|cinnamon|lxsession|gamescope|openbox\$'"
  expected_cmd='ps -A | grep --invert-match dev | grep --ignore-case'
  expected_cmd+=" --only-matching --extended-regexp --max-count=1 ${ux_regx}"

  output=$(get_desktop_environment "$LOCAL_TARGET" 'TEST_MODE')

  assert_equals_helper 'Wrong local command for get_desktop_environment' \
    "(${LINENO})" "$expected_cmd" "$output"
}

function test_get_desktop_environment_remote_cmd()
{
  local ux_regx
  local expected_cmd
  local output

  ux_regx="'gnome-shell\$|kde|mate|cinnamon|lxsession|gamescope|openbox\$'"
  expected_cmd='ps -A | grep --invert-match dev | grep --ignore-case'
  expected_cmd+=" --only-matching --extended-regexp --max-count=1 ${ux_regx}"

  output=$(get_desktop_environment "$REMOTE_TARGET" 'TEST_MODE')

  assert_equals_helper 'Wrong remote command for get_desktop_environment' \
    "(${LINENO})" "$expected_cmd" "$output"
}

function test_get_desktop_environment_from_json()
{
  RAW_JSON=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")

  get_desktop_environment "$LOCAL_TARGET" 'SILENT'

  assert_equals_helper 'Desktop environment from JSON did not match sample' \
    "(${LINENO})" 'kde' "${device_info_data['compositor']}"
}

function test_get_ram_from_json()
{
  RAW_JSON=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")

  get_ram 'SILENT'

  assert_equals_helper 'RAM total from JSON did not match sample' \
    "(${LINENO})" '16 GiB' "${device_info_data['ram_total']}"
  assert_equals_helper 'RAM available from JSON did not match sample' \
    "(${LINENO})" '15.42 GiB' "${device_info_data['ram_available']}"
  assert_equals_helper 'RAM type from JSON did not match sample' \
    "(${LINENO})" 'DDR4' "${device_info_data['ram_type']}"
  assert_equals_helper 'RAM capacity from JSON did not match sample' \
    "(${LINENO})" '128 GiB' "${device_info_data['ram_capacity']}"
  assert_equals_helper 'RAM installed from JSON did not match sample' \
    "(${LINENO})" '16 GiB' "${device_info_data['ram_installed']}"
}

function test_get_cpu_from_json()
{
  RAW_JSON=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")

  get_cpu "$LOCAL_TARGET" 'SILENT'

  assert_equals_helper 'CPU model name from JSON did not match sample' \
    "(${LINENO})" 'AMD Ryzen 5 5600G with Radeon Graphics' "${device_info_data['cpu_model_name']}"
  assert_equals_helper 'CPU speed from JSON did not match sample' \
    "(${LINENO})" '2976' "${device_info_data['cpu_speed']}"
  assert_equals_helper 'CPU total cores from JSON did not match sample' \
    "(${LINENO})" '6-core' "${device_info_data['cpu_total_cores']}"
  assert_equals_helper 'CPU architecture from JSON did not match sample' \
    "(${LINENO})" 'x86_64' "${device_info_data['cpu_architecture']}"
}

function test_get_disk_from_json()
{
  RAW_JSON=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")

  get_disk "$LOCAL_TARGET" 'SILENT'

  assert_equals_helper 'Disk size from JSON did not match sample' \
    "(${LINENO})" '111.79 GiB' "${device_info_data['disk_size']}"
  assert_equals_helper 'Disk used from JSON did not match sample' \
    "(${LINENO})" '24.26 GiB (21.7%)' "${device_info_data['disk_used']}"
}

function test_get_os_from_json()
{
  RAW_JSON=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")

  get_os "$LOCAL_TARGET" 'SILENT'

  assert_equals_helper 'OS name from JSON did not match sample' \
    "(${LINENO})" 'Debian GNU/Linux forky/sid' "${device_info_data['os_name']}"
  assert_equals_helper 'Desktop environment from JSON did not match sample' \
    "(${LINENO})" 'kwin_wayland' "${device_info_data['desktop_environment']}"
}

function test_get_kernel_info_from_json()
{
  RAW_JSON=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")

  get_kernel_info "$LOCAL_TARGET" 'SILENT'

  assert_equals_helper 'Kernel release from JSON did not match sample' \
    "(${LINENO})" '7.0.0-rc3-PC-WITH-B580+' "${device_info_data['kernel_release']}"
  assert_equals_helper 'Kernel machine from JSON did not match sample' \
    "(${LINENO})" 'x86_64' "${device_info_data['kernel_machine']}"
}

function test_get_motherboard_from_json()
{
  RAW_JSON=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")

  get_motherboard "$LOCAL_TARGET" 'SILENT'

  assert_equals_helper 'Motherboard vendor from JSON did not match sample' \
    "(${LINENO})" 'ASUSTeK' "${device_info_data['motherboard_vendor']}"
  assert_equals_helper 'Motherboard name from JSON did not match sample' \
    "(${LINENO})" 'TUF GAMING X570-PRO (WI-FI)' "${device_info_data['motherboard_name']}"
}

function test_get_chassis_from_json()
{
  RAW_JSON=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")

  get_chassis "$LOCAL_TARGET" 'SILENT'

  assert_equals_helper 'Chassis type from JSON did not match sample' \
    "(${LINENO})" 'Desktop' "${device_info_data['chassis']}"
}

function test_get_graphics_local_cmd()
{
  local output
  local expected_cmd='inxi --tty --width 1 --color 0 --graphics'

  output=$(get_graphics "$LOCAL_TARGET" 'TEST_MODE')
  assert_equals_helper 'Wrong local command for get_graphics' "(${LINENO})" "$expected_cmd" "$output"
}

function test_get_graphics_remote_cmd()
{
  local output
  local expected_cmd='inxi --tty --width 1 --color 0 --graphics'

  output=$(get_graphics "$REMOTE_TARGET" 'TEST_MODE')
  assert_equals_helper 'Wrong remote command for get_graphics' "(${LINENO})" "$expected_cmd" "$output"
}

# Test get_graphics using the standard x86 sample (single GPU: Intel Arc B580 with xe driver)
function test_get_graphics_from_json()
{
  RAW_JSON=$(< "${SAMPLES_DIR}/inxi/inxi_output.json")

  get_graphics "$LOCAL_TARGET" 'SILENT'

  assert_equals_helper 'GPU entry 0 from JSON did not match sample' \
    "(${LINENO})" 'Intel Battlemage G21 [Arc B580],xe' "${gpus[0]}"
  assert_equals_helper 'Window system from JSON did not match sample' \
    "(${LINENO})" 'unspecified' "${device_info_data['window_system']}"
}

# Test get_graphics using the Pine64 Pinebook Pro sample (two GPUs: display-subsystem
# with rockchip_drm driver and rk3399-mali with panfrost driver)
function test_get_graphics_from_json_pine()
{
  RAW_JSON=$(< "${SAMPLES_DIR}/inxi/pine_output.json")

  get_graphics "$LOCAL_TARGET" 'SILENT'

  assert_equals_helper 'GPU entry 0 from JSON pine did not match sample' \
    "(${LINENO})" 'display-subsystem,rockchip_drm' "${gpus[0]}"
  assert_equals_helper 'GPU entry 1 from JSON pine did not match sample' \
    "(${LINENO})" 'rk3399-mali,panfrost' "${gpus[1]}"
  assert_equals_helper 'Window system from JSON pine did not match sample' \
    "(${LINENO})" '' "${device_info_data['window_system']}"
}

function test_display_data()
{
  local output

  declare -a expected_cmd=(
    'Chassis:'
    'Type: Pizza Box'
    'CPU:'
    'Model: A model'
    'Architecture: x86_64'
    'Frequency (MHz/Avg): 1400'
    'Total Cores: 13'
    'Memory:'
    'Total RAM: 2 GiB'
    'Available RAM: 1 GiB'
    'RAM Type: DDR4'
    'RAM capacity: 128 GiB'
    'Total RAM installed: 2 GiB'
    'Storage boot partitions:'
    'Root filesystem: dev/something'
    'Size: 250G'
    'Used size: 200G'
    'File system type: ext4'
    'Mounted on: /'
    'Distro info:'
    'Distribution: Ubuntu'
    'Desktop environment: gnome'
    'Window System: wayland'
    'Compositor: gnome-shell'
    'Kernel:'
    'Name: Linux'
    'Release: 1.0.0-0'
    'Version: #29~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC Mon Jan  1 00:00:00 UTC 2'
    'Machine hardware name: Machine-type'
    'Motherboard:'
    'Vendor: Vendor'
    'Name: ABC123'
    'GPU:'
    'Device Name: AMD something'
    'Driver Name: amdgpu'
    'Display:'
    'Modesetting:'
    '3840x2160@60'
  )

  options_values['target']="$LOCAL_TARGET"
  device_info_data['chassis']='Pizza Box'
  device_info_data['ram_total']='2 GiB'
  device_info_data['ram_available']='1 GiB'
  device_info_data['ram_type']='DDR4'
  device_info_data['ram_capacity']='128 GiB'
  device_info_data['ram_installed']='2 GiB'
  device_info_data['cpu_model_name']='A model'
  device_info_data['cpu_architecture']='x86_64'
  device_info_data['cpu_speed']=1400
  device_info_data['cpu_total_cores']=13
  device_info_data['disk_size']='250G'
  device_info_data['root_path']='dev/something'
  device_info_data['fs_mount']='/'
  device_info_data['fs_type']='ext4'
  device_info_data['disk_used']='200G'
  device_info_data['os_name']='Ubuntu'
  device_info_data['desktop_environment']='gnome'
  device_info_data['window_system']='wayland'
  device_info_data['compositor']='gnome-shell'
  device_info_data['kernel_name']='Linux'
  device_info_data['kernel_release']='1.0.0-0'
  device_info_data['kernel_version']='#29~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC Mon Jan  1 00:00:00 UTC 2'
  device_info_data['kernel_machine']='Machine-type'
  device_info_data['motherboard_vendor']='Vendor'
  device_info_data['motherboard_name']='ABC123'
  gpus[0]='AMD something,amdgpu'

  unset crtcs
  declare -gA crtcs
  crtcs['crtc-0']='type=primary;resolution=3840x2160;color_encoding=ITU-R BT.601 YCbCr;refresh_rate=60;connector=DP-1;'

  output=$(show_data)

  compare_command_sequence 'Failed to set target data' "$LINENO" 'expected_cmd' "$output"
}

invoke_shunit
