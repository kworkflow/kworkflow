#!/bin/bash

. ./src/plugins/kernel_install/utils.sh --source-only
. ./tests/utils.sh --source-only
. ./src/kwio.sh --source-only

declare -r TEST_ROOT_PATH="$PWD"

function oneTimeSetUp()
{
  declare -g kw_path="$PWD/tests/samples"
  declare -g INSTALLED_KERNELS_PATH="$kw_path/INSTALLED_KERNELS"

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

  # Replace kw_tmp_files
  test_tmp_file="$SHUNIT_TMPDIR/tmp/kw"
  kw_path="$SHUNIT_TMPDIR/opt/kw"
  kw_tmp_files="$test_tmp_file"
  mkdir -p "$test_tmp_file"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
}

function test_cmd_manager()
{
  local count=0

  output=$(cmd_manager 'TEST_MODE' 'ls something')
  assert_equals_helper 'TEST_MODE' "$LINENO" 'ls something' "$output"
}

function test_human_list_installed_kernels()
{
  declare -a expected_out=(
    "sudo mkdir -p $kw_path"
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
  declare -a expected_out=(
    "sudo mkdir -p $kw_path"
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
    "sudo mkdir -p $kw_path"
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

  expected=(
    '' # TODO: Figure out why we have these extra spaces here
    "sudo mkdir -p $kw_path"
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
  local kernelpath="/boot/vmlinuz-$target"
  local initrdpath="/boot/initrd.img-$target"
  local modulespath="/lib/modules/$target"
  local libpath="/var/lib/initramfs-tools/$target"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  local -a cmd_sequence=(
    "sudo mkdir -p $kw_path"
    "sudo touch '$INSTALLED_KERNELS_PATH'"
    "sudo grep -q 'xpto' '$INSTALLED_KERNELS_PATH'"
    "Removing: $target"
    "Can't find $kernelpath"
    "Can't find $kernelpath.old"
    "Can't find $initrdpath"
    "Can't find $modulespath"
    "Can't find $libpath"
    "Can't find /boot/config-$target"
    "sudo sed -i '/xpto/d' '$INSTALLED_KERNELS_PATH'"
    "update_boot_loader xpto local TEST_MODE"
    "grub-mkconfig -o /boot/grub/grub.cfg"
  )

  output=$(kernel_uninstall 0 'local' 'xpto' 'TEST_MODE' 1)
  compare_command_sequence 'cmd_sequence' "$output" "$LINENO"

  cd "$TEST_ROOT_PATH" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_remove_managed_kernel()
{
  local target='xpto'
  local prefix="./test"
  local kernelpath="/boot/vmlinuz-$target"
  local initrdpath="/boot/initrd.img-$target"
  local modulespath="/lib/modules/$target"
  local libpath="/var/lib/initramfs-tools/$target"
  local kernel_name='5.5.0-rc2-VKMS+'

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  local -a cmd_sequence=(
    '' # TODO: Figure out why we have these extra spaces here
    "sudo mkdir -p $kw_path"
    ''
    "sudo touch '$INSTALLED_KERNELS_PATH'"
    ''
    "sudo grep -q '$kernel_name' '$INSTALLED_KERNELS_PATH'"
    "Removing: $kernel_name"
    "Removing: $SHUNIT_TMPDIR//boot/vmlinuz-$kernel_name"
    ''
    "rm $SHUNIT_TMPDIR//boot/vmlinuz-$kernel_name"
    "Removing: $SHUNIT_TMPDIR//boot/vmlinuz-$kernel_name.old"
    ''
    "rm $SHUNIT_TMPDIR//boot/vmlinuz-$kernel_name.old"
    "Can't find $SHUNIT_TMPDIR//boot/initrd.img-$kernel_name"
    "Can't find $SHUNIT_TMPDIR//lib/modules/$kernel_name"
    "Can't find $SHUNIT_TMPDIR//var/lib/initramfs-tools/$kernel_name"
    "Removing: $SHUNIT_TMPDIR//boot/config-$kernel_name"
    ''
    "rm $SHUNIT_TMPDIR//boot/config-$kernel_name"
    ''
    "sudo sed -i '/$kernel_name/d' '$INSTALLED_KERNELS_PATH'"
    "update_boot_loader $kernel_name local"
    ''
    "grub-mkconfig -o /boot/grub/grub.cfg"
  )

  output=$(kernel_uninstall 0 'local' '5.5.0-rc2-VKMS+' '' '' "$SHUNIT_TMPDIR/")
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
  assert_equals_helper 'We did not find required files' "$LINENO" "$?" 2

  cd "$test_tmp_file" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  touch "$module_target"

  output=$(install_modules "$module_target" 'TEST_MODE')
  cmd="tar -C /lib/modules -xf $kw_tmp_files/$module_target"
  assert_equals_helper 'Standard uncompression' "$LINENO" "$cmd" "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
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
    "cp -v $kw_tmp_files/vmlinuz-$name $path_prefix/boot/vmlinuz-$name"
    'generate_debian_temporary_root_file_system_mock'
    'update_debian_boot_loader_mock'
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

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "$sudo_cmd cp -v arch/$architecture/boot/$kernel_image_name $path_prefix/boot/vmlinuz-$name"
    'generate_debian_temporary_root_file_system_mock'
    'update_debian_boot_loader_mock'
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
    "grep -Fxq $name $INSTALLED_KERNELS_PATH"
    #"sudo tee -a '$INSTALLED_KERNELS_PATH' > /dev/null"
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
