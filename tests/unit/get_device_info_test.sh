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
  device_info_data['gpu']='AMD something'
  device_info_data['gpu_driver']='amdgpu'

  output=$(show_data)

  compare_command_sequence 'Failed to set target data' "$LINENO" 'expected_cmd' "$output"
}

invoke_shunit
