#!/usr/bin/env bash

# We load utils in the oneTimeSetUp() to ensure we can replace some kw functions
include './tests/unit/utils.sh'
include './src/plugins/kernel_install/bootloader_utils.sh'
include './src/lib/kwlib.sh'
include './src/lib/kwio.sh'

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

  # Setup a fake path to make easier to mock some scenarios
  TARGET_PATH="$SHUNIT_TMPDIR"

  # Mock functions
  shopt -s expand_aliases
  alias identify_bootloader_from_files='identify_bootloader_from_files_mock'
  alias run_bootloader_update='run_bootloader_update_mock'
  alias generate_debian_temporary_root_file_system='generate_debian_temporary_root_file_system_mock'
  alias findmnt='findmnt_mock'
  alias total_of_installed_kernels='total_of_installed_kernels_mock'

  . ./src/plugins/kernel_install/utils.sh --source-only

  REMOTE_KW_DEPLOY="${PWD}/tests/unit/samples"
  INSTALLED_KERNELS_PATH="${REMOTE_KW_DEPLOY}/INSTALLED_KERNELS"
}

function oneTimeTearDown()
{
  rm -f "$INSTALLED_KERNELS_PATH"
  # shellcheck disable=SC2115
  [[ -d ${TARGET_PATH} ]] && rm --recursive --force "${TARGET_PATH}/*"
}

function setUp()
{
  mk_fake_boot "$SHUNIT_TMPDIR"

  # Creating fake installed kernels
  touch "$INSTALLED_KERNELS_PATH"
  printf '5.5.0-rc2-VKMS+' >> "$INSTALLED_KERNELS_PATH"
  printf '\n%s' '5.6.0-rc2-AMDGPU+' >> "$INSTALLED_KERNELS_PATH"

  # Replace KW_DEPLOY_TMP_FILE
  test_tmp_file="${SHUNIT_TMPDIR}/tmp/kw"
  REMOTE_KW_DEPLOY="${SHUNIT_TMPDIR}/opt/kw"
  KW_DEPLOY_TMP_FILE="$test_tmp_file"
  mkdir --parents "$test_tmp_file"

  # Mock variables
  KW_PLUGINS_DIR="${PWD}/src/plugins"
  REMOTE_KW_DEPLOY="${KW_PLUGINS_DIR}/kernel_install"
}

function tearDown()
{
  rm --recursive --force "$SHUNIT_TMPDIR"
  mkdir --parents "$SHUNIT_TMPDIR"
}

function total_of_installed_kernels_mock()
{
  printf '5'
}

function identify_bootloader_from_files_mock()
{
  printf 'GRUB'
}

function run_bootloader_update_mock()
{
  printf 'run_bootloader_update_mock\n'
}

# Mock funtions for install tests
function generate_debian_temporary_root_file_system()
{
  printf '%s\n' 'generate_debian_temporary_root_file_system_mock'
  return 0
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

function findmnt_only_filesystem_mock()
{
  # findmnt --first-only --noheadings --output FSTYPE "$target_path"
  printf 'btrfs'
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
    "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
    '5.5.0-rc2-VKMS+'
    '5.6.0-rc2-AMDGPU+'
    'linux'
  )

  printf '%s\n' "${expected_out[@]:1}" > "$INSTALLED_KERNELS_PATH"

  output="$(
    function is_filesystem_writable()
    {
      return 0
    }
    list_installed_kernels 'TEST_MODE' '0' '' "${SHUNIT_TMPDIR}"
  )"

  compare_command_sequence '' "$LINENO" 'expected_out' "$output"
}

function test_command_list_installed_kernels()
{
  local output

  declare -a expected_out=(
    "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
    '5.5.0-rc2-VKMS+,5.6.0-rc2-AMDGPU+,linux'
  )

  printf '%s\n' "${expected_out[-1]/,/$'\n'}" > "$INSTALLED_KERNELS_PATH"

  output="$(
    function is_filesystem_writable()
    {
      return 0
    }
    list_installed_kernels 'TEST_MODE' '1' '' "${SHUNIT_TMPDIR}"
  )"

  compare_command_sequence '' "$LINENO" 'expected_out' "$output"
}

