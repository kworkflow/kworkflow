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

invoke_shunit
