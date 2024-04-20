#!/usr/bin/env bash

include './src/kw_env.sh'
include './tests/unit/utils.sh'

setUp()
{
  export ORIGINAL_PATH="$PWD"
  export TEST_PATH="$SHUNIT_TMPDIR"
  export KW_CACHE_DIR="${SHUNIT_TMPDIR}/.cache"

  mkdir -p "$TEST_PATH"

  # Let's run all test in a well-contained folder
  cd "${TEST_PATH}" || {
    fail "($LINENO): setUp: It was not possible to move into ${TEST_PATH}"
    return 22
  }

  # Create fake .kw folder
  mk_fake_kw_folder "$TEST_PATH"

  # Copy strings
  cp "${ORIGINAL_PATH}/etc/strings/env.txt" "$TEST_PATH"

  # Create a dummy kernel .config file
  cp "$STD_CONFIG_FILE" ./
}

tearDown()
{
  cd "$ORIGINAL_PATH" || {
    fail "($LINENO): tearDown: It was not possible to move into ${ORIGINAL_PATH}"
    return 22
  }

  [[ -d "$TEST_PATH" ]] && rm -rf "$TEST_PATH"
  return 0
}

function test_create_new_env_create_multiple_envs_from_current_configs()
{
  local new_env_name

  options_values['CREATE']='xpto'
  create_new_env
  assertEquals "($LINENO) We should nota have errors" "$?" 0

  options_values['CREATE']='abc'
  create_new_env
  assertEquals "($LINENO) We should nota have errors" "$?" 0

  # Other checks
  # 1. Do we have the env folder?
  new_env_name=$(find ".kw/${ENV_DIR}" -type d -name 'xpto')
  assertEquals "($LINENO) We did not find the new folder name" "$new_env_name" ".kw/${ENV_DIR}/xpto"

  new_env_name=$(find ".kw/${ENV_DIR}" -type d -name 'abc')
  assertEquals "($LINENO) We did not find the new folder name" "$new_env_name" ".kw/${ENV_DIR}/abc"

  # 2. Check for config files
  for config in "${config_file_list[@]}"; do
    assertTrue "${LINENO}: ${config} config not find " '[[ -f .kw/${ENV_DIR}/xpto/${config}.config ]]'
    assertTrue "${LINENO}: ${config} config not find " '[[ -f .kw/${ENV_DIR}/abc/${config}.config ]]'
  done
}

function test_create_new_env_outside_of_a_repo_without_init()
{
  local output

  # Let's remove the default .kw created in the setUp to force an error
  assertTrue "${LINENO}: Something went wrong when we tried to remove .kw folder" 'rm -rf .kw'

  options_values['CREATE']='farofa'
  output=$(create_new_env)
  assertEquals "($LINENO) We should hit a fail condition" "$?" 22
}

function test_create_new_env_missing_config()
{
  mv .kw/remote.config ./
  export KW_ETC_DIR="$TEST_PATH"

  options_values['CREATE']='xlr8'
  create_new_env > /dev/null
  assertTrue "${LINENO}: missing config not created" '[[ -e .kw/${ENV_DIR}/xlr8/remote.config ]]'

  rm ./remote.config
}

function test_create_new_env_check_if_target_env_name_already_exists()
{
  local output

  options_values['CREATE']='tapioca'
  create_new_env

  # Try to create the same env twice
  output=$(create_new_env)
  assertEquals "($LINENO) We should be able to create two env with the same name" "$?" 22
}

function test_show_available_envs()
{
  local output

  options_values['CREATE']='tapioca'
  create_new_env

  options_values['CREATE']='farofa'
  create_new_env

  local expected=(
    'Other kw environments:'
    "* farofa: ${KW_CACHE_DIR}/${ENV_DIR}/farofa"
    "* tapioca: ${KW_CACHE_DIR}/${ENV_DIR}/tapioca"
  )

  output=$(list_env_available_envs)
  compare_command_sequence 'Did not list all envs correctly' "$LINENO" 'expected' "$output"
}

