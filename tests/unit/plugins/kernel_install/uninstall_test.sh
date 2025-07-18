# We load utils in the oneTimeSetUp() to ensure we can replace some kw functions
include './tests/unit/utils.sh'
include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/bootloader.sh'
include './src/plugins/kernel_install/uninstall.sh'
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

  # Mock functions
  shopt -s expand_aliases
  alias findmnt='findmnt_mock'
  alias total_of_installed_kernels='total_of_installed_kernels_mock'

  REMOTE_KW_DEPLOY="${PWD}/tests/unit/samples"
  INSTALLED_KERNELS_PATH="${REMOTE_KW_DEPLOY}/INSTALLED_KERNELS"
}

function setUp()
{
  # Setup a fake path to make easier to mock some scenarios
  TARGET_PATH="$SHUNIT_TMPDIR"

  mk_fake_boot "$TARGET_PATH"

  # Creating fake installed kernels
  touch "$INSTALLED_KERNELS_PATH"
  printf '5.5.0-rc2-VKMS+' >> "$INSTALLED_KERNELS_PATH"
  printf '\n%s' '5.6.0-rc2-AMDGPU+' >> "$INSTALLED_KERNELS_PATH"

  # Create fake systemd-boot file
  CURRENT_SHA=$(mk_fake_boot_efi "$TARGET_PATH")

  # Replace KW_DEPLOY_TMP_FILE
  test_tmp_file="${TARGET_PATH}/tmp/kw"
  REMOTE_KW_DEPLOY="${TARGET_PATH}/opt/kw"
  KW_DEPLOY_TMP_FILE="$test_tmp_file"
  mkdir --parents "$test_tmp_file"

  # Mock variables
  KW_PLUGINS_DIR="${PWD}/src/plugins"
  REMOTE_KW_DEPLOY="${KW_PLUGINS_DIR}/kernel_install"
}

function tearDown()
{
  rm -f "$INSTALLED_KERNELS_PATH"
  # shellcheck disable=SC2115
  if [[ -d ${TARGET_PATH} ]]; then
    rm --recursive --force "${TARGET_PATH}"
  fi
}

function findmnt_mock()
{
  printf '%s\n' 'TARGET SOURCE         FSTYPE OPTIONS'
  printf '%s\n' '/home  /dev/lala ext4   rw,relatime'
}

function test_is_in_array()
{
  local -a array=(1 2 3 4 5)

  is_in_array 0 'array'
  assert_equals_helper 'Should return 1 (not present)' "$LINENO" 1 "$?"

  is_in_array 4 'array'
  assert_equals_helper 'Should return 0 (present)' "$LINENO" 0 "$?"
}

function test_process_installed_kernels_managed_kernels()
{
  local -a processed_installed_kernels
  local original_list_installed_kernels_definition

  # Backup list_installed_kernels function
  original_list_installed_kernels_definition=$(declare -f list_installed_kernels)

  # shellcheck disable=SC2317
  function list_installed_kernels()
  {
    printf 'kernel1,kernel2'
  }

  process_installed_kernels '' '' 'processed_installed_kernels'

  assert_equals_helper 'Wrong number of elements' "$LINENO" 2 "${#processed_installed_kernels[@]}"
  assert_equals_helper 'Wrong element 0' "$LINENO" 'kernel1' "${processed_installed_kernels[0]}"
  assert_equals_helper 'Wrong element 1' "$LINENO" 'kernel2' "${processed_installed_kernels[1]}"

  # Restore list_installed_kernels function
  eval "$original_list_installed_kernels_definition"
}

function test_process_installed_kernels_unmanaged_kernels()
{
  local -a processed_installed_kernels
  local original_list_installed_kernels_definition

  # Backup list_installed_kernels function
  original_list_installed_kernels_definition=$(declare -f list_installed_kernels)

  # shellcheck disable=SC2317
  function list_installed_kernels()
  {
    printf 'kernel1,kernel2,notmanaged'
  }

  process_installed_kernels 1 '' 'processed_installed_kernels'
  assert_equals_helper 'Wrong number of elements' "$LINENO" 3 "${#processed_installed_kernels[@]}"
  assert_equals_helper 'Wrong element 0' "$LINENO" 'kernel1' "${processed_installed_kernels[0]}"
  assert_equals_helper 'Wrong element 1' "$LINENO" 'kernel2' "${processed_installed_kernels[1]}"
  assert_equals_helper 'Wrong element 2' "$LINENO" 'notmanaged' "${processed_installed_kernels[2]}"

  # Restore list_installed_kernels function
  eval "$original_list_installed_kernels_definition"
}

