#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./tests/utils.sh --source-only
. ./src/kwio.sh --source-only

declare -r TEST_ROOT_PATH="$PWD"

function oneTimeSetUp()
{
  declare -g REMOTE_KW_DEPLOY="$PWD/tests/samples"
  declare -g INSTALLED_KERNELS_PATH="$REMOTE_KW_DEPLOY/INSTALLED_KERNELS"

  # Mocking the sudo function
  function sudo()
  {
    eval "$*"
  }
  export -f sudo
}

function oneTimeTearDown()
{
  rm -f "$INSTALLED_KERNELS_PATH"
}

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

  output=$(cmd_manager "TEST_MODE" "ls something")
  assert_equals_helper "TEST_MODE" "$LINENO" "ls something" "$output"
}

function test_ask_yN()
{
  local count=0

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

function test_human_list_installed_kernels()
{
  declare -a expected_out=(
    "sudo mkdir -p $REMOTE_KW_DEPLOY"
    "sudo touch $INSTALLED_KERNELS_PATH"
    '5.5.0-rc2-VKMS+'
    '5.6.0-rc2-AMDGPU+'
    'linux'
  )

  printf '%s\n' "${expected_out[@]}" > "$INSTALLED_KERNELS_PATH"

  output=$(list_installed_kernels 'TEST_MODE' '0' "$SHUNIT_TMPDIR")
  compare_command_sequence 'expected_out' "$output" "$LINENO"
}

function test_command_list_installed_kernels()
{
  declare -a expected_out=(
    "sudo mkdir -p $REMOTE_KW_DEPLOY"
    "sudo touch $INSTALLED_KERNELS_PATH"
    '5.5.0-rc2-VKMS+,5.6.0-rc2-AMDGPU+,linux'
  )

  printf '%s\n' "${expected_out[@]/,/$'\n'}" > "$INSTALLED_KERNELS_PATH"

  output=$(list_installed_kernels 'TEST_MODE' '1' "$SHUNIT_TMPDIR")
  compare_command_sequence 'expected_out' "$output" "$LINENO"
}

function test_list_unmanaged_kernels()
{
  local output
  local expected

  echo -n '' > "$INSTALLED_KERNELS_PATH"

  expected=(
    "sudo mkdir -p $REMOTE_KW_DEPLOY"
    "sudo touch $INSTALLED_KERNELS_PATH"
    '5.5.0-rc2-VKMS+,5.5.0-rc2-VKMS+.old,5.6.0-rc2-AMDGPU+,linux'
  )

  # arguments: $flag $single_line $prefix $all
  output=$(list_installed_kernels 'TEST_MODE' "1" "$SHUNIT_TMPDIR" "1")
  compare_command_sequence 'expected' "$output" "($LINENO)"
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

function test_kernel_uninstall_unmanaged()
{
  local output
  local -a expected

  expected=(
    "sudo mkdir -p '$REMOTE_KW_DEPLOY'"
    "sudo touch '$INSTALLED_KERNELS_PATH'"
    "sudo grep -q 'kname' '$INSTALLED_KERNELS_PATH'"
    'Kernel not managed by kw. Use --force/-f to uninstall anyway.'
  )
  # Test unmanaged
  output=$(kernel_uninstall 'TEST_MODE' '0' 'local' 'kname' 'TEST_MODE' '')
  compare_command_sequence 'expected' "$output" "$LINENO"
}

function test_kernel_uninstall_managed()
{
  local target='xpto'
  local prefix="./test"
  local kernelpath="/boot/vmlinuz-$target"
  local initrdpath="/boot/initrd.img-$target"
  local modulespath="/lib/modules/$target"
  local libpath="/var/lib/initramfs-tools/$target"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  local -a cmd_sequence=(
    "sudo mkdir -p '$REMOTE_KW_DEPLOY'"
    "sudo touch '$INSTALLED_KERNELS_PATH'"
    "sudo grep -q 'xpto' '$INSTALLED_KERNELS_PATH'"
    "Removing: $target"
    "Can't find $kernelpath"
    "Can't find $kernelpath.old"
    "Can't find $initrdpath"
    "Can't find $modulespath"
    "Can't find $libpath"
    "update_boot_loader xpto local TEST_MODE"
    "grub-mkconfig -o /boot/grub/grub.cfg"
    "sudo sed -i '/xpto/d' '$INSTALLED_KERNELS_PATH'"
  )

  output=$(kernel_uninstall 'TEST_MODE' 0 'local' 'xpto' 'TEST_MODE' '1')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"

  cd "$TEST_ROOT_PATH" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_do_uninstall_cmd_sequence()
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
  echo 'generate_debian_temporary_root_file_system_mock'
}

function update_debian_boot_loader()
{
  echo 'update_debian_boot_loader_mock'
}

function findmnt_mock()
{
  echo "TARGET SOURCE         FSTYPE OPTIONS"
  echo "/home  /dev/lala ext4   rw,relatime"
}

function vm_umount()
{
  echo "vm_umount"
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
    "sudo tee -a '$INSTALLED_KERNELS_PATH' > /dev/null"
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
    "sudo tee -a '$INSTALLED_KERNELS_PATH' > /dev/null"
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
    "vm_umount"
    'update_debian_boot_loader_mock'
    "sudo tee -a '$INSTALLED_KERNELS_PATH' > /dev/null"
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
