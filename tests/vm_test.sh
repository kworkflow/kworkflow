#!/usr/bin/env bash

include './tests/utils.sh'
include './src/kw_config_loader.sh'
include './src/vm.sh'

function setUp()
{
  mkdir -p "$SHUNIT_TMPDIR/.kw/"
  cp -f tests/samples/kworkflow.config "$SHUNIT_TMPDIR/.kw/"

  tests="$PWD/tests"
  etc="${prefix}etc"

  export prefix="$SHUNIT_TMPDIR/"
  mkdir -p "${prefix}boot"
  mkdir -p "$etc"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
  mkdir -p "$SHUNIT_TMPDIR"
}

function test_vm_mount()
{
  local mount_point="${SHUNIT_TMPDIR}/lala"
  local qemu_path='/any/path'
  local -r current_path="$PWD"
  local ret
  local expected_ret
  local msg

  # Message to user
  local say_msg="Mount $qemu_path in $mount_point"

  # Guestmount cmd
  local guestmount_cmd="guestmount -a $qemu_path -i $mount_point 2>&1"

  declare -a expected_cmd

  function uname()
  {
    printf '5.1'
  }

  tearDown
  setUp

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # Mock vmlinuz
  touch "${prefix}boot/vmlinuz-$(uname)"

  # Removing read permission from our mock vmlinuz
  chmod a-r "${prefix}boot/vmlinuz-$(uname)"

  # Suppose it's a debian system
  cp -f "$tests/samples/os/debian/etc/os-release" "$prefix/etc"

  expected_cmd=(
    'To mount the VM, the kernel image needs to be readable'
    "sudo dpkg-statoverride --update --add root root 0644 ${prefix}boot/vmlinuz-$(uname -r)"
    "$say_msg"
    "$guestmount_cmd"
  )

  output=$(printf '%s\n' 'y' | vm_mount 'TEST_MODE' "$qemu_path" "$mount_point")
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Suppose it's not debian
  rm -rf "${etc:?}/"*
  cp -f "$tests/samples/os/arch/etc/os-release" "$prefix/etc"

  expected_cmd[1]="sudo chmod +r ${prefix}boot/vmlinuz-$(uname -r)"
  output=$(printf '%s\n' 'y' | vm_mount 'TEST_MODE' "$qemu_path" "$mount_point")
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Adding back read permission
  chmod +r "${prefix}boot/vmlinuz-$(uname)"

  expected_cmd=(
    "$say_msg"
    "$guestmount_cmd"
  )

  output=$(
    function findmnt()
    {
      printf '%s\n' 'anything'
    }
    vm_mount 'TEST_MODE'
  )
  ret="$?"
  expected_ret='125'
  assertEquals "($LINENO) - Expected 125" "$expected_ret" "$ret"

  output=$(vm_mount 'TEST_MODE' "$qemu_path" "$mount_point")
  ret="$?"
  assertTrue "($LINENO)" "$ret"

  output=$(vm_mount 'TEST_MODE' "$qemu_path" "$mount_point")
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  load_configuration "$KW_CONFIG_SAMPLE"

  say_msg="Mount ${configurations[qemu_path_image]} in $mount_point"
  guestmount_cmd="guestmount -a ${configurations[qemu_path_image]} -i $mount_point 2>&1"
  expected_cmd[0]="$say_msg"
  expected_cmd[1]="$guestmount_cmd"

  output=$(vm_mount 'TEST_MODE' '' "$mount_point")
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_vm_umount()
{
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

  output=$(vm_umount 'TEST_MODE')
  ret="$?"
  expected_ret="125"
  assertEquals "($LINENO)" "$expected_ret" "$ret"

  output=$(vm_umount 'TEST_MODE' '' "$mount_point")
  ret="$?"
  assertTrue "($LINENO)" "$ret"

  output=$(vm_umount 'TEST_MODE' '' "$mount_point")
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_vm_up()
{
  local output=''
  local virtualizer='qemu-system-x86_64'
  local qemu_hw_options='-enable-kvm -daemonize -smp 2 -m 1024'
  local qemu_net_options='-nic user,hostfwd=tcp::2222-:22,smb=/home/USERKW'
  local qemu_path='/home/USERKW/p/virty.qcow2'

  parse_configuration "$SAMPLES_DIR/kworkflow_template.config"

  local cmd_vm_up="$virtualizer $qemu_hw_options $qemu_net_options $qemu_path"

  declare -a expected_cmd=(
    'Starting Qemu with:'
    "$cmd_vm_up"
    "$cmd_vm_up"
  )

  output=$(vm_up 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_vm_parse_options()
{
  unset options_values
  declare -gA options_values
  local output
  local option_output

  # test default options
  parse_vm_options
  assertEquals "($LINENO)" '' "${options_values['MOUNT']}"
  assertEquals "($LINENO)" '' "${options_values['UMOUNT']}"
  assertEquals "($LINENO)" '' "${options_values['UP']}"

  # test individual options
  unset options_values
  declare -gA options_values
  parse_vm_options --mount
  assertEquals "($LINENO)" '1' "${options_values['MOUNT']}"

  unset options_values
  declare -gA options_values
  parse_vm_options --umount
  assertEquals "($LINENO)" '1' "${options_values['UMOUNT']}"

  unset options_values
  declare -gA options_values
  parse_vm_options --up
  assertEquals "($LINENO)" '1' "${options_values['UP']}"

  unset options_values
  declare -gA options_values
  parse_vm_options --alert=v
  assertEquals "($LINENO)" '--alert=v' "${options_values['ALERT_COMPLETION']}"

  unset options_values
  declare -gA options_values
  parse_vm_options --alert=s
  assertEquals "($LINENO)" '--alert=s' "${options_values['ALERT_COMPLETION']}"

  parse_vm_options --mispelled
  assertEquals "($LINENO)" 22 "$?"
  assertEquals "($LINENO)" "kw vm: unrecognized option '--mispelled'" "${options_values['ERROR']}"
}

invoke_shunit