function test_kernel_uninstall_regex_one_kernel()
{
  local kernel_name='5.5.0-rc2-VKMS+'
  local mkinitcpio_d_path_1="etc/mkinitcpio.d/${kernel_name}.preset"
  local grub_cfg_path="${TARGET_PATH}/boot/grub/grub.cfg"
  local boot_files
  local output
  local index

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Composing expected command sequence
  local -a cmd_sequence=(
    "mkdir --parents ${REMOTE_KW_DEPLOY}"
    "touch '${INSTALLED_KERNELS_PATH}'"
    "Removing: ${kernel_name}"
  )

  index=${#cmd_sequence[@]}

  boot_files=$(find "${TARGET_PATH}/boot/" -name "*${kernel_name}*" | sort --dictionary)
  # shellcheck disable=SC2068
  for file in ${boot_files[@]}; do
    cmd_sequence["$((index++))"]="Removing: ${file}"
    cmd_sequence["$((index++))"]="rm ${file}"
  done

  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/${mkinitcpio_d_path_1}"
  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/var/lib/initramfs-tools/${kernel_name}"
  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/lib/modules/${kernel_name}"
  cmd_sequence["$((index++))"]="sed --in-place '/${kernel_name}/d' '$INSTALLED_KERNELS_PATH'"
  cmd_sequence["$((index++))"]="update-grub"

  # Check
  output="$(
    function does_the_system_uses_systemd()
    {
      return 95
    }

    function is_filesystem_writable()
    {
      return 0
    }

    function migrate_old_kernel_list()
    {
      return 0
    }

    kernel_uninstall 'debian' 0 'remote' 'regex:.*VKMS.*' 'TEST_MODE' '' "$SHUNIT_TMPDIR"
  )"

  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_uninstall_remove_first_kw_managed_kernel_empty_list()
{
  local kernel_name='5.5.0-rc2-VKMS+'
  local mkinitcpio_d_path_1="etc/mkinitcpio.d/${kernel_name}.preset"
  local grub_cfg_path="${TARGET_PATH}/boot/grub/grub.cfg"
  local boot_files
  local output
  local index

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Composing expected command sequence
  local -a cmd_sequence=(
    "mkdir --parents ${REMOTE_KW_DEPLOY}"
    "touch '${INSTALLED_KERNELS_PATH}'"
    "There is no kernel managed by kw."
  )

  # Check
  output="$(
    function migrate_old_kernel_list()
    {
      return 0
    }

    function is_filesystem_writable()
    {
      return 0
    }

    function process_installed_kernels()
    {
      local all_kernels="$1"
      local prefix="$2"
      local -n _processed_installed_kernels="$3"
    }

    kernel_uninstall 'debian' 0 'remote' "''" 'TEST_MODE' '' "$SHUNIT_TMPDIR"
  )"

  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_uninstall_remove_first_kw_managed_kernel()
{
  local kernel_name='vmlinuz-5.5.0-rc2-VKMS+'
  local mkinitcpio_d_path_1="etc/mkinitcpio.d/${kernel_name}.preset"
  local grub_cfg_path="${TARGET_PATH}/boot/grub/grub.cfg"
  local boot_files
  local output
  local index

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Composing expected command sequence
  local -a cmd_sequence=(
    "mkdir --parents ${REMOTE_KW_DEPLOY}"
    "touch '${INSTALLED_KERNELS_PATH}'"
    "Removing: ${kernel_name}"
  )

  index=${#cmd_sequence[@]}

  boot_files=$(find "${TARGET_PATH}/boot/" -name "*${kernel_name}*" | sort --dictionary)
  # shellcheck disable=SC2068
  for file in ${boot_files[@]}; do
    cmd_sequence["$((index++))"]="Removing: ${file}"
    cmd_sequence["$((index++))"]="rm ${file}"
  done

  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/${mkinitcpio_d_path_1}"
  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/var/lib/initramfs-tools/${kernel_name}"
  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/lib/modules/${kernel_name}"
  cmd_sequence["$((index++))"]="sed --in-place '/${kernel_name}/d' '$INSTALLED_KERNELS_PATH'"
  cmd_sequence["$((index++))"]="update-grub"
  cmd_sequence["$((index++))"]='reboot'

  # Check
  output="$(
    function migrate_old_kernel_list()
    {
      return 0
    }

    function identify_bootloader()
    {
      printf 'GRUB'
    }

    function does_the_system_uses_systemd()
    {
      return 95
    }

    function process_installed_kernels()
    {
      local all_kernels="$1"
      local prefix="$2"
      local -n _processed_installed_kernels="$3"

      _processed_installed_kernels[0]='vmlinuz-5.5.0-rc2-VKMS+'
      _processed_installed_kernels[1]='vmlinuz-5.6.0-rc2-AMDGPU+'
      return 2
    }

    function reboot_machine()
    {
      printf 'reboot\n'
    }

    kernel_uninstall 'debian' 0 'remote' "''" 'TEST_MODE' '' "$SHUNIT_TMPDIR"
  )"

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
    "mkdir --parents ${REMOTE_KW_DEPLOY}"
    "touch '${INSTALLED_KERNELS_PATH}'"
    "generate_debian_temporary_root_file_system TEST_MODE '' local SYSTEMD_BOOT"
  )

  mkdir --parents "${TARGET_PATH}/boot"
  printf '%s\n' "menuentry 'Arch Linux, with Linux 5.5.0-rc2-NOTMANAGED'" >> "${TARGET_PATH}/boot/grub/grub.cfg"
  touch "${TARGET_PATH}/boot/vmlinuz-5.5.0-rc2-NOTMANAGED"
  output="$(
    function migrate_old_kernel_list()
    {
      return 0
    }

    function identify_bootloader()
    {
      printf 'SYSTEMD_BOOT'
    }

    function does_the_system_uses_systemd()
    {
      return 95
    }

    kernel_uninstall 'debian' 0 'remote' '5.5.0-rc2-NOTMANAGED' 'TEST_MODE' '' "$TARGET_PATH"
  )"
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
}

