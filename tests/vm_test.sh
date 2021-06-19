#!/bin/bash

include './tests/utils.sh'
include './src/vm.sh'

function suite()
{
  suite_addTest "vm_mount_Test"
  suite_addTest "vm_umount_Test"
}

declare -r test_path="tests/.tmp"

function setUp()
{
  local -r current_path="$PWD"

  rm -rf "$test_path"

  mkdir -p $test_path

  cp -f tests/samples/kworkflow.config $test_path
}

function tearDown()
{
  rm -rf "$test_path"
}

function vm_mount_Test()
{
  local ID
  local mount_point="$test_path/lala"
  local qemu_path="/any/path"
  local -r current_path="$PWD"
  local ret
  local expected_ret

  # Message to user
  local say_msg="Mount $qemu_path in $mount_point"

  # Guestmount cmd
  local guestmount_cmd="guestmount -a $qemu_path -i $mount_point 2>&1"

  declare -a expected_cmd=(
    "$say_msg"
    "$guestmount_cmd"
  )

  setUp

  cd "$test_path"

  ID=1
  output=$(vm_mount "TEST_MODE")
  ret="$?"
  expected_ret="125"
  assertEquals "($ID) - Expected 125" "$expected_ret" "$ret"

  ID=2
  output=$(vm_mount "TEST_MODE" "$qemu_path" "$mount_point")
  ret="$?"
  assertTrue "($ID)" "$ret"

  ID=3
  output=$(vm_mount "TEST_MODE" "$qemu_path" "$mount_point")
  compare_command_sequence expected_cmd[@] "$output" "$ID"

  load_configuration "$KW_CONFIG_SAMPLE"

  ID=4
  say_msg="Mount ${configurations[qemu_path_image]} in $mount_point"
  guestmount_cmd="guestmount -a ${configurations[qemu_path_image]} -i $mount_point 2>&1"
  expected_cmd[0]="$say_msg"
  expected_cmd[1]="$guestmount_cmd"

  output=$(vm_mount "TEST_MODE" "" "$mount_point")
  compare_command_sequence expected_cmd[@] "$output" "$ID"

  cd "$current_path"

  tearDown
}

function vm_umount_Test()
{
  local ID
  local mount_point="/"
  local -r current_path="$PWD"
  local ret
  local expected_ret

  # Message to user
  local say_msg="Unmount $mount_point"

  # Guestunmount cmd
  local guestmount_cmd="guestunmount $mount_point"

  declare -a expected_cmd=(
    "$say_msg"
    "$guestmount_cmd"
  )

  setUp

  cd "$test_path"

  ID=1
  output=$(vm_umount "TEST_MODE")
  ret="$?"
  expected_ret="125"
  assertEquals "($ID) - Expected 125" "$expected_ret" "$ret"

  ID=2
  output=$(vm_umount "TEST_MODE" "" "$mount_point")
  ret="$?"
  assertTrue "($ID): We got: $ret" "$ret"

  ID=3
  output=$(vm_umount "TEST_MODE" "" "$mount_point")
  compare_command_sequence expected_cmd[@] "$output" "$ID"

  cd "$current_path"

  tearDown
}

invoke_shunit