function test_show_available_envs_when_we_dont_kw_folder()
{
  local output

  # Let's remove the default .kw created in the setUp to force an error
  assertTrue "${LINENO}: Something went wrong when we tried to remove .kw folder" 'rm -rf .kw'

  output=$(list_env_available_envs)
  assertEquals "($LINENO) We should hit a fail condition" "$?" 22
}

function test_show_available_envs_when_there_is_no_env()
{
  local output

  local expected=(
    'Kw did not find any environment. You can create a new one with the --create option.'
    'See kw env --help'
  )

  output=$(list_env_available_envs)

  compare_command_sequence 'Should not list anything' "$LINENO" 'expected' "$output"
}

function test_use_target_env()
{
  local output
  local real_path
  local expected_path

  # Create envs
  options_values['CREATE']='tapioca'
  create_new_env

  options_values['CREATE']='farofa'
  create_new_env

  # Switch env
  options_values['USE']='farofa'
  use_target_env

  real_path=$(readlink "${PWD}/.kw/build.config")
  expected_path="${PWD}/.kw/${ENV_DIR}/farofa/build.config"

  assertEquals "($LINENO) It looks like that the env did not switch" "$real_path" "$expected_path"

  # Switch env
  options_values['USE']='tapioca'
  use_target_env

  real_path=$(readlink "${PWD}/.kw/build.config")
  expected_path="${PWD}/.kw/${ENV_DIR}/tapioca/build.config"

  assertEquals "($LINENO) It looks like that the env did not switch" "$real_path" "$expected_path"
}

function test_use_target_env_invalid_env()
{
  local output
  local real_path
  local expected_path

  # Create envs
  options_values['CREATE']='tapioca'
  create_new_env

  options_values['CREATE']='farofa'
  create_new_env

  # Switch env
  options_values['USE']='lala'
  output=$(use_target_env)
  assertEquals "($LINENO) Env does not exists" "$?" 22
}

function test_validate_env_before_switch_invalid_case_with_config()
{
  # In this case we don't care about the user output for the test, for this
  # reason, move to dev/null
  validate_env_before_switch > /dev/null
  assert_equals_helper 'It should not allow switch to a new env due to .config file.' "$LINENO" "$?" 22
}

function test_validate_env_before_switch_invalid_case_with_object_file()
{
  # Remove the .cofig file
  mv '.config' 'config'

  # Create a fake object file
  mkdir -p 'drivers/gpu/drm/'
  touch 'drivers/gpu/drm/drm_atomic.o'

  # In this case we don't care about the user output for the test, for this
  # reason, move to dev/null
  validate_env_before_switch > /dev/null
  assert_equals_helper 'It should not allow switch to a new env due to object files.' "$LINENO" "$?" 22
}

function test_validate_env_before_switch_no_config_and_no_object_files()
{
  # Remove the .cofig file
  mv '.config' 'config'

  validate_env_before_switch > /dev/null
  assert_equals_helper 'It should allow switch to a new env.' "$LINENO" "$?" 0
}

function test_parse_env_options()
{
  local output
  unset options_values
  declare -gA options_values

  # Check list
  parse_env_options --list
  assert_equals_helper 'List envs' \
    "($LINENO)" 1 "${options_values['LIST']}"

  # Check help
  output=$(parse_env_options -h)
  assertEquals "($LINENO)" "$?" 0

  # Check verbose
  output=$(parse_env_options --verbose)
  assertEquals "($LINENO)" "$?" 0

  # Check create
  parse_env_options --create abc
  assert_equals_helper 'Create envs' \
    "($LINENO)" 'abc' "${options_values['CREATE']}"

  output=$(parse_env_options --create 'abc la')
  assertEquals "($LINENO) Invalid name" "$?" 22

  output=$(parse_env_options --create 'Weird_n@m#')
  assertEquals "($LINENO) Invalid name" "$?" 22

  # Check use option
  parse_env_options --use abc
  assert_equals_helper 'Use abc env' \
    "($LINENO)" 'abc' "${options_values['USE']}"

  # Check use option
  parse_env_options --an-invalid-option
  assertEquals "($LINENO) Invalid option" "$?" 22

  parse_env_options --use
  assertEquals "($LINENO) Invalid option" "$?" 22
}