# XXX: This test has many biases to the system and MUST BE rewritten. For now,
# just comment it out.
#function test_kernel_uninstall_regex_two_kernels()
#{
#  local kernel_name_1='5.5.0-rc2-VKMS+'
#  local kernel_name_2='5.6.0-rc2-AMDGPU+'
#  local mkinitcpio_d_path_1="etc/mkinitcpio.d/${kernel_name_1}.preset"
#  local mkinitcpio_d_path_2="etc/mkinitcpio.d/${kernel_name_2}.preset"
#  local output
#  local boot_files
#  local index
#
#  cd "$SHUNIT_TMPDIR" || {
#    fail "(${LINENO}) It was not possible to move to temporary directory"
#    return
#  }
#
#  # Composing expected command sequence
#  local -a cmd_sequence=(
#    "sudo mkdir --parents ${REMOTE_KW_DEPLOY}"
#    "sudo touch '${INSTALLED_KERNELS_PATH}'"
#    "5.5.0-rc2-NOTMANAGED not managed by kw. Use --force/-f to uninstall anyway."
#    "Removing: ${kernel_name_1}"
#  )
#  index=${#cmd_sequence[@]}
#
#  boot_files=$(find "${TARGET_PATH}/boot/" -name "*${kernel_name_1}*" | sort)
#  # shellcheck disable=SC2068
#  for file in ${boot_files[@]}; do
#    cmd_sequence["$((index++))"]="Removing: ${file}"
#    cmd_sequence["$((index++))"]="sudo --preserve-env rm ${file}"
#  done
#
#  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/${mkinitcpio_d_path_1}"
#  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/var/lib/initramfs-tools/${kernel_name_1}" cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/lib/modules/${kernel_name_1}"
#  cmd_sequence["$((index++))"]="sudo sed --in-place '/${kernel_name_1}/d' '${INSTALLED_KERNELS_PATH}'"
#  cmd_sequence["$((index++))"]="Removing: ${kernel_name_2}"
#
#  boot_files=$(find "${TARGET_PATH}/boot/" -name "*${kernel_name_2}*" | sort)
#  # shellcheck disable=SC2068
#  for file in ${boot_files[@]}; do
#    cmd_sequence["$((index++))"]="Removing: ${file}"
#    cmd_sequence["$((index++))"]="sudo --preserve-env rm ${file}"
#  done
#
#  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/${mkinitcpio_d_path_2}"
#  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/var/lib/initramfs-tools/${kernel_name_2}"
#  cmd_sequence["$((index++))"]="Can't find ${TARGET_PATH}/lib/modules/${kernel_name_2}"
#  cmd_sequence["$((index++))"]="sudo sed --in-place '/${kernel_name_2}/d' '$INSTALLED_KERNELS_PATH'"
#  cmd_sequence["$((index++))"]="generate_debian_temporary_root_file_system TEST_MODE '' local GRUB"
#
#  # Check
#  # TODO: This test looks really weird. It looks like we are testing only part
#  # of the array.
#
#  output="$(
#    function identify_bootloader()
#    {
#      printf 'GRUB'
#    }
#
#    function detect_filesystem_type()
#    {
#      printf 'ext4'
#    }
#
#    function does_the_system_uses_systemd()
#    {
#      return 95
#    }
#
#    function is_filesystem_writable()
#    {
#      return 0
#    }
#
#    kernel_uninstall 'debian' 0 'local' 'regex:5.*' 'TEST_MODE' '' "$SHUNIT_TMPDIR"
#  )"
#  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
#
#  output="$(
#    function identify_bootloader()
#    {
#      printf 'GRUB'
#    }
#
#    function detect_filesystem_type()
#    {
#      printf 'ext4'
#    }
#
#    function does_the_system_uses_systemd()
#    {
#      return 95
#    }
#
#    function is_filesystem_writable()
#    {
#      return 0
#    }
#
#    kernel_uninstall 'debian' 0 'local' 'regex:5\.5.*,regex:5\.6.*' 'TEST_MODE' '' "$SHUNIT_TMPDIR"
#  )"
#  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
#
#  output="$(
#    function identify_bootloader()
#    {
#      printf 'GRUB'
#    }
#
#    function detect_filesystem_type()
#    {
#      printf 'ext4'
#    }
#
#    function does_the_system_uses_systemd()
#    {
#      return 95
#    }
#
#    function is_filesystem_writable()
#    {
#      return 0
#    }
#
#    kernel_uninstall 'debian' 0 'local' 'regex:5\.5.*,5.6.0-rc2-AMDGPU+' 'TEST_MODE' '' "$SHUNIT_TMPDIR"
#  )"
#  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"
#
#  cd "$TEST_ROOT_PATH" || {
#    fail "(${LINENO}) It was not possible to move back from temp directory"
#    return
#  }
#}

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
    "mkdir --parents ${REMOTE_KW_DEPLOY}"
    "touch '${INSTALLED_KERNELS_PATH}'"
    "Removing: ${target}"
    "Removing: ${boot_path}"
    "rm ${boot_path}"
    "Removing: ${mkinitcpio_d_path}"
    "rm ${mkinitcpio_d_path}"
    "Removing: ${initramfs_tools_var_path}"
    "rm ${initramfs_tools_var_path}"
    "Removing: ${modules_lib_path}"
    "rm --recursive --force ${modules_lib_path}"
    "sed --in-place '/${target}/d' '${INSTALLED_KERNELS_PATH}'"
    "update-grub"
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

  output="$(
    function identify_bootloader()
    {
      printf 'GRUB'
    }

    function detect_filesystem_type()
    {
      printf 'ext4'
    }

    function does_the_system_uses_systemd()
    {
      return 95
    }

    function is_filesystem_writable()
    {
      return 0
    }

    kernel_uninstall 'debian' 0 'remote' '5.5.0-rc2-NOTMANAGED' 'TEST_MODE' 1 "$TARGET_PATH"
  )"

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
    "mkdir --parents ${REMOTE_KW_DEPLOY}"
    "touch '${INSTALLED_KERNELS_PATH}'"
    "Removing: ${kernel_name}"
  )

  index=${#cmd_sequence[@]}

  local -a cmd_last_part=(
    "Can't find ${TARGET_PATH}//${mkinitcpio_d_path}"
    "Can't find ${TARGET_PATH}//var/lib/initramfs-tools/${kernel_name}"
    "Can't find ${TARGET_PATH}//lib/modules/${kernel_name}"
    "sed --in-place '/${kernel_name}/d' '${INSTALLED_KERNELS_PATH}'"
    'update-grub'
  )

  boot_files=$(find "${TARGET_PATH}//boot/" -name "*${kernel_name}*" | sort)

  # shellcheck disable=SC2068
  for file in ${boot_files[@]}; do
    cmd_sequence["$index"]="Removing: ${file}"
    ((index++))
    cmd_sequence["$index"]="rm ${file}"
    ((index++))
  done

  for cmd in "${cmd_last_part[@]}"; do
    cmd_sequence["$index"]="$cmd"
    ((index++))
  done

  # Check
  output="$(
    function identify_bootloader()
    {
      printf 'GRUB'
    }

    function detect_filesystem_type()
    {
      printf 'ext4'
    }

    function does_the_system_uses_systemd()
    {
      return 95
    }

    function is_filesystem_writable()
    {
      return 0
    }

    kernel_uninstall 'debian' 0 'remote' '5.5.0-rc2-VKMS+' 'TEST_MODE' 1 "${SHUNIT_TMPDIR}/"
  )"
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

  output="$(
    function does_the_system_uses_systemd()
    {
      return 95
    }

    do_uninstall 'remote' "$kernel_name" "$prefix" 'TEST_MODE'
  )"
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

  output="$(
    function does_the_system_uses_systemd()
    {
      return 95
    }

    do_uninstall 'remote' "$kernel_name" "$prefix" 'TEST_MODE'
  )"
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

  output="$(
    function does_the_system_uses_systemd()
    {
      return 95
    }

    do_uninstall 'remote' "$kernel_name" "$prefix" 'TEST_MODE'
  )"
  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

