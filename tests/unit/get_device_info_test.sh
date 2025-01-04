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
    'Architecture: x86_64'
    'Frequency (MHz/Avg): 1400'
    'Total Cores: 13'
    'Memory:'
    'Total RAM: 2 GiB'
    'Available RAM: 1 GiB'
    'RAM Type: DDR4'
    'RAM capacity: 128 GiB'
    'Total RAM installed: 2 GiB'
    'Storage devices:'
    'Root filesystem: dev/something'
    'Size: 250G'
    'Mounted on: /'
    'Operating System:'
    'Distribution: Ubuntu'
    'Distribution version: 22.04.1 LTS (Jammy Jellyfish)'
    'Distribution base: debian'
    'Desktop environments: gnome'
    'Kernel:'
    'Name: Linux'
    'Release: 1.0.0-0'
    'Version: #29~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC Mon Jan  1 00:00:00 UTC 2'
    'Machine hardware name: Machine-type'
    'Motherboard:'
    'Vendor: Vendor'
    'Name: ABC123'
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
  device_info_data['os_name']='Ubuntu'
  device_info_data['os_id_like']='debian'
  device_info_data['os_version']='22.04.1 LTS (Jammy Jellyfish)'
  device_info_data['desktop_environment']='gnome'
  device_info_data['kernel_name']='Linux'
  device_info_data['kernel_release']='1.0.0-0'
  device_info_data['kernel_version']='#29~22.04.1-Ubuntu SMP PREEMPT_DYNAMIC Mon Jan  1 00:00:00 UTC 2'
  device_info_data['kernel_machine']='Machine-type'
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
  get_desktop_environment "$LOCAL_TARGET" 'SILENT'
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'lxde' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock kde'
  get_desktop_environment "$LOCAL_TARGET" 'SILENT'
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'kde' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock mate'
  get_desktop_environment "$LOCAL_TARGET" 'SILENT'
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'mate' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock cinnamon'
  get_desktop_environment "$LOCAL_TARGET" 'SILENT'
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'cinnamon' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock openbox'
  get_desktop_environment "$LOCAL_TARGET" 'SILENT'
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'openbox' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock gnome-shell'
  get_desktop_environment "$LOCAL_TARGET" 'SILENT'
  assert_equals_helper 'Failed to set/gather local target DE data' "($LINENO)" 'gnome' "${device_info_data['desktop_environment']}"

  alias ps='ps_mock something'
  get_desktop_environment "$LOCAL_TARGET" 'SILENT'
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

invoke_shunit
