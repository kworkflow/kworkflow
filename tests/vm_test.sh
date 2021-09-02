#!/bin/bash

include './tests/utils.sh'
include './src/vm.sh'

function setUp()
{
  mkdir -p "$SHUNIT_TMPDIR/.kw/"
  cp -f tests/samples/kworkflow.config "$SHUNIT_TMPDIR/.kw/"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
  mkdir -p "$SHUNIT_TMPDIR"
}

function test_vm_mount()
{
  local mount_point="$SHUNIT_TMPDIR/lala"
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

  tearDown
  setUp

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(
    function findmnt()
    {
      printf '%s\n' 'anything'
    }
    vm_mount "TEST_MODE"
  )
  ret="$?"
  expected_ret="125"
  assertEquals "($LINENO) - Expected 125" "$expected_ret" "$ret"

  output=$(vm_mount "TEST_MODE" "$qemu_path" "$mount_point")
  ret="$?"
  assertTrue "($LINENO)" "$ret"

  output=$(vm_mount "TEST_MODE" "$qemu_path" "$mount_point")
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  load_configuration "$KW_CONFIG_SAMPLE"

  say_msg="Mount ${configurations[qemu_path_image]} in $mount_point"
  guestmount_cmd="guestmount -a ${configurations[qemu_path_image]} -i $mount_point 2>&1"
  expected_cmd[0]="$say_msg"
  expected_cmd[1]="$guestmount_cmd"

  output=$(vm_mount "TEST_MODE" "" "$mount_point")
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_vm_umount()
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

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

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
  compare_command_sequence 'expected_cmd' "$output" "$ID"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

invoke_shunit
