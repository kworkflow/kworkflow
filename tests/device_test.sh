#!/bin/bash

include './src/device_info.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  shopt -s expand_aliases
  remote_parameters['REMOTE_USER']='john'
}

declare -gA configurations
configurations[ssh_user]=john

function test_get_ram()
{
  local cmd
  local output

  cmd="[ -f '/proc/meminfo' ] && cat /proc/meminfo | grep 'MemTotal' | grep -o '[0-9]*'"
  output=$(get_ram "$LOCAL_TARGET" 'TEST_MODE')
  assert_equals_helper 'Local target RAM info gathering command did not match expectation' "($LINENO)" "$cmd" "$output"

  device_options['ip']='127.0.0.1'
  device_options['port']='2222'
  output=$(get_ram "$REMOTE_TARGET" 'TEST_MODE')
  assert_equals_helper 'Remote target RAM info gathering command did not match expectation' "($LINENO)" "ssh -p 2222 john@127.0.0.1 sudo \"$cmd\"" "$output"
}

function test_get_cpu()
{
  local output
  declare -a expected_cmd=(
    "lscpu | grep 'Model name:' | sed -r 's/Model name:\s+//g' | cut -d' ' -f1"
    "lscpu | grep MHz | sed -r 's/(CPU.*)/\t\t\1/'"
  )

  output=$(get_cpu "$LOCAL_TARGET" 'TEST_MODE')
  compare_command_sequence 'Failed to gather local target CPU data' "$LINENO" 'expected_cmd' "$output"

  declare -a expected_cmd=(
    "ssh -p 2222 john@127.0.0.1 sudo \"lscpu | grep 'Model name:' | sed -r 's/Model name:\s+//g' | cut -d' ' -f1\""
    "ssh -p 2222 john@127.0.0.1 sudo \"lscpu | grep MHz | sed -r 's/(CPU.*)/\t\t\1/'\""
  )

  device_options['ip']='127.0.0.1'
  device_options['port']='2222'
  output=$(get_cpu "$REMOTE_TARGET" 'TEST_MODE')
  compare_command_sequence 'Failed to gather remote target CPU data' "$LINENO" 'expected_cmd' "$output"
}

function test_get_disk()
{
  local cmd
  local output

  cmd="df -h / | tail -n 1 | tr -s ' '"
  output=$(get_disk "$LOCAL_TARGET" 'TEST_MODE')
  assert_equals_helper 'Failed to gather local target disk data' "($LINENO)" "$cmd" "$output"

  device_options['ip']='127.0.0.1'
  device_options['port']='2222'
  output=$(get_disk "$REMOTE_TARGET" 'TEST_MODE')
  assert_equals_helper 'Failed to gather remote target disk data' "($LINENO)" "ssh -p 2222 john@127.0.0.1 sudo \"$cmd\"" "$output"
}

function test_get_motherboard()
{
  local output
  declare -a expected_cmd=(
    '[ -f /sys/devices/virtual/dmi/id/board_name ] && cat /sys/devices/virtual/dmi/id/board_name'
    '[ -f /sys/devices/virtual/dmi/id/board_vendor ] && cat /sys/devices/virtual/dmi/id/board_vendor'
  )

  output=$(get_motherboard "$LOCAL_TARGET" 'TEST_MODE')
  compare_command_sequence 'Failed to gather local target motherboard data' "$LINENO" 'expected_cmd' "$output"
}

function test_get_chassis()
{
  local cmd
  local output

  cmd='cat /sys/devices/virtual/dmi/id/chassis_type'
  output=$(get_chassis "$LOCAL_TARGET" 'TEST_MODE')
  assert_equals_helper 'Failed to gather local target chassis data' "($LINENO)" "$cmd" "$output"
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
    'Distribution: Ubuntu'
    'Distribution version: 22.04.1 LTS (Jammy Jellyfish)'
    'Distribution base: debian'
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
  device_info_data['os_name']='Ubuntu'
  device_info_data['os_id_like']='debian'
  device_info_data['os_version']='22.04.1 LTS (Jammy Jellyfish)'
  device_info_data['desktop_environment']='gnome'
  device_info_data['motherboard_vendor']='Vendor'
  device_info_data['motherboard_name']='ABC123'
  output=$(show_data)
  compare_command_sequence 'Failed to set target data' "$LINENO" 'expected_cmd' "$output"
}

