#!/bin/bash

# We load utils in the oneTimeSetUp() to ensure we can replace some kw functions
include './tests/utils.sh'
include './src/kwio.sh'

declare -r TEST_ROOT_PATH="$PWD"

function oneTimeSetUp()
{
  # Mocking the sudo function
  function sudo()
  {
    eval "$*"
  }
  export -f sudo

  function grub-mkconfig()
  {
    printf ''
  }
  export -f grub-mkconfig

  # Mock functions
  shopt -s expand_aliases
  alias identify_bootloader_from_files='identify_bootloader_from_files_mock'
  alias run_bootloader_for_vm='run_bootloader_for_vm_mock'
  alias findmnt='findmnt_mock'
  alias vm_umount='vm_umount'
  alias vm_mount='vm_mount_mock'

  . ./src/plugins/kernel_install/utils.sh --source-only

  REMOTE_KW_DEPLOY="$PWD/tests/samples"
  INSTALLED_KERNELS_PATH="$REMOTE_KW_DEPLOY/INSTALLED_KERNELS"
  declare -gA configurations
}

function oneTimeTearDown()
{
  rm -f "$INSTALLED_KERNELS_PATH"
}

function setUp()
{
  mk_fake_boot "$SHUNIT_TMPDIR"

  # Creating fake installed kernels
  touch "$INSTALLED_KERNELS_PATH"
  printf '5.5.0-rc2-VKMS+' >> "$INSTALLED_KERNELS_PATH"
  printf '5.6.0-rc2-AMDGPU+' >> "$INSTALLED_KERNELS_PATH"

  # Replace KW_DEPLOY_TMP_FILE
  test_tmp_file="$SHUNIT_TMPDIR/tmp/kw"
  REMOTE_KW_DEPLOY="$SHUNIT_TMPDIR/opt/kw"
  KW_DEPLOY_TMP_FILE="$test_tmp_file"
  mkdir -p "$test_tmp_file"

  # Mock variables
  KW_PLUGINS_DIR="$PWD/src/plugins"
  REMOTE_KW_DEPLOY="$KW_PLUGINS_DIR/kernel_install"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
}

function identify_bootloader_from_files_mock()
{
  printf 'GRUB'
}

