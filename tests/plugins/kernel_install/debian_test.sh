#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./src/plugins/kernel_install/debian.sh --source-only
. ./src/kwio.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest 'update_boot_loader_Test'
  suite_addTest 'vm_update_boot_loader_Test'
  suite_addTest 'install_kernel_remote_Test'
  suite_addTest 'install_kernel_local_Test'
  suite_addTest 'install_kernel_vm_Test'
  suite_addTest 'install_modules_Test'
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

function update_boot_loader_Test
{
  output=$(update_boot_loader 'xpto' '' 'TEST_MODE')
  cmd=' grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check simple flow' "$LINENO" "$cmd" "$output"

  output=$(update_boot_loader 'xpto' 'local' 'TEST_MODE')
  cmd='sudo -E grub-mkconfig -o /boot/grub/grub.cfg'
  assert_equals_helper 'Check local deploy' "$LINENO" "$cmd" "$output"
}

function vm_update_boot_loader_Test
{
  local name='xpto'
  local cmd_grub='grub-mkconfig -o /boot/grub/grub.cfg'
  local mount_root=": mount /dev/sda1 /"
  local mkdir_init=": mkdir-p /etc/initramfs-tools"
  local cmd_init="update-initramfs -c -k $name"
  local mkdir_grub=": mkdir-p /boot/grub"
  local setup_grub=": write /boot/grub/device.map '(hd0) /dev/sda'"
  local grub_install="grub-install --root-directory=/ --target=i386-pc --force /dev/sda1"

  output=$(vm_update_boot_loader "$name" "$cmd_grub" 'TEST_MODE')
  assert_equals_helper "Invalide case" "$LINENO" "There is no VM in " "$output"

  # We just want to force a positive action in the if condition in order to be
  # able to validate vm boot loader
  configurations[qemu_path_image]='./run_tests.sh'

  guestfish_cmd="guestfish --rw -a ${configurations[qemu_path_image]} run \
      $mount_root \
      $mkdir_init : command '$cmd_init' \
      $setup_grub : command '$grub_install' : command '$cmd_grub'"

  declare -a cmd_sequence=(
    "-> Updating initramfs and grub for $name on VM. This can take a few minutes."
    "sleep 0.5s"
    "$guestfish_cmd"
    "Done."
  )

  output=$(vm_update_boot_loader "$name" "$cmd_grub" 'TEST_MODE')
  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"
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

function install_modules_Test
{
  local module_target='5.9.0-rc5-NEW-VRR-TRACK+.tar'

  output=$(install_modules "$module_target" 'TEST_MODE')
  cmd="tar -C /lib/modules -xf $module_target"
  assert_equals_helper 'Standard uncompression' "$LINENO" "$cmd" "$output"
}

invoke_shunit