function detect_distro_mock()
{
  printf '%s\n' 'lala'
}

function which_distro_mock()
{
  printf '%s\n' 'xpto'
}

function test_get_os()
{
  local output
  local expected_cmd

  # Check local deploy calls the expected commands
  expected_cmd='cat /etc/os-release'
  output=$(get_os "$LOCAL_TARGET" 'TEST_MODE')
  output=$(printf '%s\n' "$output" | head -n1)
  assert_equals_helper 'Unexpected cmd while trying to gather local target os-release data' "$LINENO" "$expected_cmd" "$output"

  # Check remote deploy calls the expected commands
  expected_cmd='cat /etc/os-release'
  output=$(get_os "$REMOTE_TARGET" 'TEST_MODE')
  output=$(printf '%s\n' "$output" | head -n1)
  assert_equals_helper 'Unexpected cmd while trying to gather local target os-release data' "$LINENO" "$expected_cmd" "$output"

  #todo: Check if the vars from os-release are correctely parsed
}

function ps_mock()
{
  printf '%s\n' "$1"
}

function test_get_desktop_environment()
{
  local cmd
  local output

  # Check local deploy and some DE variations
  alias ps='ps_mock lxsession'
  get_desktop_environment "$LOCAL_TARGET"
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'lxde' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock kde'
  get_desktop_environment "$LOCAL_TARGET"
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'kde' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock mate'
  get_desktop_environment "$LOCAL_TARGET"
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'mate' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock cinnamon'
  get_desktop_environment "$LOCAL_TARGET"
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'cinnamon' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock openbox'
  get_desktop_environment "$LOCAL_TARGET"
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'openbox' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock gnome-shell'
  get_desktop_environment "$LOCAL_TARGET"
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'gnome' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock something'
  get_desktop_environment "$LOCAL_TARGET"
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'unidentified' "${device_info_data['desktop_environment']}"
}

# mocked data for get_gpu test
mocked_lspci=$(
  cat << EOF
00:00.0 Host bridge: Intel Corporation Xeon E3-1200 v6/7th Gen Core Processor Host Bridge/DRAM Registers (rev 08)
00:02.0 VGA compatible controller: Intel Corporation UHD Graphics 620 (rev 07)
00:04.0 Signal processing controller: Intel Corporation Xeon E3-1200 v5/E3-1500 v5/6th Gen Core Processor Thermal Subsystem (rev 08)
00:14.0 USB controller: Intel Corporation Sunrise Point-LP USB 3.0 xHCI Controller (rev 21)
00:14.2 Signal processing controller: Intel Corporation Sunrise Point-LP Thermal subsystem (rev 21)
00:15.0 Signal processing controller: Intel Corporation Sunrise Point-LP Serial IO I2C Controller #0 (rev 21)
00:16.0 Communication controller: Intel Corporation Sunrise Point-LP CSME HECI #1 (rev 21)
00:17.0 SATA controller: Intel Corporation Sunrise Point-LP SATA Controller [AHCI mode] (rev 21)
00:1c.0 PCI bridge: Intel Corporation Sunrise Point-LP PCI Express Root Port #1 (rev f1)
00:1c.4 PCI bridge: Intel Corporation Sunrise Point-LP PCI Express Root Port #5 (rev f1)
00:1c.5 PCI bridge: Intel Corporation Sunrise Point-LP PCI Express Root Port #6 (rev f1)
00:1f.0 ISA bridge: Intel Corporation Sunrise Point LPC Controller/eSPI Controller (rev 21)
00:1f.2 Memory controller: Intel Corporation Sunrise Point-LP PMC (rev 21)
00:1f.3 Audio device: Intel Corporation Sunrise Point-LP HD Audio (rev 21)
00:1f.4 SMBus: Intel Corporation Sunrise Point-LP SMBus (rev 21)
01:00.0 Display controller: Advanced Micro Devices, Inc. [AMD/ATI] Jet PRO [Radeon R5 M230 / R7 M260DX / Radeon 520 Mobile] (rev c3)
02:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL810xE PCI Express Fast Ethernet controller (rev 07)
03:00.0 Network controller: Qualcomm Atheros QCA9565 / AR9565 Wireless Network Adapter (rev 01)
EOF
)

