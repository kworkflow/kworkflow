#!/usr/bin/env bash

# We load utils in the oneTimeSetUp() to ensure we can replace some kw functions
include './tests/unit/utils.sh'
include './src/plugins/kernel_install/bootloader.sh'
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
  alias identify_bootloader_from_files='identify_bootloader_mock'
  alias findmnt='findmnt_mock'

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

function identify_bootloader_mock()
{
  printf 'GRUB'
}

# Mock funtions for install tests
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

invoke_shunit
