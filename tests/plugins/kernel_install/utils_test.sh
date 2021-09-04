#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./tests/utils.sh --source-only
. ./src/kwio.sh --source-only

declare -r TEST_ROOT_PATH="$PWD"

function setUp()
{
  local current_path="$PWD"

  mk_fake_boot "$SHUNIT_TMPDIR"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
}

function test_cmd_manager()
{
  local count=0
  local current_path="$PWD"

  output=$(cmd_manager 'TEST_MODE' 'ls something')
  assert_equals_helper 'TEST_MODE' "$LINENO" 'ls something' "$output"
}

function test_ask_yN()
{
  local count=0

  output=$(printf '%s\n' 'y' | ask_yN 'Test message')
  assert_equals_helper 'TEST_MODE' "$LINENO" '1' "$output"

  output=$(printf '%s\n' 'Y' | ask_yN 'Test message')
  assert_equals_helper 'TEST_MODE' "$LINENO" '1' "$output"

  output=$(printf '%s\n' 'Yes' | ask_yN 'Test message')
  assert_equals_helper 'TEST_MODE' "$LINENO" '1' "$output"

  output=$(printf '%s\n' 'Sim' | ask_yN 'Test message')
  assert_equals_helper 'TEST_MODE' "$LINENO" '0' "$output"

  output=$(printf '%s\n' 'No' | ask_yN 'Test message')
  assert_equals_helper 'TEST_MODE' "$LINENO" '0' "$output"

  output=$(printf '%s\n' 'N' | ask_yN 'Test message')
  assert_equals_helper 'TEST_MODE' "$LINENO" '0' "$output"
}

function test_human_list_installed_kernels()
{
  local count=0

  declare -a expected_out=(
    '' # Extra espace in the beginning
    '5.5.0-rc2-VKMS+'
    '5.6.0-rc2-AMDGPU+'
    'linux'
  )

  output=$(list_installed_kernels '0' "$SHUNIT_TMPDIR")
  while read -r out; do
    assertEquals "$count - Expected kernel list" "${expected_out[$count]}" "$out"
    ((count++))
  done <<< "$output"
}

function test_command_list_installed_kernels()
{
  local count=0

  declare -a expected_out=(
    '' # Extra espace in the beginning
    '5.5.0-rc2-VKMS+,5.6.0-rc2-AMDGPU+,linux'
  )

  output=$(list_installed_kernels '1' "$SHUNIT_TMPDIR")
  while read -r out; do
    assertEquals "$count - Expected kernel list" "${expected_out[$count]}" "$out"
    ((count++))
  done <<< "$output"

}

function test_reboot_machine()
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

function test_do_uninstall_cmd_sequence()
{
  local target='xpto'
  local prefix="./test"
  local kernelpath="$prefix/boot/vmlinuz-$target"
  local initrdpath="$prefix/boot/initrd.img-$target"
  local modulespath="$prefix/lib/modules/$target"
  local libpath="$prefix/var/lib/initramfs-tools/$target"
  local configpath="$prefix/boot/config-$target"

  # Invalid path
  declare -a cmd_sequence=(
    "Can't find $kernelpath"
    "Can't find $kernelpath.old"
    "Can't find $initrdpath"
    "Can't find $modulespath"
    "Can't find $libpath"
    "Can't find $configpath"
  )

  output=$(do_uninstall "$target" "$prefix" "$TEST_MODE")
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"

  # Good sequence
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
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
    "Removing: $configpath"
    "rm $configpath"
  )

  output=$(do_uninstall "$target" "$prefix" 'TEST_MODE')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"

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
    "Removing: $configpath"
    "rm $configpath"
  )

  output=$(do_uninstall "$target" "$prefix" 'TEST_MODE')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"

  cd "$TEST_ROOT_PATH" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_install_modules()
{
  local module_target='5.9.0-rc5-NEW-VRR-TRACK+.tar'
  local cmd

  output=$(install_modules "$module_target" 'TEST_MODE')
  cmd="tar -C /lib/modules -xf $module_target"
  assert_equals_helper 'Standard uncompression' "$LINENO" "$cmd" "$output"
}

function test_vm_update_boot_loader_debian()
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

  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"
}

function test_vm_update_boot_loader_arch()
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

  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"
}

# Mock funtions for install tests
function generate_debian_temporary_root_file_system()
{
  printf '%s\n' 'generate_debian_temporary_root_file_system_mock'
}

function update_debian_boot_loader()
{
  printf '%s\n' 'update_debian_boot_loader_mock'
}

function findmnt_mock()
{
  printf '%s\n' 'TARGET SOURCE         FSTYPE OPTIONS'
  printf '%s\n' '/home  /dev/lala ext4   rw,relatime'
}

function vm_umount()
{
  printf '%s\n' 'vm_umount'
}

function test_install_kernel_remote()
{
  local name='5.9.0-rc5-TEST'
  local kernel_image_name='bzImage'
  local reboot='1'
  local architecture='x86_64'
  local target='remote'
  local flag='TEST_MODE'
  local path_prefix=''

  output=$(install_kernel '' 'debian' "$kernel_image_name" "$reboot" "$architecture" "$target" 'TEST_MODE')
  ret="$?"
  assert_equals_helper 'Test invalid name' "$LINENO" '22' "$ret"

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "cp -v vmlinuz-$name $path_prefix/boot/vmlinuz-$name"
    'generate_debian_temporary_root_file_system_mock'
    'update_debian_boot_loader_mock'
    'reboot'
  )
  output=$(install_kernel "$name" 'debian' "$kernel_image_name" "$reboot" "$architecture" "$target" 'TEST_MODE')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"
}

function test_install_kernel_local()
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
    'generate_debian_temporary_root_file_system_mock'
    'update_debian_boot_loader_mock'
    "$sudo_cmd reboot"
  )

  output=$(install_kernel "$name" 'debian' "$kernel_image_name" "$reboot" "$architecture" "$target" 'TEST_MODE')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"
}

function test_install_kernel_vm()
{
  local name='5.9.0-rc5-TEST'
  local kernel_image_name='bzImage'
  local reboot='1'
  local architecture='x86_64'
  local target='vm'
  local path_prefix="$SHUNIT_TMPDIR"

  # Setup this specific test
  touch "$SHUNIT_TMPDIR/boot/vmlinuz-$name"
  touch "$SHUNIT_TMPDIR/.config"
  touch "$SHUNIT_TMPDIR/virty.qcow2"
  rm -rf "${SHUNIT_TMPDIR:?}"/boot
  configurations[mount_point]="$SHUNIT_TMPDIR"

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "cp -v .config $path_prefix/boot/config-$name"
    "cp -v arch/$architecture/boot/$kernel_image_name $path_prefix/boot/vmlinuz-$name"
    'generate_debian_temporary_root_file_system_mock'
    'vm_umount'
    'update_debian_boot_loader_mock'
  )

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  shopt -s expand_aliases
  alias findmnt='findmnt_mock'
  alias vm_umount='vm_umount'

  output=$(install_kernel "$name" 'debian' "$kernel_image_name" "$reboot" "$architecture" "$target" 'TEST_MODE')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"

  cd "$TEST_ROOT_PATH" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

invoke_shunit
