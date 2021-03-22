#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./src/plugins/kernel_install/debian.sh --source-only
. ./src/kwio.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest 'update_debian_boot_loader_Test'
  suite_addTest 'install_kernel_remote_Test'
  suite_addTest 'install_kernel_local_Test'
  suite_addTest 'install_kernel_vm_Test'
}

declare -r TEST_ROOT_PATH="$PWD"

function setUp
{
  rm -rf "$TMP_TEST_DIR"

  local current_path="$PWD"

  mk_fake_boot "$TMP_TEST_DIR"
#  parse_configuration "$KW_CONFIG_SAMPLE"
}

function tearDown()
{
  rm -rf "$TMP_TEST_DIR"
}

function update_debian_boot_loader_Test
{
  output=$(update_debian_boot_loader 'xpto' '' 'TEST_MODE')
  cmd=' grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check simple flow' "$LINENO" "$cmd" "$output"

  output=$(update_debian_boot_loader 'xpto' 'local' 'TEST_MODE')
  cmd='sudo -E grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check local deploy' "$LINENO" "$cmd" "$output"
}

function install_kernel_remote_Test
{
  local name='5.9.0-rc5-TEST'
  local kernel_image_name='bzImage'
  local reboot='1'
  local architecture='x86_64'
  local target=''
  local flag='TEST_MODE'
  local path_prefix=''

  output=$(install_kernel '' "$kernel_image_name" "$reboot" "$architecture" "$target" 'TEST_MODE')
  ret="$?"
  assert_equals_helper 'Test invalid name' "$LINENO" '22' "$ret"

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "cp -v vmlinuz-$name $path_prefix/boot/vmlinuz-$name"
    "update-initramfs -c -k $name"
    "grub-mkconfig -o /boot/grub/grub.cfg"
    "reboot"
  )
  output=$(install_kernel "$name" "$kernel_image_name" "$reboot" "$architecture" "$target" 'TEST_MODE')
  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"
}

function install_kernel_local_Test
{
  local name='5.9.0-rc5-TEST'
  local kernel_image_name='bzImage'
  local reboot='1'
  local architecture='x86_64'
  local target='local'
  local flag='TEST_MODE'
  local sudo_cmd='sudo -E'
  local path_prefix=''

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "$sudo_cmd cp -v arch/$architecture/boot/$kernel_image_name $path_prefix/boot/vmlinuz-$name"
    "$sudo_cmd update-initramfs -c -k $name"
    "$sudo_cmd grub-mkconfig -o /boot/grub/grub.cfg"
    "$sudo_cmd reboot"
  )

  output=$(install_kernel "$name" "$kernel_image_name" "$reboot" "$architecture" "$target" 'TEST_MODE')
  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"
}

function findmnt_mock()
{
  echo "TARGET SOURCE         FSTYPE OPTIONS"
  echo "/home  /dev/lala ext4   rw,relatime"
}

function vm_umount
{
  echo "vm_umount"
}

function install_kernel_vm_Test
{
  local name='5.9.0-rc5-TEST'
  local kernel_image_name='bzImage'
  local reboot='1'
  local architecture='x86_64'
  local target='vm'
  local flag='TEST_MODE'
  local path_prefix="$TMP_TEST_DIR"

  # Setup this specific test
  touch "$TMP_TEST_DIR/boot/vmlinuz-$name"
  touch "$TMP_TEST_DIR/.config"
  touch "$TMP_TEST_DIR/virty.qcow2"
  configurations[mount_point]="$TMP_TEST_DIR"

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "cp -v .config $path_prefix/boot/config-$name"
    "cp -v arch/$architecture/boot/$kernel_image_name $path_prefix/boot/vmlinuz-$name"
    "vm_umount"
    # We don't want to test update_boot_loader for vm here because we have
    # a specific test for that. Let's add the failure case
    "There is no VM in tests/.tmp"
  )

  cd "$TMP_TEST_DIR"
  shopt -s expand_aliases
  alias findmnt='findmnt_mock'
  alias vm_umount='vm_umount'
  output=$(install_kernel "$name" "$kernel_image_name" "$reboot" "$architecture" "$target" 'TEST_MODE')
  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"

  cd "$TEST_ROOT_PATH"
}

invoke_shunit
