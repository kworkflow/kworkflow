#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./tests/utils --source-only
. ./src/kwio.sh --source-only

function suite
{
  suite_addTest "human_list_installed_kernels_Test"
  suite_addTest "comman_list_installed_kernels_Test"
  suite_addTest "cmd_manager_Test"
  suite_addTest "ask_yN_Test"
  suite_addTest "reboot_machine_Test"
  suite_addTest "do_uninstall_cmd_sequence_Test"
  suite_addTest 'install_modules_Test'
  suite_addTest 'vm_update_boot_loader_debian_Test'
  suite_addTest 'vm_update_boot_loader_arch_Test'
}

declare -r TEST_ROOT_PATH="$PWD"

function setUp
{
  rm -rf "$TMP_TEST_DIR"

  local current_path="$PWD"

  mk_fake_boot "$TMP_TEST_DIR"
}

function tearDown()
{
  rm -rf "$TMP_TEST_DIR"
}

function cmd_manager_Test
{
  local count=0
  local current_path="$PWD"

  output=$(cmd_manager "TEST_MODE" "ls something")
  assert_equals_helper "TEST_MODE" "$LINENO" "ls something" "$output"
}

function ask_yN_Test
{
  local count=0
  local current_path="$PWD"

  output=$(echo 'y' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "1" "$output"

  output=$(echo 'Y' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "1" "$output"

  output=$(echo 'Yes' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "1" "$output"

  output=$(echo 'Sim' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "0" "$output"

  output=$(echo 'No' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "0" "$output"

  output=$(echo 'N' | ask_yN "Test message")
  assert_equals_helper "TEST_MODE" "$LINENO" "0" "$output"
}


function human_list_installed_kernels_Test
{
  local count=0

  declare -a expected_out=(
    "" # Extra espace in the beginning
    "5.5.0-rc2-VKMS+"
    "5.6.0-rc2-AMDGPU+"
    "linux"
  )

  output=$(list_installed_kernels "0" "$TMP_TEST_DIR")
  while read out; do
    assertEquals "$count - Expected kernel list" "${expected_out[$count]}" "$out"
    ((count++))
  done <<< "$output"
}

function comman_list_installed_kernels_Test
{
  local count=0

  declare -a expected_out=(
    "" # Extra espace in the beginning
    "5.5.0-rc2-VKMS+,5.6.0-rc2-AMDGPU+,linux"
  )

  output=$(list_installed_kernels "1" "$TMP_TEST_DIR")
  while read out; do
    assertEquals "$count - Expected kernel list" "${expected_out[$count]}" "$out"
    ((count++))
  done <<< "$output"

}

function reboot_machine_Test
{
  output=$(reboot_machine '1' '' 'TEST_MODE')
  assert_equals_helper 'Enable reboot in a non-local machine' "$LINENO" ' reboot' "$output"

  output=$(reboot_machine '0' '' 'TEST_MODE')
  assert_equals_helper 'Disable reboot in a non-local machine' "$LINENO" '' "$output"

  output=$(reboot_machine '1' 'local' 'TEST_MODE')
  assert_equals_helper 'Disable reboot in a non-local machine' "$LINENO" 'sudo -E reboot' "$output"

  output=$(reboot_machine '1' 'local' 'TEST_MODE')
  assert_equals_helper 'Disable reboot in a non-local machine' "$LINENO" 'sudo -E reboot' "$output"
}

function do_uninstall_cmd_sequence_Test
{
  local target='xpto'
  local prefix="./test"
  local kernelpath="$prefix/boot/vmlinuz-$target"
  local initrdpath="$prefix/boot/initrd.img-$target"
  local modulespath="$prefix/lib/modules/$target"
  local libpath="$prefix/var/lib/initramfs-tools/$target"

  # Invalid path
  declare -a cmd_sequence=(
    "Can't find $kernelpath"
    "Can't find $kernelpath.old"
    "Can't find $initrdpath"
    "Can't find $modulespath"
    "Can't find $libpath"
    "Can't find $libpath"
  )

  output=$(do_uninstall "$target" "$prefix" "$TEST_MODE")
  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"

  # Good sequence
  cd "$TMP_TEST_DIR"
  mkdir -p "$prefix"
  mk_fake_remote_system "$prefix" "$target"

  declare -a cmd_sequence=(
    "Removing: $kernelpath"
    "rm $kernelpath"
    "Removing: $kernelpath.old"
    "rm $kernelpath.old"
    "Removing: $initrdpath"
    "rm -rf $initrdpath"
    "Removing: $modulespath"
    "rm -rf $modulespath"
    "Removing: $libpath"
    "rm -rf $libpath"
  )

  output=$(do_uninstall "$target" "$prefix" 'TEST_MODE')
  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"

  # Partial sequence
  rm "$kernelpath.old"
  rm -rf "$modulespath"
  declare -a cmd_sequence=(
    "Removing: $kernelpath"
    "rm $kernelpath"
    "Can't find $kernelpath.old"
    "Removing: $initrdpath"
    "rm -rf $initrdpath"
    "Can't find $modulespath"
    "Removing: $libpath"
    "rm -rf $libpath"
  )

  output=$(do_uninstall "$target" "$prefix" 'TEST_MODE')
  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"

  cd "$TEST_ROOT_PATH"
}

function install_modules_Test
{
  local module_target='5.9.0-rc5-NEW-VRR-TRACK+.tar'
  local cmd

  output=$(install_modules "$module_target" 'TEST_MODE')
  cmd="tar -C /lib/modules -xf $module_target"
  assert_equals_helper 'Standard uncompression' "$LINENO" "$cmd" "$output"
}

function vm_update_boot_loader_debian_Test
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

  # Debian

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

  output=$(vm_update_boot_loader "$name" 'debian' "$cmd_grub" "$cmd_init" "$setup_grub" "$grub_install" 'TEST_MODE')

  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"
}

function vm_update_boot_loader_arch_Test
{
  local name='xpto'
  local cmd_grub='grub-mkconfig -o /boot/grub/grub.cfg'
  local mount_root=": mount /dev/sda1 /"
  local mkdir_grub=": mkdir-p /boot/grub"
  local cmd_init="dracut --regenerate-all -f"
  local setup_grub=": write /boot/grub/device.map '(hd0,1) /dev/sda'"
  local grub_install="grub-install --directory=/usr/lib/grub/i386-pc --target=i386-pc --boot-directory=/boot --recheck --debug /dev/sda"

  configurations[qemu_path_image]=''
  output=$(vm_update_boot_loader "$name" "$cmd_grub" 'TEST_MODE')
  assert_equals_helper "Invalide case" "$LINENO" "There is no VM in " "$output"

  # Debian

  # We just want to force a positive action in the if condition in order to be
  # able to validate vm boot loader
  configurations[qemu_path_image]='./run_tests.sh'

  guestfish_cmd="guestfish --rw -a ${configurations[qemu_path_image]} run \
        $mount_root : command '$cmd_init' \
        $mkdir_grub $setup_grub : command '$grub_install' \
        : command '$cmd_grub'"

  declare -a cmd_sequence=(
    "-> Updating initramfs and grub for $name on VM. This can take a few minutes."
    "sleep 0.5s"
    "$guestfish_cmd"
    "Done."
  )

  output=$(vm_update_boot_loader "$name" 'arch' "$cmd_grub" "$cmd_init" "$setup_grub" "$grub_install" 'TEST_MODE')

  compare_command_sequence cmd_sequence[@] "$output" "$LINENO"
}

invoke_shunit