function test_list_unmanaged_kernels()
{
  local output
  local -a expected
  local -a available_kernels=()

  printf '%s' '' > "$INSTALLED_KERNELS_PATH"

  expected=(
    "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
    '5.5.0-rc2-VKMS+,5.6.0-rc2-AMDGPU+,linux'
  )

  output="$(
    function is_filesystem_writable()
    {
      return 0
    }
    list_installed_kernels 'TEST_MODE' '1' '1' "${SHUNIT_TMPDIR}"
  )"
  compare_command_sequence '' "$LINENO" 'expected' "$output"
}

function test_list_all_kernels_no_match()
{
  local -a expected_result
  local -a available_kernels=()

  expected_result=()

  # Remove all files from /boot to ensure an empty list
  if [[ -d "${SHUNIT_TMPDIR}/boot" ]]; then
    find "${SHUNIT_TMPDIR}/boot/" -maxdepth 1 -type f -delete
  fi

  list_all_kernels "$SHUNIT_TMPDIR" available_kernels 'TEST_MODE'
  compare_array_values expected_result available_kernels "$LINENO"
}

function test_reboot_machine()
{
  local output

  output=$(reboot_machine '1' '' 'TEST_MODE')
  assert_equals_helper 'Enable reboot in a non-local machine' "$LINENO" 'reboot' "$output"

  output=$(reboot_machine '0' '' 'TEST_MODE')
  assert_equals_helper 'Disable reboot in a non-local machine' "$LINENO" '' "$output"

  output=$(reboot_machine '1' 'local' 'TEST_MODE')
  assert_equals_helper 'Disable reboot in a non-local machine' "$LINENO" 'sudo --preserve-env reboot' "$output"

  output=$(reboot_machine '1' 'local' 'TEST_MODE')
  assert_equals_helper 'Disable reboot in a non-local machine' "$LINENO" 'sudo --preserve-env reboot' "$output"
}

function test_is_in_array()
{
  local -a array=(1 2 3 4 5)

  is_in_array 0 'array'
  assert_equals_helper 'Should return 1 (not present)' "$LINENO" 1 "$?"
  is_in_array 4 'array'
  assert_equals_helper 'Should return 0 (present)' "$LINENO" 0 "$?"
}

function test_process_installed_kernels()
{
  local -a processed_installed_kernels
  local original_list_installed_kernels_definition

  original_list_installed_kernels_definition=$(declare -f list_installed_kernels)
  # shellcheck disable=SC2317
  function list_installed_kernels()
  {
    local all_kernels="$3"

    if [[ -n "$all_kernels" ]]; then
      printf 'kernel1,kernel2,notmanaged'
    else
      printf 'kernel1,kernel2'
    fi
  }

  processed_installed_kernels=('should' 'be' 'cleared' 'prior')
  process_installed_kernels '' '' 'processed_installed_kernels'
  assert_equals_helper 'Wrong number of elements' "$LINENO" 2 "${#processed_installed_kernels[@]}"
  assert_equals_helper 'Wrong element 0' "$LINENO" 'kernel1' "${processed_installed_kernels[0]}"
  assert_equals_helper 'Wrong element 1' "$LINENO" 'kernel2' "${processed_installed_kernels[1]}"

  processed_installed_kernels=('should' 'be' 'cleared' 'prior')
  process_installed_kernels 1 '' 'processed_installed_kernels'
  assert_equals_helper 'Wrong number of elements' "$LINENO" 3 "${#processed_installed_kernels[@]}"
  assert_equals_helper 'Wrong element 0' "$LINENO" 'kernel1' "${processed_installed_kernels[0]}"
  assert_equals_helper 'Wrong element 1' "$LINENO" 'kernel2' "${processed_installed_kernels[1]}"
  assert_equals_helper 'Wrong element 2' "$LINENO" 'notmanaged' "${processed_installed_kernels[2]}"

  eval "$original_list_installed_kernels_definition"
}

