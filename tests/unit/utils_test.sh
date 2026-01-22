#!/usr/bin/env bash

include './src/utils.sh'
include './tests/unit/utils.sh'

function setUp()
{
  export KW_STATUS_BASE_PATH="$SHUNIT_TMPDIR"
  export KW_PLUGINS_DIR="${PWD}/src/plugins"
  export KW_SRC_LIB_DIR="${PWD}/src/lib"

  CONFIG_SSH='ssh -p 3333'
  CONFIG_REMOTE='juca@127.0.0.1'
  STD_RSYNC_FLAG="-LrlptD --rsync-path='sudo rsync'"
  UPDATE_KW_REMOTE_MSG='* Sending kw to the remote'

  # Define some basic values for configurations
  parse_configuration "$KW_CONFIG_SAMPLE"
  parse_configuration "$KW_DEPLOY_CONFIG_SAMPLE" deploy_config

  # Usually, we call populate_remote_info to fill out remote info. However, to
  # keep the test more reliable, we manually set this values here
  remote_parameters['REMOTE_IP']=${configurations[ssh_ip]}
  remote_parameters['REMOTE_PORT']=${configurations[ssh_port]}
  remote_parameters['REMOTE_USER']=${configurations[ssh_user]}

  REMOTE_KW_DEPLOY="${deploy_config[remote_kw_deploy]}"
  KW_DEPLOY_TMP_FILE="${deploy_config[kw_deploy_tmp_file]}"
  REMOTE_INTERACE_CMD_PREFIX="bash ${REMOTE_KW_DEPLOY}/kw_remote_proxy_hub.sh --kw-path '${REMOTE_KW_DEPLOY}' --kw-tmp-files '${KW_DEPLOY_TMP_FILE}'"
}

function test_check_setup_status_remote()
{
  local output
  local expected_cmd
  local cmd_check="test -f ${KW_STATUS_BASE_PATH}/kw_status"
  local ssh_prefix='ssh -p 3333 juca@127.0.0.1 sudo'

  output=$(check_setup_status 3 'TEST_MODE')
  expected_cmd="${ssh_prefix} \"${cmd_check}\""
  assert_equals_helper 'Status remote check' "$LINENO" "$expected_cmd" "$output"
}

