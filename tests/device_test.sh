#!/bin/bash

include './src/device_info.sh'
include './tests/utils.sh'

function test_get_ram()
{
  local cmd
  local output

  cmd="[ -f '/proc/meminfo' ] && cat /proc/meminfo | grep 'MemTotal' | grep -o '[0-9]*'"
  output=$(get_ram "$LOCAL_TARGET" 'TEST_MODE')
  assertEquals "($LINENO)" "$cmd" "$output"
}

function test_get_cpu()
{
  local output
  declare -a expected_cmd=(
    "lscpu | grep 'Model name:' | sed -r 's/Model name:\s+//g' | cut -d' ' -f1"
    "lscpu | grep MHz | sed -r 's/(CPU.*)/\t\t\1/'"
  )

  output=$(get_cpu "$LOCAL_TARGET" 'TEST_MODE')
  compare_command_sequence expected_cmd[@] "$output" "$LINENO"
}

function test_get_disk()
{
  local cmd
  local output

  cmd="df -h / | tail -n 1 | tr -s ' '"
  output=$(get_disk "$LOCAL_TARGET" 'TEST_MODE')
  assertEquals "($LINENO)" "$cmd" "$output"
}

function test_get_motherboard()
{
  local output
  declare -a expected_cmd=(
    '[ -f /sys/devices/virtual/dmi/id/board_name ] && cat /sys/devices/virtual/dmi/id/board_name'
    '[ -f /sys/devices/virtual/dmi/id/board_vendor ] && cat /sys/devices/virtual/dmi/id/board_vendor'
  )

  output=$(get_motherboard "$LOCAL_TARGET" 'TEST_MODE')
  compare_command_sequence expected_cmd[@] "$output" "$LINENO"
}

function test_get_chassis()
{
  local cmd
  local output

  cmd='cat /sys/devices/virtual/dmi/id/chassis_type'
  output=$(get_chassis "$LOCAL_TARGET" 'TEST_MODE')
  assertEquals "($LINENO)" "$cmd" "$output"
}

function test_display_data()
{
  local output

  declare -a expected_cmd=(
    'Chassis:'
    'Type: Pizza Box'
    'CPU:'
    'Model: A model'
    'Current frequency (MHz): 1400'
    'RAM:'
    'Total RAM: 16G'
    'Storage devices:'
    'Root filesystem: dev/something'
    'Size: 250G'
    'Mounted on: /'
    'Operating System:'
    'Distribution: debian'
    'Desktop environments: gnome'
    'Motherboard:'
    'Vendor: Vendor'
    'Name: ABC123'
  )

  device_options['target']="$LOCAL_TARGET"
  device_info_data['chassis']='Pizza Box'
  device_info_data['ram']='16777216'
  device_info_data['cpu_model']='A model'
  device_info_data['cpu_currently']=1400
  device_info_data['disk_size']='250G'
  device_info_data['root_path']='dev/something'
  device_info_data['fs_mount']='/'
  device_info_data['os']='debian'
  device_info_data['desktop_environment']='gnome'
  device_info_data['motherboard_vendor']='Vendor'
  device_info_data['motherboard_name']='ABC123'
  output=$(show_data)
  compare_command_sequence expected_cmd[@] "$output" "$LINENO"
}

invoke_shunit
