#!/usr/bin/env bash

include './src/plugins/kernel_install/utils.sh'
include './src/plugins/kernel_install/systemd_boot.sh'
include './src/lib/kwio.sh'
include './src/lib/kwlib.sh'
include './src/lib/kw_string.sh'
include './tests/unit/utils.sh'

function setUp()
{
  REMOTE_KW_DEPLOY="${PWD}/tests/unit/samples"
  INSTALLED_KERNELS_PATH="${REMOTE_KW_DEPLOY}/INSTALLED_KERNELS"

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

function test_setup_systemd_reboot_for_new_kernel()
{
  local output
  local expected_output='bootctl set-oneshot CUSTOM-KERNEL+.conf'

  output="$(
    function bootctl()
    {
      return
    }

    function get_bootctl_version()
    {
      printf '259'
    }

    function jq()
    {
      printf 'CUSTOM-KERNEL+.conf\n'
    }

    setup_systemd_reboot_for_new_kernel 'CUSTOM-KERNEL+' '' 'TEST_MODE'
  )"

  assert_equals_helper 'set-oneshot is wrong' "(${LINENO})" "$expected_output" "$output"
}

function test_execute_systemd_kernel_install()
{
  local output
  local expected_cmd
  local kernel_name='6.14.0-PLAY-WITH-KW+'
  local efi_path="${TARGET_PATH}/boot/efi/${CURRENT_SHA}/${kernel_name}/initrd.img-${kernel_name}"

  expected_cmd="kernel-install add '${kernel_name}' '${TARGET_PATH}/boot/vmlinuz-${kernel_name}' '${TARGET_PATH}${efi_path}'"

  output=$(execute_systemd_kernel_install 'TEST_MODE' 'remote' "$kernel_name" "$TARGET_PATH")

  assert_equals_helper 'Kernel-install command is wrong' "(${LINENO})" "$expected_cmd" "$output"
}

function test_execute_systemd_kernel_install_wrong_path()
{
  local output
  local expected_cmd
  local kernel_name='6.14.0-PLAY-WITH-KW+'
  local remove_initrd="${TARGET_PATH}/boot/efi/${CURRENT_SHA}/${kernel_name}/initrd.img-${kernel_name}"

  if [[ ! -f "$remove_initrd" ]]; then
    fail "(${LINENO}) Something is wrong in the test setup"
  fi

  rm "$remove_initrd"

  output=$(execute_systemd_kernel_install 'TEST_MODE' 'remote' "$kernel_name" "$TARGET_PATH")

  assertEquals "(${LINENO})" 2 "$?"
}

function test_execute_popos_workaround_uname_path()
{
  local original="$PWD"
  local fake_kernel_version='7.13.27-amd64-generic'
  local conf_path=''
  local expected_cmd=''
  local output=''

  cd "$TARGET_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Preparing repository
  conf_path="${PWD}/${LOADER_ENTRIES_PATH}/test.conf"
  mkdir --parent "${PWD}/${LOADER_ENTRIES_PATH}"
  cp "${original}/tests/unit/samples/boot/systemd_boot/test.conf" "${conf_path}"

  expected_cmd="kernelstub --kernel-path ${TARGET_PATH}/boot/vmlinuz-${fake_kernel_version} --initrd-path ${TARGET_PATH}/boot/initrd.img-${fake_kernel_version}"
  output="$(
    function uname()
    {
      printf '%s' ${fake_kernel_version}
    }

    function get_esp_base_path()
    {
      printf '%s' ${PWD}
    }

    execute_popos_workaround 'TEST_MODE' 'remote' 'test' ${TARGET_PATH}
  )"

  # Remove warning message from the test
  output=$(printf '%s\n' "$output" | head -1)

  grep --quiet --ignore-case "title ${test}" "$conf_path"
  assertEquals "(${LINENO}): Title did not change" 0 "$?"
  assert_equals_helper 'kernelstub command did not match' "(${LINENO})" "$expected_cmd" "$output"

  cd "$original" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
}

function test_execute_popos_workaround_no_uname_match()
{
  local original="$PWD"
  local fake_kernel_version='7.13.27-amd64-generic'
  local expected_cmd=''
  local conf_path=''
  local output=''

  cd "$TARGET_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Preparing repository
  conf_path="${PWD}/${LOADER_ENTRIES_PATH}/test.conf"
  mkdir --parent "${PWD}/${LOADER_ENTRIES_PATH}"
  cp "${original}/tests/unit/samples/boot/systemd_boot/test.conf" "${conf_path}"

  # Inserting fake generic kernel
  touch "boot/vmlinuz-${fake_kernel_version}"

  expected_cmd="kernelstub --kernel-path ${TARGET_PATH}/boot/vmlinuz-${fake_kernel_version} --initrd-path ${TARGET_PATH}/boot/initrd.img-${fake_kernel_version}"
  output="$(
    function uname()
    {
      printf '%s' '6.12.27-amd64'
    }

    function get_esp_base_path()
    {
      printf '%s' ${PWD}
    }

    execute_popos_workaround 'TEST_MODE' 'remote' 'test' $TARGET_PATH
  )"

  # Remove warning message from the test
  output=$(printf '%s\n' "$output" | head -1)

  grep --quiet --ignore-case "title ${test}" "$conf_path"
  assertEquals "(${LINENO}): Title did not change" 0 "$?"
  assert_equals_helper 'kernelstub command did not match' "(${LINENO})" "$expected_cmd" "$output"

  cd "$original" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
}

function test_execute_popos_workaround_no_uname_match_multiple_generic()
{
  local original="$PWD"
  local fake_kernel_version_v1='7.13.27-amd64-generic'
  local fake_kernel_version_v2='8.15.30-amd64-generic'
  local fake_kernel_version_v3='8.15.31-amd64-generic'
  local fake_kernel_version_v4='5.13.27-amd64-generic'
  local conf_path
  local expected_cmd
  local output

  cd "$TARGET_PATH" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Preparing repository
  conf_path="${PWD}/${LOADER_ENTRIES_PATH}/test.conf"
  mkdir --parent "${PWD}/${LOADER_ENTRIES_PATH}"
  cp "${original}/tests/unit/samples/boot/systemd_boot/test.conf" "${conf_path}"

  # Inserting fake generic kernel
  touch "boot/vmlinuz-${fake_kernel_version_v1}"
  touch "boot/vmlinuz-${fake_kernel_version_v2}"
  touch "boot/vmlinuz-${fake_kernel_version_v3}"
  touch "boot/vmlinuz-${fake_kernel_version_v4}"

  expected_cmd="kernelstub --kernel-path ${TARGET_PATH}/boot/vmlinuz-${fake_kernel_version_v3} --initrd-path ${TARGET_PATH}/boot/initrd.img-${fake_kernel_version_v3}"
  output="$(
    function uname()
    {
      printf '%s' '6.12.27-amd64'
    }

    function get_esp_base_path()
    {
      printf '%s' ${PWD}
    }

    execute_popos_workaround 'TEST_MODE' 'remote' 'test' $TARGET_PATH
  )"

  # Remove warning message from the test
  output=$(printf '%s\n' "$output" | head -1)

  grep --quiet --ignore-case "title ${test}" "$conf_path"
  assertEquals "(${LINENO}): Title did not change" 0 "$?"
  assert_equals_helper 'kernelstub command did not match' "(${LINENO})" "$expected_cmd" "$output"

  cd "$original" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
}

invoke_shunit
