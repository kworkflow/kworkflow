#!/usr/bin/env bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/arch.sh'
include './src/lib/kwio.sh'
include './tests/unit/utils.sh'

function setUp()
{
  export ORIGINAL_PATH="$PWD"
  mk_fake_boot "$SHUNIT_TMPDIR"

  export kw_path='/fake/remote/path'
  export KW_ETC_DIR='/fake/local/path'
  export REMOTE_KW_DEPLOY='/fake/run/kw/etc'

  cp "tests/unit/samples/mkinitcpio_output/mkinitcpio_log_with_errors" "$SHUNIT_TMPDIR"
  cp "tests/unit/samples/mkinitcpio_output/mkinitcpio_log_only_warnings" "$SHUNIT_TMPDIR"

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
}

function tearDown()
{
  cd "$ORIGINAL_PATH" || {
    fail "(${LINENO}) It was not possible to move to the kw folder"
    return
  }
  rm -rf "$SHUNIT_TMPDIR"
}

function test_generate_arch_temporary_root_file_system_local_and_mkinitcpio()
{
  local name='xpto'
  local path_prefix=''
  local cmd=
  local sudo_cmd=''
  local qemu_mock_img="${SHUNIT_TMPDIR}/mock_image"
  local ret

  # Local
  sudo_cmd='sudo --preserve-env'
  declare -a cmd_sequence=(
    "${sudo_cmd} depmod --all ${name}"
    "${sudo_cmd} mkinitcpio --generate /boot/initramfs-${name}.img --kernel ${name}"
  )

  # Create fake initramfs
  touch "initramfs-${name}.img"

  output="$(
    boot_prefix="${SHUNIT_TMPDIR}"
    function command_exists()
    {
      return 0
    }
    generate_arch_temporary_root_file_system 'TEST_MODE' "${name}" 'local' 'GRUB'
  )"
  ret="$?"

  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
  assert_equals_helper 'Expected error code' "(${LINENO})" 0 "$ret"
}

function test_generate_arch_temporary_root_file_system_local_and_mkinitcpio_fail_to_generate_initramfs()
{
  local name='xpto'
  local path_prefix=''
  local cmd=
  local sudo_cmd=''
  local qemu_mock_img="${SHUNIT_TMPDIR}/mock_image"
  local ret

  output="$(
    function command_exists()
    {
      return 0
    }
    generate_arch_temporary_root_file_system 'TEST_MODE' "${name}" 'local' 'GRUB'
  )"
  ret="$?"

  assert_equals_helper 'Expected error code' "(${LINENO})" 2 "$ret"
}

function test_generate_arch_temporary_root_file_system_remote_and_mkinitcpio()
{
  local name='xpto'
  local path_prefix=''
  local cmd=
  local sudo_cmd=''
  local qemu_mock_img="${SHUNIT_TMPDIR}/mock_image"

  # Remote
  declare -a cmd_sequence=(
    "depmod --all ${name}"
    "mkinitcpio --generate /boot/initramfs-${name}.img --kernel ${name}"
  )

  output="$(
    function command_exists()
    {
      return 0
    }
    generate_arch_temporary_root_file_system 'TEST_MODE' "${name}" 'remote' 'GRUB'
  )"
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
}

function test_generate_arch_temporary_root_file_system_remote_and_dracut()
{
  local name='xpto'
  local path_prefix=''
  local cmd=
  local sudo_cmd=''
  local qemu_mock_img="${SHUNIT_TMPDIR}/mock_image"

  # Remote
  declare -a cmd_sequence=(
    "depmod --all $name"
    "DRACUT_NO_XATTR=1 dracut --force --persistent-policy by-partuuid --hostonly /boot/initramfs-${name}.img ${name}"
  )

  # We want to force dracut
  output="$(
    function command_exists()
    {
      [[ "$1" == 'mkinitcpio' ]] && return 1
      return 0
    }
    generate_arch_temporary_root_file_system 'TEST_MODE' "$name" 'remote' 'GRUB'
  )"
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
}