function run_bootloader_for_vm_mock()
{
  printf 'run_bootloader_for_vm_mock\n'
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

function vm_mount_mock()
{
  printf '%s\n' 'vm_mount'
}

function test_cmd_manager()
{
  local output
  local count=0

  output=$(cmd_manager 'TEST_MODE' 'ls something')
  assert_equals_helper 'TEST_MODE' "$LINENO" 'ls something' "$output"
}

function test_human_list_installed_kernels()
{
  local output

  declare -a expected_out=(
    "sudo mkdir -p $REMOTE_KW_DEPLOY"
    "sudo touch $INSTALLED_KERNELS_PATH"
    '5.5.0-rc2-VKMS+'
    '5.6.0-rc2-AMDGPU+'
    'linux'
  )

  printf '%s\n' "${expected_out[@]:2}" > "$INSTALLED_KERNELS_PATH"

  output=$(list_installed_kernels 'TEST_MODE' '0' '' "$SHUNIT_TMPDIR")
  compare_command_sequence 'expected_out' "$output" "$LINENO"
}

function test_command_list_installed_kernels()
{
  local output

  declare -a expected_out=(
    "sudo mkdir -p $REMOTE_KW_DEPLOY"
    "sudo touch $INSTALLED_KERNELS_PATH"
    '5.5.0-rc2-VKMS+,5.6.0-rc2-AMDGPU+,linux'
  )

  printf '%s\n' "${expected_out[-1]/,/$'\n'}" > "$INSTALLED_KERNELS_PATH"

  output=$(list_installed_kernels 'TEST_MODE' '1' '' "$SHUNIT_TMPDIR")
  compare_command_sequence 'expected_out' "$output" "$LINENO"
}

function test_list_unmanaged_kernels()
{
  local output
  local -a expected
  local -a available_kernels=()

  printf '%s' '' > "$INSTALLED_KERNELS_PATH"

  expected=(
    "sudo mkdir -p $REMOTE_KW_DEPLOY"
    "sudo touch $INSTALLED_KERNELS_PATH"
    '5.5.0-rc2-VKMS+,5.6.0-rc2-AMDGPU+,linux'
  )

  # arguments: $flag $single_line $prefix $all
  output=$(list_installed_kernels 'TEST_MODE' '1' '1' "$SHUNIT_TMPDIR")
  compare_command_sequence 'expected' "$output" "($LINENO)"

  rm -rf "$SHUNIT_TMPDIR/boot/grub"

  expected[2]='Could not find grub installed. Cannot list all installed kernels'
  output=$(list_installed_kernels 'TEST_MODE' "1" "$SHUNIT_TMPDIR" "1")
  compare_command_sequence 'expected' "$output" "($LINENO)"
}

function test_list_kernels_based_on_grub()
{
  local output
  local expected_str
  local -a available_kernels=()

  list_installed_kernels_based_on_grub "$SHUNIT_TMPDIR" 'available_kernels'
  expected_str='5.5.0-rc2-VKMS+ 5.6.0-rc2-AMDGPU+ linux'
  assertEquals "($LINENO)" "$expected_str" "${available_kernels[*]}"
}

function test_reboot_machine()
{
  local output

  output=$(reboot_machine '1' '' 'TEST_MODE')
  assert_equals_helper 'Enable reboot in a non-local machine' "$LINENO" 'reboot' "$output"

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
  local output

  expected=(
    '' # TODO: Figure out why we have these extra spaces here
    "sudo mkdir -p $REMOTE_KW_DEPLOY"
    ''
    "sudo touch '$INSTALLED_KERNELS_PATH'"
    ''
    "sudo grep -q 'kname' '$INSTALLED_KERNELS_PATH'"
    'kname not managed by kw. Use --force/-f to uninstall anyway.'
  )

  # Test unmanaged
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(kernel_uninstall '0' 'local' 'kname')
  compare_command_sequence 'expected' "$output" "$LINENO"

  cd "$TEST_ROOT_PATH" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_force_uninstall_unmanaged()
{
  local target='xpto'
  local prefix="./test"
  local kernel_boot_img_path="/boot/vmlinuz-$target"
  local initrd_boot_path="/boot/initrd.img-$target"
  local modules_lib_path="/lib/modules/$target"
  local initramfs_tools_var_path="/var/lib/initramfs-tools/$target"
  local initramfs_boot_img_path="/boot/initramfs-$target.img"
  local initramfs_fallback_boot_img_path="/boot/initramfs-$target-fallback.img"
  local mkinitcpio_d_path="/etc/mkinitcpio.d/$target.preset"
  local output

  # Notice that we are only testing the force feature, we did not create fake
  # files, as a result we can't find files.
  local -a cmd_sequence=(
    "sudo mkdir -p $REMOTE_KW_DEPLOY"
    "sudo touch '$INSTALLED_KERNELS_PATH'"
    "sudo grep -q 'xpto' '$INSTALLED_KERNELS_PATH'"
    "Removing: $target"
    "Can't find $kernel_boot_img_path"
    "Can't find $kernel_boot_img_path.old"
    "Can't find $initrd_boot_path"
    "Can't find $initramfs_boot_img_path"
    "Can't find $initramfs_fallback_boot_img_path"
    "Can't find /boot/config-$target"
    "Can't find $mkinitcpio_d_path"
    "Can't find $initramfs_tools_var_path"
    "Can't find $modules_lib_path"
    "sudo sed -i '/xpto/d' '$INSTALLED_KERNELS_PATH'"
    "update_bootloader xpto local TEST_MODE"
    "sudo -E grub-mkconfig -o /boot/grub/grub.cfg"
  )

  output=$(kernel_uninstall 0 'local' 'xpto' 'TEST_MODE' 1)
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"
}

function test_remove_managed_kernel()
{
  local target='xpto'
  local prefix="./test"
  local kernel_name='5.5.0-rc2-VKMS+'
  local kernel_boot_img_path="/boot/vmlinuz-$target"
  local initrd_boot_path="/boot/initrd.img-$target"
  local modules_lib_path="/lib/modules/$target"
  local initramfs_tools_var_path="/var/lib/initramfs-tools/$target"
  local initramfs_boot_img_path="/boot/initramfs-$kernel_name.img"
  local initramfs_fallback_boot_img_path="/boot/initramfs-$kernel_name-fallback.img"
  local mkinitcpio_d_path="/etc/mkinitcpio.d/$kernel_name.preset"
  local output

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  local -a cmd_sequence=(
    "sudo mkdir -p $REMOTE_KW_DEPLOY"
    "sudo touch '$INSTALLED_KERNELS_PATH'"
    "sudo grep -q '$kernel_name' '$INSTALLED_KERNELS_PATH'"
    "Removing: $kernel_name"
    "Removing: $SHUNIT_TMPDIR//boot/vmlinuz-$kernel_name"
    "rm $SHUNIT_TMPDIR//boot/vmlinuz-$kernel_name"
    "Removing: $SHUNIT_TMPDIR//boot/vmlinuz-$kernel_name.old"
    "rm $SHUNIT_TMPDIR//boot/vmlinuz-$kernel_name.old"
    "Can't find $SHUNIT_TMPDIR//boot/initrd.img-$kernel_name"
    "Can't find $SHUNIT_TMPDIR/$initramfs_boot_img_path"
    "Can't find $SHUNIT_TMPDIR/$initramfs_fallback_boot_img_path"
    "Removing: $SHUNIT_TMPDIR//boot/config-$kernel_name"
    "rm $SHUNIT_TMPDIR//boot/config-$kernel_name"
    "Can't find $SHUNIT_TMPDIR/$mkinitcpio_d_path"
    "Can't find $SHUNIT_TMPDIR//var/lib/initramfs-tools/$kernel_name"
    "Can't find $SHUNIT_TMPDIR//lib/modules/$kernel_name"
    "sudo sed -i '/$kernel_name/d' '$INSTALLED_KERNELS_PATH'"
    "update_bootloader $kernel_name local TEST_MODE"
    'sudo -E grub-mkconfig -o /boot/grub/grub.cfg'
  )

  output=$(kernel_uninstall 0 'local' '5.5.0-rc2-VKMS+' 'TEST_MODE' '' "$SHUNIT_TMPDIR/")
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
  local kernel_boot_img_path="$prefix/boot/vmlinuz-$target"
  local initrd_boot_path="$prefix/boot/initrd.img-$target"
  local modules_lib_path="$prefix/lib/modules/$target"
  local initramfs_tools_var_path="$prefix/var/lib/initramfs-tools/$target"
  local config_boot_path="$prefix/boot/config-$target"
  local initramfs_boot_img_path="$prefix/boot/initramfs-$target.img"
  local initramfs_fallback_boot_img_path="$prefix/boot/initramfs-$target-fallback.img"
  local mkinitcpio_d_path="$prefix/etc/mkinitcpio.d/$target.preset"
  local output

  # TEST 1: Invalid path
  declare -a cmd_sequence=(
    "Can't find $kernel_boot_img_path"
    "Can't find $kernel_boot_img_path.old"
    "Can't find $initrd_boot_path"
    "Can't find $initramfs_boot_img_path"
    "Can't find $initramfs_fallback_boot_img_path"
    "Can't find $config_boot_path"
    "Can't find $mkinitcpio_d_path"
    "Can't find $initramfs_tools_var_path"
    "Can't find $modules_lib_path"
  )

  output=$(do_uninstall "$target" "$prefix" "$TEST_MODE")
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"

  # TEST 2: Valid paths
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  mkdir -p "$prefix"
  mk_fake_remote_system "$prefix" "$target"

  declare -a cmd_sequence=(
    "Removing: $kernel_boot_img_path"
    "rm $kernel_boot_img_path"
    "Removing: $kernel_boot_img_path.old"
    "rm $kernel_boot_img_path.old"
    "Removing: $initrd_boot_path"
    "rm $initrd_boot_path"
    "Removing: $initramfs_boot_img_path"
    "rm $initramfs_boot_img_path"
    "Removing: $initramfs_fallback_boot_img_path"
    "rm $initramfs_fallback_boot_img_path"
    "Removing: $config_boot_path"
    "rm $config_boot_path"
    "Removing: $mkinitcpio_d_path"
    "rm $mkinitcpio_d_path"
    "Removing: $initramfs_tools_var_path"
    "rm $initramfs_tools_var_path"
    "Removing: $modules_lib_path"
    "rm -rf $modules_lib_path"
  )

  output=$(do_uninstall "$target" "$prefix" 'TEST_MODE')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"

  # Partial sequence
  rm "$kernel_boot_img_path.old"
  rm -rf "$modules_lib_path"
  declare -a cmd_sequence=(
    "Removing: $kernel_boot_img_path"
    "rm $kernel_boot_img_path"
    "Can't find $kernel_boot_img_path.old"
    "Removing: $initrd_boot_path"
    "rm $initrd_boot_path"
    "Removing: $initramfs_boot_img_path"
    "rm $initramfs_boot_img_path"
    "Removing: $initramfs_fallback_boot_img_path"
    "rm $initramfs_fallback_boot_img_path"
    "Removing: $config_boot_path"
    "rm $config_boot_path"
    "Removing: $mkinitcpio_d_path"
    "rm $mkinitcpio_d_path"
    "Removing: $initramfs_tools_var_path"
    "rm $initramfs_tools_var_path"
    "Can't find $modules_lib_path"
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
  local output

  output=$(install_modules "$module_target" 'TEST_MODE')
  assert_equals_helper 'We did not find required files' "$LINENO" "$?" 2

  cd "$test_tmp_file" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  touch "$module_target"

  output=$(install_modules "$module_target" 'TEST_MODE')
  cmd="tar -C /lib/modules -xf $KW_DEPLOY_TMP_FILE/$module_target"
  assert_equals_helper 'Standard uncompression' "$LINENO" "$cmd" "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
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
  local output

  output=$(install_kernel '' 'debian' "$kernel_image_name" "$reboot" "$architecture" "$target" 'TEST_MODE')
  ret="$?"
  assert_equals_helper 'Test invalid name' "$LINENO" '22' "$ret"

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "cp -v $KW_DEPLOY_TMP_FILE/vmlinuz-$name $path_prefix/boot/vmlinuz-$name"
    'generate_debian_temporary_root_file_system_mock'
    'grub-mkconfig -o /boot/grub/grub.cfg'
    "grep -Fxq $name $INSTALLED_KERNELS_PATH"
    #"sudo tee -a '$INSTALLED_KERNELS_PATH' > /dev/null"
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
  local output

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "$sudo_cmd cp -v arch/$architecture/boot/$kernel_image_name $path_prefix/boot/vmlinuz-$name"
    'generate_debian_temporary_root_file_system_mock'
    'sudo -E grub-mkconfig -o /boot/grub/grub.cfg'
    "grep -Fxq $name $INSTALLED_KERNELS_PATH"
    #"sudo tee -a '$INSTALLED_KERNELS_PATH' > /dev/null"
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
  local output

  # Setup this specific test
  touch "$SHUNIT_TMPDIR/boot/vmlinuz-$name"
  touch "$SHUNIT_TMPDIR/.config"
  touch "$SHUNIT_TMPDIR/virty.qcow2"
  rm -rf "${SHUNIT_TMPDIR:?}"/boot
  configurations[mount_point]="$SHUNIT_TMPDIR"
  configurations[qemu_path_image]="$SHUNIT_TMPDIR/virty.qcow2"

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "cp -v .config $path_prefix/boot/config-$name"
    "cp -v arch/$architecture/boot/$kernel_image_name $path_prefix/boot/vmlinuz-$name"
    'generate_debian_temporary_root_file_system_mock'
    'vm_mount'
    'run_bootloader_for_vm_mock'
    'vm_umount'
    'vm_mount'
    "touch $SHUNIT_TMPDIR/$INSTALLED_KERNELS_PATH"
    "grep -Fxq $name $SHUNIT_TMPDIR/$INSTALLED_KERNELS_PATH"
    'vm_umount'
    #"sudo tee -a '$INSTALLED_KERNELS_PATH' > /dev/null"
  )

  output=$(install_kernel "$name" 'debian' "$kernel_image_name" "$reboot" "$architecture" "$target" 'TEST_MODE')
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"
}

function test_distro_deploy_setup()
{
  local output
  local expected_cmd

  package_manager_cmd='yes | some_package_manager'
  required_packages=(
    'abc'
    'def'
    'xpto'
  )
  output=$(distro_deploy_setup 'TEST_MODE')

  expected_cmd="$package_manager_cmd ${required_packages[*]} "

  assert_equals_helper 'Install packages' "$LINENO" "$expected_cmd" "$output"
}

invoke_shunit
