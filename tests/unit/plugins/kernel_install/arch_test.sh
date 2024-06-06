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

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
}

function tearDown()
{
  cd "$ORIGINAL_PATH" || {
    fail "($LINENO) It was not possible to move to the kw folder"
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

  # Local
  sudo_cmd='sudo -E'
  declare -a cmd_sequence=(
    "${sudo_cmd} depmod --all ${name}"
    "${sudo_cmd} mkinitcpio --generate /boot/initramfs-${name}.img --kernel ${name}"
  )

  output="$(
    function command_exists()
    {
      return 0
    }
    generate_arch_temporary_root_file_system 'TEST_MODE' "$name" 'local' 'GRUB'
  )"
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
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
    generate_arch_temporary_root_file_system 'TEST_MODE' "$name" 'remote' 'GRUB'
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
      [[ "$1" == 'mkinitcpio' ]] && return 1
      [[ "$1" == 'dracut' ]] && return 1
    }
    generate_arch_temporary_root_file_system 'TEST_MODE' "$name" 'remote' 'GRUB'
  )"

  assertEquals "($LINENO)" 22 "$?"
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
    "depmod --all $name"
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
    generate_arch_temporary_root_file_system 'TEST_MODE' "$name" 'remote' 'GRUB' '' 'xpto'
  )"

  assert_equals_helper "Expected error message" "($LINENO)" "$expected_output" "$output"
}

invoke_shunit
