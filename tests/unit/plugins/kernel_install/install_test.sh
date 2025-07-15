#!/usr/bin/env bash

include './tests/unit/utils.sh'
include './src/plugins/kernel_install/install.sh'
include './src/lib/kwlib.sh'
include './src/lib/kwio.sh'

declare -r TEST_ROOT_PATH="$PWD"

function oneTimeSetUp()
{
  # Setup a fake path to make easier to mock some scenarios
  TARGET_PATH="$SHUNIT_TMPDIR"
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

function test_install_modules_force_uncompress_failure_path()
{
  local module_target='5.9.0-rc5-NEW-VRR-TRACK+.tar'
  local lib_modules_path_bkp="$LIB_MODULES_PATH"
  local output

  output="$(
    function uncompress_kw_package()
    {
      return 2
    }

    install_modules "$module_target" 'TEST_MODE'
  )"

  assert_equals_helper 'We did not find required files' "$LINENO" 2 "$?"
}

function test_install_modules()
{
  local module_target='5.9.0-rc5-NEW-VRR-TRACK+.tar'
  local lib_modules_path_bkp="$LIB_MODULES_PATH"
  local output
  local cmd

  cd "$test_tmp_file" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Test preparation
  mk_fake_tar_file_to_deploy "$PWD"

  # Note: LIB_MODULES_PATH is defined in the utils.sh as /lib/modules
  LIB_MODULES_PATH="${KW_DEPLOY_TMP_FILE}${LIB_MODULES_PATH}"
  mkdir --parents "$LIB_MODULES_PATH"

  install_modules 'remote'

  assertTrue "(${LINENO})" '[[ -f "${LIB_MODULES_PATH}/something_1" ]]'
  assertTrue "(${LINENO})" '[[ -f "${LIB_MODULES_PATH}/something_2" ]]'

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Restore original LIB_MODULES_PATH value
  LIB_MODULES_PATH="$lib_modules_path_bkp"
}

function test_install_kernel_remote_force_uncompress_failures()
{
  local target='remote'
  local reboot='1'
  local output=''

  output="$(
    function uncompress_kw_package()
    {
      return 2
    }

    install_kernel 'debian' "$reboot" "$target" '' 'TEST_MODE'
  )"
  ret="$?"
  assert_equals_helper 'Test invalid name' "$LINENO" 2 "$ret"
}

function helper_create_kw_pkg_info_file()
{
  local base_path="$1"
  local name="$2"

  touch "${base_path}/kw_pkg/kw.pkg.info"
  {
    printf 'kernel_name=%s\n' "$name"
    printf 'kernel_binary_image_file=bzImage\n'
    printf 'architecture=x86_64\n'
    printf 'previous_kernel_backup=yes\n'
  } > "${base_path}/kw_pkg/kw.pkg.info"
}

function test_validates_install_kernel_force_failure_due_to_missing_name()
{
  local name='test'
  local path_prefix=''
  local output=''

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Test preparation
  mk_fake_tar_file_to_deploy "$PWD" "$KW_DEPLOY_TMP_FILE" "$name"
  mkdir --parents "${KW_DEPLOY_TMP_FILE}/kw_pkg"

  helper_create_kw_pkg_info_file "$KW_DEPLOY_TMP_FILE" ''
  touch "${PWD}/boot/vmlinuz-${name}"

  output="$(
    function update_bootloader()
    {
      printf '%s\n' 'update_bootloader_mock'
      return 0
    }

    function migrate_old_kernel_list()
    {
      return 0
    }

    function reboot_machine()
    {
      printf '%s\n' 'reboot'
      return 0
    }

    install_kernel 'debian' '1' 'remote' '' 'TEST_MODE'
  )"

  assert_equals_helper 'No kerne name' "$LINENO" 22 "$?"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
}

function test_validates_install_kernel_force_bootloader_failure()
{
  local name='test'
  local path_prefix=''
  local output=''
  local ret

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Test preparation
  mk_fake_tar_file_to_deploy "$PWD" "$KW_DEPLOY_TMP_FILE" "$name"
  mkdir --parents "${KW_DEPLOY_TMP_FILE}/kw_pkg"

  helper_create_kw_pkg_info_file "$KW_DEPLOY_TMP_FILE" 'test'
  touch "${PWD}/boot/vmlinuz-${name}"

  output="$(
    function update_bootloader()
    {
      printf '%s\n' 'update_bootloader_mock'
      return 22
    }

    function migrate_old_kernel_list()
    {
      return 0
    }

    function reboot_machine()
    {
      printf '%s\n' 'reboot'
      return 0
    }

    install_kernel 'debian' '1' 'remote' '' 'TEST_MODE'
  )"
  assert_equals_helper 'No kerne name' "$LINENO" 22 "$?"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
}

function test_validates_install_kernel_to_remote_target()
{
  local name='test'
  local path_prefix=''
  local output=''

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
    'update_bootloader_mock'
    "grep --fixed-strings --line-regexp --quiet ${name} ${INSTALLED_KERNELS_PATH}"
    'reboot'
  )

  # Test preparation
  mk_fake_tar_file_to_deploy "$PWD" "$KW_DEPLOY_TMP_FILE" "$name"
  mkdir --parents "${KW_DEPLOY_TMP_FILE}/kw_pkg"

  helper_create_kw_pkg_info_file "$KW_DEPLOY_TMP_FILE" "$name"
  touch "${PWD}/boot/vmlinuz-${name}"

  output="$(
    function update_bootloader()
    {
      printf '%s\n' 'update_bootloader_mock'
      return 0
    }

    function migrate_old_kernel_list()
    {
      return 0
    }

    function reboot_machine()
    {
      printf '%s\n' 'reboot'
      return 0
    }

    install_kernel 'debian' '1' 'remote' '' 0 'TEST_MODE'
  )"

  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
}

function test_install_kernel_local()
{
  local name='test'
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

  helper_create_kw_pkg_info_file "$KW_DEPLOY_TMP_FILE" "$name"

  # Check standard remote kernel installation
  declare -a cmd_sequence=(
    "rm --recursive --force ${KW_DEPLOY_TMP_FILE}/kw_pkg"
    "tar --touch --auto-compress --extract --file='${KW_DEPLOY_TMP_FILE}/${name}.kw.tar' --directory='${SHUNIT_TMPDIR}/tmp/kw' --no-same-owner"
    "sudo --preserve-env rsync --archive ${SHUNIT_TMPDIR}/tmp/kw/kw_pkg/modules/lib/modules/* /lib/modules"
    "sudo --preserve-env cp ${KW_DEPLOY_TMP_FILE}/kw_pkg/config-test /boot/"
    "sudo --preserve-env cp ${KW_DEPLOY_TMP_FILE}/kw_pkg/bzImage /boot/"
    'update_bootloader_mock'
    "sudo --preserve-env grep --fixed-strings --line-regexp --quiet ${name} ${INSTALLED_KERNELS_PATH}"
    'sudo --preserve-env reboot'
  )

  output="$(
    function update_bootloader()
    {
      printf '%s\n' 'update_bootloader_mock'
      return 0
    }

    function migrate_old_kernel_list()
    {
      return 0
    }

    function reboot_machine()
    {
      printf '%s\n' 'sudo --preserve-env reboot'
      return 0
    }

    install_kernel 'debian' '1' 'local' '' 1 'TEST_MODE'
  )"

  compare_command_sequence '' "$LINENO" 'cmd_sequence' "$output"

  cd "$TEST_ROOT_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
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