function test_check_setup_status_local_fail_case()
{
  local original="$PWD"

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  check_setup_status 2
  assert_equals_helper 'Wrong return value' "(${LINENO})" 2 "$?"

  cd "$original" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_check_setup_status_local_success_case()
{
  local output
  local expected_cmd
  local original="$PWD"

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Create kw_status, now the test should pass
  touch "${KW_STATUS_BASE_PATH}/kw_status"
  output=$(check_setup_status 2)
  assert_equals_helper 'Wrong return value' "(${LINENO})" 0 "$?"

  cd "$original" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_prepare_remote_dir_expected_flow_for_remote()
{
  local scripts_path="${KW_PLUGINS_DIR}/kernel_install"
  local rsync_quiet="rsync  -e '${CONFIG_SSH}'"
  local lib_path="${KW_SRC_LIB_DIR}"
  local arch_sync_files_cmd
  local sync_plugins_files
  local sync_lib_files
  local output

  sync_plugins_files="${rsync_quiet} ${scripts_path}/* ${CONFIG_REMOTE}:${REMOTE_KW_DEPLOY} ${STD_RSYNC_FLAG} --archive"
  sync_lib_files="${rsync_quiet} ${lib_path} ${CONFIG_REMOTE}:${REMOTE_KW_DEPLOY} ${STD_RSYNC_FLAG} --archive"

  # Test 1: Normal remote prepare
  declare -a expected_cmd=(
    "$sync_plugins_files"
    "$sync_lib_files"
    "${CONFIG_SSH} ${CONFIG_REMOTE} sudo \"rm --preserve-root=all --recursive --force -- ${KW_DEPLOY_TMP_FILE}\""
    "${CONFIG_SSH} ${CONFIG_REMOTE} sudo \"mkdir --parents ${KW_DEPLOY_TMP_FILE}\""
  )

  output=$(prepare_remote_dir '' '' '' '' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_prepare_remote_dir_first_deploy_to_remote()
{
  local scripts_path="${KW_PLUGINS_DIR}/kernel_install"
  local rsync_quiet="rsync  -e '${CONFIG_SSH}'"
  local lib_path="${KW_SRC_LIB_DIR}"
  local arch_sync_files_cmd
  local sync_plugins_files
  local sync_lib_files
  local output

  sync_plugins_files="${rsync_quiet} ${scripts_path}/* ${CONFIG_REMOTE}:${REMOTE_KW_DEPLOY} ${STD_RSYNC_FLAG} --archive"
  sync_lib_files="${rsync_quiet} ${lib_path} ${CONFIG_REMOTE}:${REMOTE_KW_DEPLOY} ${STD_RSYNC_FLAG} --archive"

  alias detect_distro='which_distro_mock'
  expected_cmd=()
  output=$(prepare_remote_dir '' '' '' 1 'TEST_MODE')

  declare -a expected_cmd=(
    "$UPDATE_KW_REMOTE_MSG"
    "${CONFIG_SSH} ${CONFIG_REMOTE} sudo \"mkdir --parents ${REMOTE_KW_DEPLOY}/lib\""
    "scp -q ${scripts_path}/* ${CONFIG_REMOTE}:${REMOTE_KW_DEPLOY}"
    "scp -r -q ${lib_path} ${CONFIG_REMOTE}:${REMOTE_KW_DEPLOY}"
    "${CONFIG_SSH} ${CONFIG_REMOTE} sudo \"rm --preserve-root=all --recursive --force -- ${KW_DEPLOY_TMP_FILE}\""
    "${CONFIG_SSH} ${CONFIG_REMOTE} sudo \"mkdir --parents ${KW_DEPLOY_TMP_FILE}\""
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_prepare_remote_dir_unsupported_distro()
{
  local output

  output="$(
    function which_distro()
    {
      printf '%s\n' 'none'
    }
    prepare_remote_dir '' '' '' '' 'TEST_MODE'
  )"
  assert_equals_helper 'Wrong return value' "(${LINENO})" 95 "$?"
}

function test_prepare_local_dir()
{
  local output

  declare -a expected_out=(
    "rm --preserve-root=all --recursive --force ${KW_DEPLOY_TMP_FILE}"
    "mkdir --parents ${KW_DEPLOY_TMP_FILE}"
    "sudo -E mkdir --parents ${REMOTE_KW_DEPLOY}"
  )

  output=$(prepare_local_dir 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_out' "$output"
}

function test_update_status_log_remote_target()
{
  local ssh_prefix='ssh -p 3333 juca@127.0.0.1 sudo'
  local output
  local cmd

  cmd="\"printf '%s;%s\n' '3' 'TEST_MODE' >> ${KW_STATUS_BASE_PATH}/kw_status\""
  output=$(update_status_log 3 'TEST_MODE')

  assert_equals_helper 'Status file remote' "$LINENO" "${ssh_prefix} ${cmd}" "$output"
}

function test_update_status_log_local_target()
{
  local output
  local expected_cmd

  expected_cmd="printf '%s;%s\n' '2' 'TEST_MODE' | sudo -E tee --append ${KW_STATUS_BASE_PATH}/kw_status"
  output=$(update_status_log 2 'TEST_MODE')

  assert_equals_helper 'Local deploy command' "$LINENO" "$expected_cmd" "$output"
}

function test_prepare_distro_for_deploy_ext4()
{
  local ssh_prefix='ssh -p 3333 juca@127.0.0.1 sudo'
  local cmd="bash ${REMOTE_KW_DEPLOY}/kw_remote_proxy_hub.sh"
  local output

  alias detect_filesystem_type='detect_filesystem_type_mock_ext4'

  cmd+=" --kw-path '${REMOTE_KW_DEPLOY}' --kw-tmp-files '${KW_DEPLOY_TMP_FILE}'"
  cmd+=" --deploy-setup TEST_MODE"

  declare -a expected_cmd=(
    '-> Basic distro set up'
    '' # Extra space for the \n in the message
    "${ssh_prefix} \"${cmd} 3\""
  )

  # Remote
  output=$(prepare_distro_for_deploy 3 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Local - We need to force a specific distro
  expected_cmd=()

  # Let's change the detect ditro to point to Arch
  output="$(
    function detect_distro()
    {
      printf '%s\n' 'arch'
    }

    prepare_distro_for_deploy 2 'TEST_MODE'
  )"
  expected_cmd=(
    '-> Basic distro set up'
    '' # Extra space for the \n
    'sudo -E mv /etc/skel/.screenrc /tmp'
    'sudo -E pacman-key --init'
    'sudo -E pacman-key --populate'
    'yes | sudo -E pacman -Syu'
    'sudo --preserve-env yes | pacman -Syu rsync screen pv bzip2 lzip lzop zstd xz rng-tools jq inxi'
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function detect_distro_arch_mock()
{
  printf '%s\n' 'arch'
}

function detect_filesystem_type_mock_btrfs()
{
  printf '%s\n' 'btrfs'
}

function btrfs_property_get_root_ro_mock()
{
  printf '%s' 'ro=false'
}

function detect_filesystem_type_mock_ext4()
{
  printf '%s\n' 'ext4'
}

function test_prepare_distro_for_deploy_arch_remote()
{
  local output
  local ssh_prefix='ssh -p 3333 juca@127.0.0.1 sudo'
  local cmd="bash ${REMOTE_KW_DEPLOY}/kw_remote_proxy_hub.sh"

  cmd+=" --kw-path '${REMOTE_KW_DEPLOY}' --kw-tmp-files '${KW_DEPLOY_TMP_FILE}'"
  cmd+=" --deploy-setup TEST_MODE"

  declare -a expected_cmd=(
    '-> Basic distro set up'
    '' # Extra space for the \n in the message
    "${ssh_prefix} \"${cmd} 3\""
  )

  output=$(prepare_distro_for_deploy 3 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

invoke_shunit