function test_exit_env_checking_files()
{
  local output

  # Creating an env
  options_values['CREATE']='MACHINE_A'
  create_new_env

  # Switch env
  options_values['USE']='MACHINE_A'
  use_target_env

  # Exiting the env
  options_values['EXIT_ENV']=1
  output="$(printf '%s\n' 'y' | exit_env)"

  assertFalse "$LINENO: We didn't expect a symbolic link in (${PWD}/.kw/build.config)" '[[ -L "${PWD}/.kw/build.config" ]]'
}

function test_destroy_env_checking_the_existence_of_a_directory()
{
  local output
  local real_path
  local expected_path

  # Create envs
  options_values['CREATE']='MACHINE_A'
  create_new_env

  options_values['CREATE']='MACHINE_B'
  create_new_env

  options_values['CREATE']='MACHINE_C'
  create_new_env

  options_values['USE']='MACHINE_A'
  use_target_env

  # Destroying the MACHINE_A env
  options_values['DESTROY']='MACHINE_A'
  output="$(printf '%s\n' 'y' | destroy_env)"

  # Destroying the MACHINE_C env
  options_values['DESTROY']='MACHINE_C'
  output="$(printf '%s\n' 'y' | destroy_env)"

  # MACHINE_A
  assertFalse "($LINENO) We didn't expect to find this folder (${PWD}/.kw/envs/MACHINE_A) since the env was destroyed." '[[ -d "${PWD}/.kw/envs/MACHINE_A" ]]'
  assertFalse "($LINENO) We didn't expect to find this folder in .cache (${KW_CACHE_DIR}/envs/MACHINE_A) since the env was destroyed." '[[ -d "${KW_CACHE_DIR}/envs/MACHINE_A" ]]'

  # MACHINE_B
  assertTrue "$LINENO: We expected to find this folder(${PWD}/.kw/envs/MACHINE_B)" '[[ -d "${PWD}/.kw/envs/MACHINE_B" ]]'
  assertTrue "$LINENO: We expected to find this folder(${KW_CACHE_DIR}/envs/MACHINE_B)" '[[ -d "${KW_CACHE_DIR}/envs/MACHINE_B" ]]'

  # MACHINE_C
  assertFalse "($LINENO) We didn't expect to find this folder (${PWD}/.kw/envs/MACHINE_C) since the env was destroyed." '[[ -d "${PWD}/.kw/envs/MACHINE_C" ]]'
  assertFalse "($LINENO) We didn't expect to find this folder in .cache (${KW_CACHE_DIR}/envs/MACHINE_C) since the env was destroyed." '[[ -d "${KW_CACHE_DIR}/envs/MACHINE_C" ]]'
}

function test_create_and_destroy_env()
{
  local output
  options_values['CREATE']='MACHINE_E'
  create_new_env

  # Destroying the MACHINE_E env
  options_values['DESTROY']='MACHINE_E'
  output="$(printf '%s\n' 'y' | destroy_env)"

  # MACHINE_E
  assertFalse "($LINENO) We didn't expect to find this folder (${PWD}/.kw/MACHINE_E) since the env was destroyed." '[[ -d "${PWD}/.kw/MACHINE_E" ]]'
  assertFalse "($LINENO) We didn't expect to find this folder in .cache (${KW_CACHE_DIR}/MACHINE_E) since the env was destroyed." '[[ -d "${KW_CACHE_DIR}/MACHINE_E" ]]'
}

invoke_shunit
