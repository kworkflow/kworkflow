#!/bin/bash

include './src/plugins/kernel_install/bootloader_utils.sh'
include './tests/utils.sh'

declare -r TEST_ROOT_PATH="$PWD"

declare -a fake_dev

function setUp()
{
  # Let's create a fake /dev path
  mkdir -p "$SHUNIT_TMPDIR/dev"

  fake_dev=(
    "$SHUNIT_TMPDIR/dev/nvme0n1p1"
    "$SHUNIT_TMPDIR/dev/nvme0n1p2"
    "$SHUNIT_TMPDIR/dev/mmcblk0p1"
    "$SHUNIT_TMPDIR/dev/sda"
    "$SHUNIT_TMPDIR/dev/sdb"
    "$SHUNIT_TMPDIR/dev/hda"
  )

  # SSD, NVME, HD, SD card
  for dev_path in "${fake_dev[@]}"; do
    touch "$dev_path"
  done

  # Add some noise to the /dev file
  mkdir -p "$SHUNIT_TMPDIR/dev/sdh"
  mkdir -p "$SHUNIT_TMPDIR/dev/hdz"

  export DEV_PATH="$SHUNIT_TMPDIR/dev"
}

function create_binary_file()
{
  local input="$1"
  local save_to="$2"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
}

# Keep in mind that this is a very artificial mock function for `df
# --output='source,target'`. Despite the inconsistencies in the output, the
# core idea is to use this output to validate multiple possibilities around
# discover_device_and_partition.
function df()
{
  local df_mock=''
  read -r -d '' df_mock << 'EOF'
Filesystem     Mounted on
udev           /dev
tmpfs          /run
/dev/nvme0n1p3 /
tmpfs          /dev/shm
tmpfs          /run/lock
tmpfs          /sys/fs/cgroup
/dev/loop0     /snap/bare/5
/dev/loop1     /snap/chromium/1801
/dev/loop2     /snap/core18/2246
/dev/loop3     /snap/chromium/1810
/dev/loop5     /snap/core18/2128
/dev/loop4     /snap/gnome-3-28-1804/145
/dev/loop7     /snap/gnome-3-34-1804/66
/dev/loop6     /snap/gnome-3-28-1804/161
/dev/nvme0n1p1 /boot/efi
/dev/loop8     /snap/snapd/13270
/dev/nvme0n1p4 /home
/dev/loop9     /snap/gtk-common-themes/1515
/dev/loop10    /snap/snapd/13640
/dev/loop11    /snap/gtk-common-themes/1519
/dev/loop12    /snap/snap-store/547
/dev/loop13    /snap/shfmt/29
/dev/loop14    /snap/gnome-3-34-1804/72
/dev/loop15    /snap/snap-store/542
/dev/loop16    /snap/shfmt/31
tmpfs          /run/user/1000
fuse:drivefs://2B2E25BE24134E923A92B41532DF4E93 /media/fuse/drivefs-abf21f08db3d022ac3ec3c63f8423293
EOF
  printf '%s' "$df_mock"
}

function test_discover_device_and_partition()
{
  local output=''
  declare -A expected_partitions=(
    ['/dev/nvme0n1p3']='/'
    ['/dev/nvme0n1p1']='/boot/efi'
    ['/dev/nvme0n1p4']='/home'
  )

  export -f df

  discover_device_and_partition
  for device in "${!device_to_mount_point[@]}"; do
    assert_equals_helper 'Expected same device' "$LINENO" \
      "${device_to_mount_point[$device]}" "${expected_partitions[$device]}"
  done
}

function test_discover_all_hard_drive()
{
  # These values came from the setup
  discover_all_hard_drive
  compare_array_values fake_dev available_hard_driver_system "$LINENO"
}

function test_partition_table_type()
{
  local -r first_512_binaries_base_path='tests/samples/first_set_of_bytes_from_disk'
  local output

  # Check a standard GRUB2 in an x86 machine
  output=$(partition_table_type "$first_512_binaries_base_path/grub2_x86")
  assertEquals "($LINENO): Expected EFI" 'EFI' "$output"

  # Check a system with Syslinux - This is commonly found in ChromeOS dev systems
  output=$(partition_table_type "$first_512_binaries_base_path/syslinux_x86")
  assertEquals "($LINENO): Expected EFI" 'EFI' "$output"

  # Check in the Raspberry pi 4 first set of bytes
  output=$(partition_table_type "$first_512_binaries_base_path/rpi4")
  assertEquals "($LINENO): Expected EFI" 'RRaA' "$output"

}

function test_identify_mbr_per_partition()
{
  local -r first_512_binaries_base_path='tests/samples/first_set_of_bytes_from_disk'
  local output

  # Standard x86 machine
  output=$(identify_mbr_per_partition "$first_512_binaries_base_path/grub2_x86")
  assertEquals "($LINENO): No MBR" '' "$output"

  # ChromeOS
  output=$(identify_mbr_per_partition "$first_512_binaries_base_path/syslinux_x86")
  assertEquals "($LINENO): Syslinux MBR" 'Syslinux-MBR-4_04-and-higher' "$output"
}

invoke_shunit