# List of all kernels for validate kernel_to_be_removed_based_on_user_input
declare -a all_installed_kernels_test=(
  '6.12.0-TEST-CONFIG+'
  '6.12.0-TEST-CONFIG-V3+'
  'linux'
)

function test_kernel_to_be_removed_based_on_user_input_single_input()
{
  local input
  local output

  declare -a kw_managed_kernels_test=(
    '6.12.0-TEST-CONFIG-V3+'
  )

  declare -a kernel_to_remove_test

  kernel_to_be_removed_based_on_user_input \
    'kw_managed_kernels_test' \
    'all_installed_kernels_test' \
    'kernel_to_remove_test'
  ret="$?"

  assert_equals_helper 'Kernel name did not match' "$LINENO" '6.12.0-TEST-CONFIG-V3+' "${kernel_to_remove_test[@]}"
}

function test_kernel_to_be_removed_based_on_user_input_single_no_match()
{
  local input
  local output

  declare -a kw_managed_kernels_test=(
    'it_should_be_empty'
  )

  declare -a kernel_to_remove_test

  kernel_to_be_removed_based_on_user_input \
    'kw_managed_kernels_test' \
    'all_installed_kernels_test' \
    'kernel_to_remove_test'
  ret="$?"

  assert_equals_helper 'Kernel name did not match' "$LINENO" '' "${kernel_to_remove_test[@]}"
}

function test_kernel_to_be_removed_based_on_user_input_regex_input()
{
  local input
  local output

  declare -a kw_managed_kernels_test=(
    'regex:.*TEST-CONFIG.*'
  )

  declare -a kernel_to_remove_test

  kernel_to_be_removed_based_on_user_input \
    'kw_managed_kernels_test' \
    'all_installed_kernels_test' \
    'kernel_to_remove_test'
  ret="$?"

  assert_equals_helper 'Kernel name did not match' "$LINENO" '6.12.0-TEST-CONFIG+' "${kernel_to_remove_test[0]}"
  assert_equals_helper 'Kernel name did not match' "$LINENO" '6.12.0-TEST-CONFIG-V3+' "${kernel_to_remove_test[1]}"
  assert_equals_helper 'It should return 2 elements' "$LINENO" 2 "$ret"
}

function test_remove_systemd_kernel_files()
{
  local kernel_name='6.14.0-PLAY-WITH-KW+'
  local expected_cmd="kernel-install remove '${kernel_name}'"
  local output

  output=$(remove_systemd_kernel_files 'remote' "$kernel_name" 'TEST_MODE')
  assert_equals_helper 'Wrong kernel-install remove command' "$LINENO" "$expected_cmd" "$output"
}

invoke_shunit