function test_kernel_uninstall_regex_one_kernel()
{
  local kernel_name='5.5.0-rc2-VKMS+'
  local mkinitcpio_d_path_1="etc/mkinitcpio.d/${kernel_name}.preset"
  local grub_cfg_path="${TARGET_PATH}/boot/grub/grub.cfg"
  local output
  local boot_files
  local index

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Composing expected command sequence
  local -a cmd_sequence=(
    "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
    "sudo touch '${INSTALLED_KERNELS_PATH}'"
    "Removing: ${kernel_name}"
  )
  index=${#cmd_sequence[@]}

  boot_files=$(find "${TARGET_PATH}/boot/" -name "*${kernel_name}*" | sort)
  # shellcheck disable=SC2068
  for file in ${boot_files[@]}; do
    cmd_sequence["$((index++))"]="Removing: ${file}"
    cmd_sequence["$((index++))"]="sudo --preserve-env rm ${file}"
  done

  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/${mkinitcpio_d_path_1}"
  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/var/lib/initramfs-tools/${kernel_name}"
  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/lib/modules/${kernel_name}"
  cmd_sequence["$((index++))"]="sudo sed -i '/${kernel_name}/d' '$INSTALLED_KERNELS_PATH'"
  cmd_sequence["$((index++))"]='run_bootloader_update_mock'

  # Check
  output=$(kernel_uninstall 0 'local' 'regex:.*VKMS.*' 'TEST_MODE' '' "$SHUNIT_TMPDIR")
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_uninstall_regex_two_kernels()
{
  local kernel_name_1='5.5.0-rc2-VKMS+'
  local kernel_name_2='5.6.0-rc2-AMDGPU+'
  local mkinitcpio_d_path_1="etc/mkinitcpio.d/${kernel_name_1}.preset"
  local mkinitcpio_d_path_2="etc/mkinitcpio.d/${kernel_name_2}.preset"
  local output
  local boot_files
  local index

  cd "$SHUNIT_TMPDIR" || {

    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Composing expected command sequence
  local -a cmd_sequence=(
    "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
    "sudo touch '${INSTALLED_KERNELS_PATH}'"
    "Removing: ${kernel_name_1}"
  )
  index=${#cmd_sequence[@]}

  boot_files=$(find "${TARGET_PATH}/boot/" -name "*${kernel_name_1}*" | sort)
  # shellcheck disable=SC2068
  for file in ${boot_files[@]}; do
    cmd_sequence["$((index++))"]="Removing: ${file}"
    cmd_sequence["$((index++))"]="sudo --preserve-env rm ${file}"
  done

  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/${mkinitcpio_d_path_1}"
  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/var/lib/initramfs-tools/${kernel_name_1}"
  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/lib/modules/${kernel_name_1}"
  cmd_sequence["$((index++))"]="sudo sed -i '/${kernel_name_1}/d' '${INSTALLED_KERNELS_PATH}'"
  cmd_sequence["$((index++))"]="Removing: ${kernel_name_2}"

  boot_files=$(find "${TARGET_PATH}/boot/" -name "*${kernel_name_2}*" | sort)
  # shellcheck disable=SC2068
  for file in ${boot_files[@]}; do
    cmd_sequence["$((index++))"]="Removing: ${file}"
    cmd_sequence["$((index++))"]="sudo --preserve-env rm ${file}"
  done

  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/${mkinitcpio_d_path_2}"
  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/var/lib/initramfs-tools/${kernel_name_2}"
  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/lib/modules/${kernel_name_2}"
  cmd_sequence["$((index++))"]="sudo sed -i '/${kernel_name_2}/d' '$INSTALLED_KERNELS_PATH'"
  cmd_sequence["$((index++))"]='run_bootloader_update_mock'

  # Check
  output=$(kernel_uninstall 0 'local' '5.*' 'TEST_MODE' '' "$SHUNIT_TMPDIR")
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
  output=$(kernel_uninstall 0 'local' 'regex:5\.5.*,regex:5\.6.*' 'TEST_MODE' '' "$SHUNIT_TMPDIR")
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
  output=$(kernel_uninstall 0 'local' 'regex:5\.5.*,regex:5\.6.*' 'TEST_MODE' '' "$SHUNIT_TMPDIR")
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
  output=$(kernel_uninstall 0 'local' 'regex:5\.5.*,5.6.0-rc2-AMDGPU+' 'TEST_MODE' '' "$SHUNIT_TMPDIR")
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_uninstall_unmanaged()
{
  local target='5.5.0-rc2-NOTMANAGED'
  local modules_lib_path="${TARGET_PATH}/lib/modules/${target}"
  local initramfs_tools_var_path="${TARGET_PATH}/var/lib/initramfs-tools/${target}"
  local mkinitcpio_d_path="${TARGET_PATH}/etc/mkinitcpio.d/${target}.preset"
  local output

  # Notice that we are only testing the force feature, we did not create fake
  # files, as a result we can't find files.
  local -a cmd_sequence=(
    "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
    "sudo touch '${INSTALLED_KERNELS_PATH}'"
    "${target} not managed by kw. Use --force/-f to uninstall anyway."
  )

  mkdir --parents "${TARGET_PATH}/boot"
  printf '%s\n' "menuentry 'Arch Linux, with Linux 5.5.0-rc2-NOTMANAGED'" >> "${TARGET_PATH}/boot/grub/grub.cfg"
  touch "${TARGET_PATH}/boot/vmlinuz-5.5.0-rc2-NOTMANAGED"
  output=$(kernel_uninstall 0 'local' '5.5.0-rc2-NOTMANAGED' 'TEST_MODE' '' "$TARGET_PATH")
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  rm "${TARGET_PATH}/boot/vmlinuz-5.5.0-rc2-NOTMANAGED"
}

function test_kernel_force_uninstall_unmanaged()
{
  local target='5.5.0-rc2-NOTMANAGED'
  local grub_cfg_path="${TARGET_PATH}/boot/grub/grub.cfg"
  local boot_path="${TARGET_PATH}/boot/vmlinuz-${target}"
  local modules_lib_path="${TARGET_PATH}/lib/modules/${target}"
  local initramfs_tools_var_path="${TARGET_PATH}/var/lib/initramfs-tools/${target}"
  local mkinitcpio_d_path="${TARGET_PATH}/etc/mkinitcpio.d/${target}.preset"
  local output

  # Notice that we are only testing the force feature, we did not create fake
  # files, as a result we can't find files.
  local -a cmd_sequence=(
    "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
    "sudo touch '${INSTALLED_KERNELS_PATH}'"
    "Removing: ${target}"
    "Removing: ${boot_path}"
    "sudo --preserve-env rm ${boot_path}"
    "Removing: ${mkinitcpio_d_path}"
    "sudo --preserve-env rm ${mkinitcpio_d_path}"
    "Removing: ${initramfs_tools_var_path}"
    "sudo --preserve-env rm ${initramfs_tools_var_path}"
    "Removing: ${modules_lib_path}"
    "sudo --preserve-env rm --recursive --force ${modules_lib_path}"
    "sudo sed -i '/${target}/d' '${INSTALLED_KERNELS_PATH}'"
    'run_bootloader_update_mock'
  )

  mkdir --parents "${TARGET_PATH}/boot"
  mkdir --parents "${TARGET_PATH}/lib/modules/"
  mkdir --parents "${TARGET_PATH}/var/lib/initramfs-tools"
  mkdir --parents "${TARGET_PATH}/etc/mkinitcpio.d"

  tmp_grub_cfg="${TARGET_PATH}/tmp/grub.cfg"
  cp "$grub_cfg_path" "$tmp_grub_cfg"
  printf '%s' "menuentry 'Arch Linux, with Linux 5.5.0-rc2-NOTMANAGED'" >> "$grub_cfg_path"
  touch "$boot_path"
  touch "$mkinitcpio_d_path"
  touch "$initramfs_tools_var_path"
  mkdir --parents "$modules_lib_path"

  output=$(kernel_uninstall 0 'local' '5.5.0-rc2-NOTMANAGED' 'TEST_MODE' 1 "$TARGET_PATH")
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cp "$tmp_grub_cfg" "$grub_cfg_path"
  rm "$boot_path"
  rm "$mkinitcpio_d_path"
  rm "$initramfs_tools_var_path"
  rm --recursive --force "$modules_lib_path"
}

function test_remove_managed_kernel_local()
{
  local target='xpto'
  local prefix="./test"
  local kernel_name='5.5.0-rc2-VKMS+'
  local kernel_boot_img_path="/boot/vmlinuz-${target}"
  local initrd_boot_path="/boot/initrd.img-${target}"
  local modules_lib_path="/lib/modules/${target}"
  local initramfs_tools_var_path="/var/lib/initramfs-tools/${target}"
  local initramfs_boot_img_path="/boot/initramfs-${kernel_name}.img"
  local initramfs_fallback_boot_img_path="/boot/initramfs-${kernel_name}-fallback.img"
  local mkinitcpio_d_path="etc/mkinitcpio.d/${kernel_name}.preset"
  local output
  local boot_files
  local index

  # Adding mock file
  mkdir --parents "${TARGET_PATH}/boot"
  touch "${TARGET_PATH}/boot/vmlinuz-${kernel_name}"
  touch "${TARGET_PATH}/boot/initrd.img-${kernel_name}"
  touch "${TARGET_PATH}/boot/initramfs-${kernel_name}.img"
  touch "${TARGET_PATH}/boot/initramfs-${kernel_name}-fallback.img"
  touch "${TARGET_PATH}/boot/config-${kernel_name}"

  # Composing command sequence list
  local -a cmd_sequence=(
    "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
    "sudo touch '${INSTALLED_KERNELS_PATH}'"
    "Removing: ${kernel_name}"
  )

  index=${#cmd_sequence[@]}

  local -a cmd_last_part=(
    "Can't find ${TARGET_PATH}//${mkinitcpio_d_path}"
    "Can't find ${TARGET_PATH}//var/lib/initramfs-tools/${kernel_name}"
    "Can't find ${TARGET_PATH}//lib/modules/${kernel_name}"
    "sudo sed -i '/${kernel_name}/d' '${INSTALLED_KERNELS_PATH}'"
    'run_bootloader_update_mock'
  )

  boot_files=$(find "${TARGET_PATH}//boot/" -name "*${kernel_name}*" | sort)

  # shellcheck disable=SC2068
  for file in ${boot_files[@]}; do
    cmd_sequence["$index"]="Removing: ${file}"
    ((index++))
    cmd_sequence["$index"]="sudo --preserve-env rm ${file}"
    ((index++))
  done

  for cmd in "${cmd_last_part[@]}"; do
    cmd_sequence["$index"]="$cmd"
    ((index++))
  done

  # Check
  output=$(kernel_uninstall 0 'local' '5.5.0-rc2-VKMS+' 'TEST_MODE' 1 "${SHUNIT_TMPDIR}/")
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
}

function test_do_uninstall_invalid_path_cmd_sequence()
{
  local kernel_name='xpto'
  local prefix="${TARGET_PATH}"
  local modules_lib_path="${prefix}/lib/modules/${kernel_name}"
  local initramfs_tools_var_path="${prefix}/var/lib/initramfs-tools/${kernel_name}"
  local mkinitcpio_d_path="${prefix}/etc/mkinitcpio.d/${kernel_name}.preset"
  local output

  declare -a cmd_sequence=(
    "Can't find ${mkinitcpio_d_path}"
    "Can't find ${initramfs_tools_var_path}"
    "Can't find ${modules_lib_path}"
  )

  output=$(do_uninstall 'remote' "$kernel_name" "$prefix" 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
}

function test_do_uninstall_valid_path_cmd_sequence()
{
  local kernel_name='xpto'
  local prefix="${TARGET_PATH}"
  local modules_lib_path="${prefix}/lib/modules/${kernel_name}"
  local initramfs_tools_var_path="${prefix}/var/lib/initramfs-tools/${kernel_name}"
  local mkinitcpio_d_path="${prefix}/etc/mkinitcpio.d/${kernel_name}.preset"
  local output
  local boot_files
  local index=0

  # TEST 2: Valid paths
  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  mkdir --parents "$prefix"
  mk_fake_remote_system "$prefix" "$kernel_name"

  # Composing command
  boot_files=$(find "${TARGET_PATH}/boot/" -name "*${kernel_name}*" | sort)
  # shellcheck disable=SC2068
  for file in ${boot_files[@]}; do
    cmd_sequence["$index"]="Removing: $file"
    ((index++))
    cmd_sequence["$index"]="rm $file"
    ((index++))
  done

  declare -a cmd_sequence_last_part=(
    "Removing: ${mkinitcpio_d_path}"
    "rm ${mkinitcpio_d_path}"
    "Removing: ${initramfs_tools_var_path}"
    "rm ${initramfs_tools_var_path}"
    "Removing: ${modules_lib_path}"
    "rm --recursive --force ${modules_lib_path}"
  )

  for cmd in "${cmd_sequence_last_part[@]}"; do
    cmd_sequence["$index"]="$cmd"
    ((index++))
  done

  output=$(do_uninstall 'remote' "$kernel_name" "$prefix" 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_do_uninstall_partial_cmd_sequence()
{
  local kernel_name='xpto'
  local prefix="$TARGET_PATH"
  local modules_lib_path="${prefix}/lib/modules/${kernel_name}"
  local initramfs_tools_var_path="${prefix}/var/lib/initramfs-tools/${kernel_name}"
  local mkinitcpio_d_path="${prefix}/etc/mkinitcpio.d/${kernel_name}.preset"
  local output
  local index=0
  local boot_files

  mkdir --parents "$prefix"
  mk_fake_remote_system "$prefix" "$kernel_name"

  rm --recursive --force "$modules_lib_path"

  # Composing command
  boot_files=$(find "${TARGET_PATH}/boot/" -name "*${kernel_name}*" | sort)
  # shellcheck disable=SC2068
  for file in ${boot_files[@]}; do
    cmd_sequence["$index"]="Removing: $file"
    ((index++))
    cmd_sequence["$index"]="rm $file"
    ((index++))
  done

  declare -a cmd_sequence_last_part=(
    "Removing: ${mkinitcpio_d_path}"
    "rm ${mkinitcpio_d_path}"
    "Removing: ${initramfs_tools_var_path}"
    "rm ${initramfs_tools_var_path}"
    "Can't find ${modules_lib_path}"
  )

  for cmd in "${cmd_sequence_last_part[@]}"; do
    cmd_sequence["$index"]="$cmd"
    ((index++))
  done

  output=$(do_uninstall 'remote' "$kernel_name" "$prefix" 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_install_modules()
{
  local module_target='5.9.0-rc5-NEW-VRR-TRACK+.tar'
  local cmd
  local output
  local lib_modules_path_bkp="$LIB_MODULES_PATH"

  output=$(install_modules "$module_target" 'TEST_MODE')
  assert_equals_helper 'We did not find required files' "$LINENO" 2 "$?"

  cd "$test_tmp_file" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Test preparation
  mk_fake_tar_file_to_deploy "$PWD"
  LIB_MODULES_PATH="${KW_DEPLOY_TMP_FILE}${LIB_MODULES_PATH}"
  mkdir --parents "$LIB_MODULES_PATH"

  install_modules 'remote'

  assertTrue "(${LINENO}): Expected kw_pkg" '[[ -f "${LIB_MODULES_PATH}/something_1" ]]'
  assertTrue "(${LINENO}): Expected kw_pkg" '[[ -f "${LIB_MODULES_PATH}/something_2" ]]'

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  LIB_MODULES_PATH="$lib_modules_path_bkp"
}

function test_install_kernel_remote()
{
  local name='test'
  local kernel_image_name='bzImage'
  local reboot='1'
  local architecture='x86_64'
  local target='remote'
  local flag='TEST_MODE'
  local path_prefix=''
  local output

  output=$(install_kernel 'debian' "$reboot" "$target" '' 'TEST_MODE')
  ret="$?"
  assert_equals_helper 'Test invalid name' "$LINENO" 2 "$ret"

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "rm --recursive --force ${KW_DEPLOY_TMP_FILE}/kw_pkg"
    "tar --touch --auto-compress --extract --file='${KW_DEPLOY_TMP_FILE}/${name}.kw.tar' --directory='${SHUNIT_TMPDIR}/tmp/kw' --no-same-owner"
    "rsync --archive ${SHUNIT_TMPDIR}/tmp/kw/kw_pkg/modules/lib/modules/* /lib/modules"
    "cp ${PWD}/boot/vmlinuz-${name} ${PWD}/boot/vmlinuz-${name}.old"
    "cp ${SHUNIT_TMPDIR}/tmp/kw/kw_pkg/config-test /boot/"
    "cp ${SHUNIT_TMPDIR}/tmp/kw/kw_pkg/bzImage /boot/"
    'generate_debian_temporary_root_file_system TEST_MODE test remote GRUB'
    'update-grub'
    "grep --fixed-strings --line-regexp --quiet ${name} ${INSTALLED_KERNELS_PATH}"
    'reboot'
  )

  # Check remote kernel installation with dtb
  declare -a cmd_sequence2=(
    "rm --recursive --force ${KW_DEPLOY_TMP_FILE}/kw_pkg"
    "tar --touch --auto-compress --extract --file='${KW_DEPLOY_TMP_FILE}/${name}.kw.tar' --directory='${SHUNIT_TMPDIR}/tmp/kw' --no-same-owner"
    "rsync --archive ${SHUNIT_TMPDIR}/tmp/kw/kw_pkg/modules/lib/modules/* /lib/modules"
    "cp ${SHUNIT_TMPDIR}/tmp/kw/kw_pkg/config-test /boot/"
    "cp ${SHUNIT_TMPDIR}/tmp/kw/kw_pkg/bzImage /boot/"
    'generate_debian_temporary_root_file_system TEST_MODE test remote GRUB'
    'update-grub'
    "grep --fixed-strings --line-regexp --quiet ${name} ${INSTALLED_KERNELS_PATH}"
    'reboot'
  )

  # Test preparation
  mk_fake_tar_file_to_deploy "$PWD" "$KW_DEPLOY_TMP_FILE" "$name"
  mkdir --parents "${KW_DEPLOY_TMP_FILE}/kw_pkg"
  touch "${KW_DEPLOY_TMP_FILE}/kw_pkg/kw.pkg.info"
  {
    printf 'kernel_name=%s\n' "$name"
    printf 'kernel_binary_image_file=%s\n' "$kernel_image_name"
    printf 'architecture=%s\n' "$architecture"
    printf 'previous_kernel_backup=yes\n'
  } > "${KW_DEPLOY_TMP_FILE}/kw_pkg/kw.pkg.info"
  touch "${PWD}/boot/vmlinuz-${name}"

  output=$(install_kernel 'debian' "$reboot" "$target" '' 'TEST_MODE')

  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  # Now add a .dtb file and remove vmlinuz
  rm "${PWD}/boot/vmlinuz-${name}"

  output=$(install_kernel 'debian' "$reboot" "$target" '' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'cmd_sequence2' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
}

function test_install_kernel_local()
{
  local name='test'
  local kernel_image_name='bzImage'
  local reboot='1'
  local architecture='x86_64'
  local target='local'
  local flag='TEST_MODE'
  local sudo_cmd='sudo --preserve-env'
  local path_prefix=''
  local output

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Test preparation
  mk_fake_tar_file_to_deploy "$PWD" "$KW_DEPLOY_TMP_FILE"
  mkdir --parents "${KW_DEPLOY_TMP_FILE}/kw_pkg"
  touch "${KW_DEPLOY_TMP_FILE}/kw_pkg/kw.pkg.info"
  {
    printf 'kernel_name=%s\n' "$name"
    printf 'kernel_binary_image_file=%s\n' "$kernel_image_name"
    printf 'architecture=%s\n' "$architecture"
  } > "${KW_DEPLOY_TMP_FILE}/kw_pkg/kw.pkg.info"

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "rm --recursive --force ${KW_DEPLOY_TMP_FILE}/kw_pkg"
    "tar --touch --auto-compress --extract --file='${KW_DEPLOY_TMP_FILE}/${name}.kw.tar' --directory='${SHUNIT_TMPDIR}/tmp/kw' --no-same-owner"
    "sudo --preserve-env rsync --archive ${SHUNIT_TMPDIR}/tmp/kw/kw_pkg/modules/lib/modules/* /lib/modules"
    "sudo --preserve-env cp ${KW_DEPLOY_TMP_FILE}/kw_pkg/config-test /boot/"
    "sudo --preserve-env cp ${KW_DEPLOY_TMP_FILE}/kw_pkg/${kernel_image_name} /boot/"
    'generate_debian_temporary_root_file_system TEST_MODE test local GRUB'
    'sudo --preserve-env update-grub'
    "sudo --preserve-env grep --fixed-strings --line-regexp --quiet ${name} ${INSTALLED_KERNELS_PATH}"
    'sudo --preserve-env reboot'
  )

  output=$(install_kernel 'debian' "$reboot" "$target" '' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
}

function distro_pre_setup()
{
  :
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

  expected_cmd="${package_manager_cmd} ${required_packages[*]}"

  assert_equals_helper 'Install packages' "$LINENO" "$expected_cmd" "$output"
}

function test_distro_deploy_setup_local()
{
  local output
  local expected_cmd

  package_manager_cmd='yes | some_package_manager'
  required_packages=(
    'abc'
    'def'
    'xpto'
  )

  output=$(distro_deploy_setup 'TEST_MODE' 2)

  expected_cmd="sudo --preserve-env ${package_manager_cmd} ${required_packages[*]}"

  assert_equals_helper 'Install packages' "$LINENO" "$expected_cmd" "$output"
}

function test_detect_filesystem_type()
{
  local output

  alias findmnt='findmnt_only_filesystem_mock'

  output=$(detect_filesystem_type '')
  assert_equals_helper 'We expected btrfs' "$LINENO" 'btrfs' "$output"
}

function test_is_filesystem_writable()
{
  local output
  local expected_cmd

  output=$(is_filesystem_writable 'ext4' 'TEST_MODE')
  assert_equals_helper 'Expected nothing' "$LINENO" 0 "$?"

  output=$(is_filesystem_writable 'xpto-lala' 'TEST_MODE')
  assert_equals_helper 'Expected EOPNOTSUPP error' "$LINENO" 95 "$?"

  output=$(is_filesystem_writable 'btrfs' 'TEST_MODE')
  expected_cmd='btrfs property get / ro | grep "ro=false" --silent'
  assert_equals_helper 'Expected btrfs property get command' "$LINENO" "$expected_cmd" "$output"

  AB_ROOTFS_PARTITION="${PWD}/kw"
  output=$(is_filesystem_writable 'ext4' 'TEST_MODE')
  expected_cmd="tune2fs -l '$AB_ROOTFS_PARTITION' | grep --quiet '^Filesystem features: .*read-only.*$'"
  assert_equals_helper 'Expected tune2fs command' "$LINENO" "$expected_cmd" "$output"
}

function test_make_root_partition_writable()
{
  local output
  local expected_sequence

  output="$(
    function is_filesystem_writable()
    {
      return 0
    }
    make_root_partition_writable 'TEST_MODE'
  )"
  assert_equals_helper 'It is writable, do nothing' "$LINENO" 0 "$?"

  # Check ext4
  AB_ROOTFS_PARTITION='/xpto/la'
  output="$(
    function is_filesystem_writable()
    {
      return 1
    }
    function detect_filesystem_type()
    {
      printf 'ext4'
    }
    make_root_partition_writable 'TEST_MODE'
  )"
  expected_sequence=(
    "tune2fs -O ^read-only ${AB_ROOTFS_PARTITION}"
    'mount --options remount,rw /'
  )
  compare_command_sequence 'Wrong sequence' "$LINENO" 'expected_sequence' "$output"

  # Check btrfs
  AB_ROOTFS_PARTITION='/xpto/la'
  output="$(
    function is_filesystem_writable()
    {
      return 1
    }
    function detect_filesystem_type()
    {
      printf 'btrfs'
    }
    make_root_partition_writable 'TEST_MODE'
  )"
  expected_sequence=(
    'mount --options remount,rw /'
    'btrfs property set / ro false'
  )
  compare_command_sequence 'Wrong sequence' "$LINENO" 'expected_sequence' "$output"
}

function test_uncompress_kw_package()
{
  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Test preparation
  mk_fake_tar_file_to_deploy "$PWD" "$KW_DEPLOY_TMP_FILE"

  uncompress_kw_package
  assertTrue "(${LINENO}): Expected kw_pkg" '[[ -d "${KW_DEPLOY_TMP_FILE}/kw_pkg" ]]'

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
}

function test_uncompress_kw_package_check_invalid_path()
{
  uncompress_kw_package '/somethig/xpto/abc/kw.pkg.tar'
  assert_equals_helper 'Invalid path' "(${LINENO})" 2 "$?"
}

function test_parse_kw_package_metadata()
{
  # Prepare fake kw.pkg.info
  mkdir --parents "${KW_DEPLOY_TMP_FILE}/kw_pkg"
  touch "${KW_DEPLOY_TMP_FILE}/kw_pkg/kw.pkg.info"
  printf 'kernel_name=test\n' > "${KW_DEPLOY_TMP_FILE}/kw_pkg/kw.pkg.info"
  printf 'kernel_binary_image_file=vmlinuz-test\n' >> "${KW_DEPLOY_TMP_FILE}/kw_pkg/kw.pkg.info"
  printf 'architecture=x86_64\n' >> "${KW_DEPLOY_TMP_FILE}/kw_pkg/kw.pkg.info"

  parse_kw_package_metadata ''
  name=${kw_package_metadata['kernel_name']}
  arch=${kw_package_metadata['architecture']}
  kernel_image_name=${kw_package_metadata['kernel_binary_image_file']}

  assert_equals_helper 'Wrong kernel name' "(${LINENO})" 'test' "${kw_package_metadata['kernel_name']}"
  assert_equals_helper 'Wrong architecture' "(${LINENO})" 'x86_64' "${kw_package_metadata['architecture']}"
  assert_equals_helper 'Wrong binary image name' "(${LINENO})" 'vmlinuz-test' "${kw_package_metadata['kernel_binary_image_file']}"
}

function test_parse_kw_package_metadata_invalid_path()
{
  parse_kw_package_metadata '/an/invalid/folder'
  assert_equals_helper 'Expected an error with invalid path' "(${LINENO})" 22 "$?"
}

function test_parse_kw_package_metadata_no_pkg_info()
{
  parse_kw_package_metadata ''
  assert_equals_helper 'Expected an error due to the lack of info file' "(${LINENO})" 22 "$?"
}

invoke_shunit