# Mocked lspci verbose output for the device identified by "01:00.0"
mocked_lspci_verbose_select_01_00_0=$(
  cat << EOF
01:00.0 Display controller: Advanced Micro Devices, Inc. [AMD/ATI] Jet PRO [Radeon R5 M230 / R7 M260DX / Radeon 520 Mobile] (rev c3)
  Subsystem: Dell Jet PRO [Radeon R5 M230 / R7 M260DX / Radeon 520 Mobile]
  Flags: bus master, fast devsel, latency 0, IRQ 129
  Memory at c0000000 (64-bit, prefetchable) [size=256M]
  Memory at d0000000 (64-bit, non-prefetchable) [size=256K]
  I/O ports at e000 [size=256]
  Expansion ROM at d0040000 [disabled] [size=128K]
  Capabilities: [48] Vendor Specific Information: Len=08 <?>
  Capabilities: [50] Power Management version 3
  Capabilities: [58] Express Legacy Endpoint, MSI 00
  Capabilities: [a0] MSI: Enable+ Count=1/1 Maskable- 64bit+
  Capabilities: [100] Vendor Specific Information: ID=0001 Rev=1 Len=010 <?>
  Capabilities: [150] Advanced Error Reporting
  Capabilities: [270] Secondary PCI Express
  Kernel driver in use: radeon
  Kernel modules: radeon, amdgpu
EOF
)

# Mocked lspci verbose output for the device identified by "00:02.0"
mocked_lspci_verbose_select_00_02_0=$(
  cat << EOF
00:02.0 VGA compatible controller: Intel Corporation UHD Graphics 620 (rev 07) (prog-if 00 [VGA controller])
  DeviceName:  Onboard IGD
  Subsystem: Dell UHD Graphics 620
  Flags: bus master, fast devsel, latency 0, IRQ 128
  Memory at d1000000 (64-bit, non-prefetchable) [size=16M]
  Memory at b0000000 (64-bit, prefetchable) [size=256M]
  I/O ports at f000 [size=64]
  Expansion ROM at 000c0000 [virtual] [disabled] [size=128K]
  Capabilities: <access denied>
  Kernel driver in use: i915
  Kernel modules: i915
EOF
)

function lspci_mock()
{
  local raw_options="$*"
  if [[ $raw_options == '-v -s 01:00.0' ]]; then
    printf '%s\n' "$mocked_lspci_verbose_select_01_00_0"
  elif [[ $raw_options == '-v -s 00:02.0' ]]; then
    printf '%s\n' "$mocked_lspci_verbose_select_00_02_0"
  else
    printf '%s\n' "$mocked_lspci"
  fi
}

function test_get_gpu()
{
  local output

  alias lspci='lspci_mock'

  # Check local deploy calls the expected commands
  declare -a expected_cmd=(
    "lspci | grep -e VGA -e Display -e 3D | cut -d' ' -f1"
    'lspci -v -s 01:00.0'
    'lspci -v -s 00:02.0'
  )
  output=$(get_gpu "$LOCAL_TARGET" 'TEST_MODE')
  compare_command_sequence 'Unexpected cmd while trying to gather local target GPU data' "$LINENO" 'expected_cmd' "$output"

  # Check local deploy fills global variable $gpus as expected
  declare -a expected_result=(
    'Dell UHD Graphics 620;Intel Corporation UHD Graphics 620'
    'Dell Jet PRO [Radeon R5 M230 / R7 M260DX / Radeon 520 Mobile];Advanced Micro Devices, Inc.'
  )

  get_gpu "$LOCAL_TARGET"
  compare_array_values expected_result gpus "$LINENO"
}

invoke_shunit