function test_generate_arch_temporary_root_file_system_remote_and_not_supported()
{
  local name='xpto'
  local path_prefix=''
  local cmd=
  local sudo_cmd=''
  local qemu_mock_img="${SHUNIT_TMPDIR}/mock_image"

  # Remote
  declare -a cmd_sequence=(
    "depmod --all $name"
    "DRACUT_NO_XATTR=1 dracut --force --persistent-policy by-partuuid --hostonly /boot/initramfs-${name}.img ${name}"
  )

  # We want to force an unsupported tool
  output="$(
    function command_exists()
    {
      [[ "${1}" == 'mkinitcpio' ]] && return 1
      [[ "${1}" == 'dracut' ]] && return 1
    }
    generate_arch_temporary_root_file_system 'TEST_MODE' "${name}" 'remote' 'GRUB'
  )"

  assertEquals "(${LINENO})" 22 "$?"
}

function test_generate_arch_temporary_root_file_system_remote_preferred_root_fs()
{
  local name='xpto'
  local path_prefix=''
  local cmd=
  local sudo_cmd=''
  local qemu_mock_img="${SHUNIT_TMPDIR}/mock_image"

  # Remote
  declare -a cmd_sequence=(
    "depmod --all ${name}"
    "DRACUT_NO_XATTR=1 dracut --force --persistent-policy by-partuuid --hostonly /boot/initramfs-${name}.img ${name}"
  )

  # We want to force an the prefered option
  output="$(
    function command_exists()
    {
      return 0
    }
    generate_arch_temporary_root_file_system 'TEST_MODE' "$name" 'remote' 'GRUB' '' 'dracut'
  )"

  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
}

function test_generate_arch_temporary_root_file_system_remote_preferred_root_fs_invalid()
{
  local name='xpto'
  local path_prefix=''
  local cmd=
  local sudo_cmd=''
  local qemu_mock_img="${SHUNIT_TMPDIR}/mock_image"
  local expected_output='It looks like that "xpto" does not exists'
  local output

  # We want to force an the prefered option
  output="$(
    function command_exists()
    {
      return 1
    }
    generate_arch_temporary_root_file_system 'TEST_MODE' "${name}" 'remote' 'GRUB' '' 'xpto'
  )"

  assert_equals_helper "Expected error message" "(${LINENO})" "$expected_output" "$output"
}

function test_process_mkinitcpio_message_check_errors_return()
{
  local log_from_file
  local output
  local ret

  log_from_file=$(< "mkinitcpio_log_with_errors")

  output=$(process_mkinitcpio_message "$log_from_file")
  ret="$?"

  assert_equals_helper 'Expected error code' "(${LINENO})" 68 "$ret"
}

function test_process_mkinitcpio_message_check_warnings_return()
{
  local log_from_file
  local output
  local ret

  log_from_file=$(< "mkinitcpio_log_only_warnings")

  output=$(process_mkinitcpio_message "$log_from_file")
  ret="$?"

  assert_equals_helper 'Expected error code' "(${LINENO})" 42 "$ret"
}

function test_process_mkinitcpio_message_check_warning_message()
{
  local log_from_file
  local output
  local ret

  declare -a output_sequence=(
    "==> WARNING: Possibly missing firmware for module: 'xhci_pci'"
    "==> WARNING: Possibly missing '/bin/bash' for script: /usr/bin/mount.steamos"
    "==> WARNING: errors were encountered during the build. The image may not be complete."
  )

  log_from_file=$(< "mkinitcpio_log_only_warnings")

  output=$(process_mkinitcpio_message "$log_from_file")

  compare_command_sequence '' "$LINENO" 'output_sequence' "$output"
}

function test_process_mkinitcpio_message_check_error_warning_message()
{
  local log_from_file
  local output
  local ret

  declare -a output_sequence=(
    "==> ERROR: binary not found: 'plymouth'"
    "==> ERROR: module not found: 'steamdeck'"
    "==> ERROR: module not found: 'steamdeck_hwmon'"
    "==> ERROR: module not found: 'leds_steamdeck'"
    "==> ERROR: module not found: 'extcon_steamdeck'"
    "==> ERROR: module not found: 'ulpi'"
    "==> ERROR: module not found: 'uas'"
    "==> WARNING: Possibly missing firmware for module: 'xhci_pci'"
    "==> WARNING: Possibly missing '/bin/bash' for script: /usr/bin/mount.steamos"
    "==> WARNING: errors were encountered during the build. The image may not be complete."
  )

  log_from_file=$(< "mkinitcpio_log_with_errors")
  output=$(process_mkinitcpio_message "$log_from_file")

  compare_command_sequence '' "$LINENO" 'output_sequence' "$output"
}

invoke_shunit
