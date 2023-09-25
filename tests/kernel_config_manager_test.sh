#!/bin/bash

include './src/kernel_config_manager.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  # Common values used in suite
  readonly NAME_1='test_save_1'
  readonly NAME_2='test_save_2'
  readonly YES_FORCE=1
  readonly NO_FORCE=0
  readonly CONTENT='The content'
  readonly DESCRIPTION_1='This is the first description'
  readonly DESCRIPTION_2="Hi, I'm the second description"

  # Important values for isolating tests and mocking
  export KW_DATA_DIR="${SHUNIT_TMPDIR}"
  export KW_CACHE_DIR="${SHUNIT_TMPDIR}/cache"
  export dot_configs_dir="${KW_DATA_DIR}/configs"
  export original_dir="$PWD"

  # Loading sample configurations
  parse_configuration "${KW_CONFIG_SAMPLE}"
  parse_configuration "${KW_BUILD_CONFIG_SAMPLE}" build_config

  # Database values
  declare -g KW_DB_DIR
  KW_DB_DIR="$(realpath './database')"
}

function setUp()
{
  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  setupDatabase

  mkdir -p "${dot_configs_dir}"

  touch '.config'
  printf '%s\n' "$CONTENT" > '.config'
}

function tearDown()
{
  if is_safe_path_to_remove "${dot_configs_dir}"; then
    rm -rf "${dot_configs_dir}"
  fi

  teardownDatabase

  options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']=''

  cd "${original_dir}" || {
    fail "($LINENO) It was not possible to back to the kw folder"
    return
  }
}

function setupDatabase()
{
  execute_sql_script "${KW_DB_DIR}/kwdb.sql" > /dev/null 2>&1
}

function teardownDatabase()
{
  is_safe_path_to_remove "${KW_DATA_DIR}/kw.db"
  if [[ "$?" == 0 ]]; then
    rm "${KW_DATA_DIR}/kw.db"
  fi
}

function test_kernel_config_manager_main_SAVE_fails()
{
  local output

  output=$(kernel_config_manager_main '--save' > /dev/null)
  assert_equals_helper ' --save' "$LINENO" 22 "$?"

  output=$(kernel_config_manager_main '--save' '--lala')
  assert_equals_helper ' --save --lala' "$LINENO" 'Invalid argument' "$output"

  output=$(kernel_config_manager_main '--save' '-n')
  assert_equals_helper ' --save -n' "$LINENO" 'Invalid argument' "$output"

  output=$(kernel_config_manager_main '--save' '-d')
  assert_equals_helper ' --save -d' "$LINENO" 'Invalid argument' "$output"

  output=$(kernel_config_manager_main '--save' '-d')
  assert_equals_helper ' --save -d' "$LINENO" 'Invalid argument' "$output"

  output=$(kernel_config_manager_main '--save' '-d' "lalala and xpto")
  assert_equals_helper ' --save -d' "$LINENO" 'Invalid argument' "$output"

  output=$(kernel_config_manager_main '--save' '-f')
  assert_equals_helper ' --save -f' "$LINENO" 'Invalid argument' "$output"
}

function test_save_config_file_check_save_failures()
{
  if is_safe_path_to_remove '.config'; then
    rm '.config'
  fi
  save_config_file "$NO_FORCE $NAME_1" "$DESCRIPTION_1" > /dev/null
  assert_equals_helper 'No .config file should return ENOENT' "$LINENO" 2 "$?"

  touch '.configuration'
  save_config_file "$NO_FORCE $NAME_1" "$DESCRIPTION_1" > /dev/null
  assert_equals_helper "Should return ENOENT, because '.config' != '.configuration'" "$LINENO" 2 "$?"
  if is_safe_path_to_remove '.configuration'; then
    rm '.configuration'
  fi
}

function test_save_config_file_check_directories_creation()
{
  save_config_file "$NO_FORCE" "$NAME_1" "$DESCRIPTION_1" > /dev/null

  assertTrue "${LINENO}: The configs dir was not created" '[[ -d ${dot_configs_dir} ]]'
}

function test_save_config_file_check_saved_config()
{
  local output

  save_config_file "$NO_FORCE" "$NAME_1" "$DESCRIPTION_1" > /dev/null
  assertTrue "${LINENO}: Failed to find .config file for ${NAME_1}" '[[ -f ${dot_configs_dir}/${NAME_1} ]]'
  output=$(select_from "kernel_config WHERE name IS '${NAME_1}'" 'name')
  assert_equals_helper "Failed to find db entry for ${NAME_1}" "$LINENO" "$NAME_1" "$output"

  save_config_file "$NO_FORCE" "$NAME_2" > /dev/null
  assertTrue "${LINENO}: Failed to find .config file for ${NAME_2}" '[[ -f ${dot_configs_dir}/${NAME_2} ]]'
  output=$(select_from "kernel_config WHERE name IS '${NAME_2}'" 'name')
  assert_equals_helper "Failed to find db entry for ${NAME_2}" "$LINENO" "$NAME_2" "$output"

  output=$(cat "${dot_configs_dir}/${NAME_2}")
  assert_equals_helper 'Content in the file does not match' "$LINENO" "$CONTENT" "$output"
}

function test_save_config_file_check_description()
{
  local output

  save_config_file "$NO_FORCE" "$NAME_1" "$DESCRIPTION_1" > /dev/null
  output=$(select_from "kernel_config WHERE name IS '${NAME_1}'" 'description')
  assert_equals_helper "The description content for ${NAME_1} does not match" "$LINENO" "$DESCRIPTION_1" "$output"

  save_config_file "$NO_FORCE" "$NAME_2" "$DESCRIPTION_2" > /dev/null
  output=$(select_from "kernel_config WHERE name IS '${NAME_2}'" 'description')
  assert_equals_helper "The description content for ${NAME_2} does not match" "$LINENO" "$DESCRIPTION_2" "$output"
}

function test_save_config_file_check_force()
{
  local output
  local expected

  save_config_file "$YES_FORCE" "$NAME_2" "$DESCRIPTION_2" > /dev/null
  output=$(save_config_file "$YES_FORCE" "$NAME_2" "$DESCRIPTION_2")
  assert_equals_helper 'Wrong output' "$LINENO" "Saved kernel config '${NAME_2}'" "$output"
}

function test_list_config_check_when_there_is_no_config()
{
  local output

  output=$(list_configs)
  assert_equals_helper 'Wrong output' "$LINENO" 'There are no .config files managed by kw' "$output"
}

function test_list_config_normal_output()
{
  local output
  local msg

  save_config_file "$YES_FORCE" "$NAME_1" "$DESCRIPTION_1" > /dev/null
  save_config_file "$YES_FORCE" "$NAME_2" "$DESCRIPTION_2" > /dev/null

  output=$(list_configs)
  assertTrue "${LINENO}: We expected 'Name' in the output, but we got ${output}" '[[ ${output} =~ Name ]]'
  assertTrue "${LINENO}: We expected 'Description' in the output, but we got ${output}" '[[ ${output} =~ Description ]]'
  assertTrue "${LINENO}: We expected ${NAME_1} in the output, but we got ${output}" '[[ ${output} =~ ${NAME_1} ]]'
  assertTrue "${LINENO}: We expected ${DESCRIPTION_1} in the output, but we got ${output}" '[[ ${output} =~ ${DESCRIPTION_1} ]]'
  assertTrue "${LINENO}: We expected ${NAME_2} in the output, but we got ${output}" '[[ ${output} =~ ${NAME_2} ]]'
  assertTrue "${LINENO}: We expected ${DESCRIPTION_2} in the output, but we got ${output}" '[[ ${output} =~ ${DESCRIPTION_2} ]]'
}

function test_kernel_config_manager_main_get_config_invalid_option()
{
  local output

  output=$(kernel_config_manager_main '--get' > /dev/null)
  assert_equals_helper ' --get' "$LINENO" 22 "$?"

  output=$(kernel_config_manager_main '--get' 'something_wrong')
  assert_equals_helper ' --get' "$LINENO" 'Couldn'"'"'t find config file named: something_wrong' "$output"
}

function test_get_config()
{
  local output

  declare -a expected_output=(
    'This operation will override the current .config file'
    "Current config file updated based on ${NAME_1}"
  )

  save_config_file "$NO_FORCE" "$NAME_1" "$DESCRIPTION_1" > /dev/null
  save_config_file "$NO_FORCE" "$NAME_2" "$DESCRIPTION_2" > /dev/null

  # Case 1: We already have a local config, pop up with replace question
  output=$(get_config "$NAME_1" <<< 'y')
  compare_command_sequence 'Wrong output' "$LINENO" 'expected_output' "$output"

  # Case 2: There's no local .config file
  if is_safe_path_to_remove '.config'; then
    rm '.config'
  fi
  get_config "$NAME_1" > /dev/null
  output=$(cat .config)
  assert_equals_helper "We expected ${CONTENT}, but we got ${output}" "$LINENO" "$CONTENT" "$output"
}

function test_get_config_with_force()
{
  local output

  save_config_file "$NO_FORCE" "$NAME_1" "$DESCRIPTION_1" > /dev/null
  save_config_file "$NO_FORCE" "$NAME_2" "$DESCRIPTION_2" > /dev/null

  # Case 1: There's no local .config file
  if is_safe_path_to_remove '.config'; then
    rm '.config'
  fi
  get_config "$NAME_1" 1 > /dev/null
  output=$(cat .config)
  assert_equals_helper "We expected ${CONTENT}, but we got ${output}" "$LINENO" "$CONTENT" "$output"

  # Case 2: There's a .config file
  get_config "$NAME_2" 1 > /dev/null
  output=$(cat .config)
  assert_equals_helper "We expected ${CONTENT}, but we got ${output}" "$LINENO" "$CONTENT" "$output"
}

function test_get_config_with_file_and_without_database_entry()
{
  local output
  local expected

  touch "${dot_configs_dir}/${NAME_1}"

  output=$(get_config "$NAME_1" <<< 'n')
  expected="Couldn't find config in database named: ${NAME_1}"$'\n'
  expected+="${dot_configs_dir}/${NAME_1} not removed"
  assertTrue "${LINENO}: Shouldn't remove ${NAME_1} file from local fs" '[[ -f "${dot_configs_dir}/${NAME_1}" ]]'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  output=$(get_config "$NAME_1" <<< 'y')
  expected="Couldn't find config in database named: ${NAME_1}"$'\n'
  expected+="Removing file: ${dot_configs_dir}/${NAME_1}"
  assertTrue "${LINENO}: Should remove ${NAME_1} file from local fs" '[[ ! -f "${dot_configs_dir}/${NAME_1}" ]]'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
}

function test_kernel_config_manager_main_remove_that_should_fail()
{
  local output

  output=$(kernel_config_manager_main '--remove' 2>&1 > /dev/null)
  assert_equals_helper ' --remove' "$LINENO" 22 "$?"

  output=$(kernel_config_manager_main '--remove' something_wrong)
  assert_equals_helper ' --remove' "$LINENO" 'Couldn'"'"'t find config file named: something_wrong' "$output"
}

function test_remove_config()
{
  local output

  save_config_file "$NO_FORCE" "$NAME_1" "$DESCRIPTION_1" > /dev/null
  save_config_file "$NO_FORCE" "$NAME_2" "$DESCRIPTION_2" > /dev/null

  # Case 1: We should have two files
  output=$(find "${dot_configs_dir}" -mindepth 1 -type f | wc -l)
  assert_equals_helper "We expected 2 files but got ${output}" "$LINENO" 2 "$output"
  output=$(select_from 'kernel_config' 'count(*)')
  assert_equals_helper "We expected 2 entries in the db but got ${output}" "$LINENO" 2 "$output"

  # Case 2: Remove one config file
  remove_config "$NAME_1" 1 > /dev/null 2>&1
  output=$(find "${dot_configs_dir}" -mindepth 1 -type f | wc -l)
  assert_equals_helper "We expected 1 file but got ${output}" "$LINENO" 1 "$output"
  output=$(select_from 'kernel_config' 'count(*)')
  assert_equals_helper "We expected 1 entry in the db but got ${output}" "$LINENO" 1 "$output"

  # Case 3: Remove all config files
  remove_config "$NAME_2" 1 > /dev/null 2>&1
  output=$(find "${dot_configs_dir}" -mindepth 1 -type f | wc -l)
  assert_equals_helper "We expected no files but got ${output}" "$LINENO" 0 "$output"
  output=$(select_from 'kernel_config' 'count(*)')
  assert_equals_helper "We expected no entry in the db but got ${output}" "$LINENO" 0 "$output"
}

function test_cleanup()
{
  local output

  mkdir -p "$KW_CACHE_DIR/config"
  touch "$KW_CACHE_DIR/lsmod"

  declare -a expected_cmd=(
    'Cleaning up and retrieving files...'
    "mv $KW_CACHE_DIR/config/* $PWD"
    "rmdir $KW_CACHE_DIR/config"
    "rm $KW_CACHE_DIR/lsmod"
    'Exiting...'
  )

  output=$(cleanup 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_get_config_from_proc()
{
  local output
  declare -la expected_cmd=()

  get_config_from_proc 'TEST_MODE' '' 1
  assert_equals_helper 'proc/config.gz is not supported for VM' "$LINENO" 95 "$?"

  # 2) Local
  # Mocking non-existent proc
  mkdir 'proc'
  export PROC_CONFIG_PATH='proc/config.gz'

  declare -la expected_cmd=(
    'sudo modprobe -q configs && [ -s proc/config.gz ]'
    'zcat /proc/config.gz > .config'
  )

  output=$(get_config_from_proc 'TEST_MODE' '.config' 2)
  compare_command_sequence 'Wrong command issued' "$LINENO" 'expected_cmd' "$output"

  # Creating a fake config
  touch 'proc/config.gz'

  expected_cmd=()
  expected_cmd=(
    'zcat /proc/config.gz > .config'
  )

  output=$(get_config_from_proc 'TEST_MODE' '.config' 2)
  compare_command_sequence 'Wrong command issued' "$LINENO" 'expected_cmd' "$output"

  # 3) Remote
  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='3333'
  remote_parameters['REMOTE_USER']='juca'

  unset expected_cmd
  declare -a expected_cmd=(
    'ssh -p 3333 juca@127.0.0.1 sudo "[ -f proc/config.gz ]"'
    'ssh -p 3333 juca@127.0.0.1 sudo "zcat /proc/config.gz > /tmp/.config"'
    "rsync --info=progress2 -e 'ssh -p 3333' juca@127.0.0.1:/tmp/.config ${PWD} -LrlptD --rsync-path='sudo rsync'"
  )

  output=$(get_config_from_proc 'TEST_MODE' '.config' 3)
  compare_command_sequence 'Wrong command issued' "$LINENO" 'expected_cmd' "$output"

  # Removing fake proc
  if is_safe_path_to_remove 'proc'; then
    rm -rf 'proc'
  fi
}

function test_get_config_from_proc_inside_env_remote()
{
  local output
  declare -la expected_cmd=()

  options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']='/tmp/something'
  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='3333'
  remote_parameters['REMOTE_USER']='juca'

  unset expected_cmd
  declare -a expected_cmd=(
    'ssh -p 3333 juca@127.0.0.1 sudo "[ -f proc/config.gz ]"'
    'ssh -p 3333 juca@127.0.0.1 sudo "zcat /proc/config.gz > /tmp/.config"'
    "rsync --info=progress2 -e 'ssh -p 3333' juca@127.0.0.1:/tmp/.config /tmp/something -LrlptD --rsync-path='sudo rsync'"
  )

  output=$(get_config_from_proc 'TEST_MODE' '.config' 3)
  compare_command_sequence 'Wrong command issued' "$LINENO" 'expected_cmd' "$output"
}

function test_get_config_from_boot()
{
  # shellcheck disable=SC2317
  function uname()
  {
    printf '%s\n' '5.5.0-rc2-VKMS+'
  }

  get_config_from_boot 'TEST_MODE' '' 1
  assert_equals_helper 'We do not support VMs yet' "$LINENO" 95 "$?"

  # Preparing
  export root="./"

  # LOCAL
  get_config_from_boot 'SILENT' '.config' 2
  assert_equals_helper 'We do not have a config file' "$LINENO" 95 "$?"

  mk_fake_boot
  get_config_from_boot 'SILENT' '.config' 2
  assert_equals_helper 'We did not copy the target file' "$LINENO" 0 "$?"
}

function test_get_config_from_boot_inside_env_remote()
{
  options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']='/tmp/something'
  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='3333'
  remote_parameters['REMOTE_USER']='juca'

  unset expected_cmd
  declare -a expected_cmd=(
    'ssh -p 3333 juca@127.0.0.1 sudo "[ -f ./boot/config-ssh -p 3333 juca@127.0.0.1 sudo "uname -r" ]"'
    "rsync --info=progress2 -e 'ssh -p 3333' juca@127.0.0.1:./boot/config-ssh -p 3333 juca@127.0.0.1 sudo \"uname -r\" /tmp/something -LrlptD --rsync-path='sudo rsync'"
  )

  output=$(get_config_from_boot 'TEST_MODE' '' 3)

  compare_command_sequence 'Wrong command issued' "$LINENO" 'expected_cmd' "$output"
}

function test_get_config_from_defconfig()
{
  local output
  local single_cmd

  get_config_from_defconfig 'TEST_MODE' '.config' > /dev/null
  assert_equals_helper 'We should fail if we are not in a kernel dir' "$LINENO" 125 "$?"

  mk_fake_kernel_root "$PWD"
  # Case with different config
  single_cmd='make defconfig ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-'
  single_cmd+=" && mv $PWD/.config lala && mv $PWD/cache/config/.config $PWD/.config"
  output=$(get_config_from_defconfig 'TEST_MODE' 'lala')
  assert_equals_helper 'Config file backup' "$LINENO" "$single_cmd" "$output"

  # Case with cross-compile
  single_cmd='make defconfig ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-'
  output=$(get_config_from_defconfig 'TEST_MODE' '.config')
  assert_equals_helper 'Cross compilation failed' "$LINENO" "$single_cmd" "$output"

  build_config[arch]=''
  output=$(get_config_from_defconfig 'TEST_MODE' '.config')
  single_cmd='make defconfig CROSS_COMPILE=aarch64-linux-gnu-'
  assert_equals_helper 'No arch' "$LINENO" "$single_cmd" "$output"

  build_config[cross_compile]=''
  output=$(get_config_from_defconfig 'TEST_MODE' '.config')
  single_cmd='make defconfig'
  assert_equals_helper 'No arch' "$LINENO" "$single_cmd" "$output"
}

function test_fetch_config()
{
  local output
  local current_path="$PWD"
  local LOCAL_TARGET=2
  local REMOTE_TARGET=3

  declare -a expected_output

  export root="${SHUNIT_TMPDIR}/kernel/"

  mkdir -p "$root"
  mkdir -p "$KW_CACHE_DIR"

  # shellcheck disable=SC2317
  function uname()
  {
    printf '%s\n' 'x86'
  }

  cd "$root" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # Check error message when run optimize outside kernel structure
  output=$(printf '%s\n' 'y' | fetch_config 'TEST_MODE' '' '' 1 | tail -1)
  assert_equals_helper 'No fake kernel should be here' "$LINENO" \
    'This command should be run in a kernel tree.' "$output"

  # Retrieve config using local
  mk_fake_kernel_root "$PWD"

  expected_output=(
    "mkdir -p ${KW_CACHE_DIR}/config"
    # Note: since we are creating a faking /proc, we dropped '/'.
    'sudo modprobe -q configs && [ -s proc/config.gz ]'
    'zcat /proc/config.gz > .config'
    'make olddefconfig'
    "rm -rf ${KW_CACHE_DIR}/config"
    'Successfully retrieved .config'
  )
  output=$(fetch_config 'TEST_MODE' '' '' '' "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  expected_output=(
    "mkdir -p ${KW_CACHE_DIR}/config"
    'zcat /proc/config.gz > .config'
    'make olddefconfig'
    "rm -rf ${KW_CACHE_DIR}/config"
    'Successfully retrieved .config'
  )

  mkdir "${root}proc"
  touch "${root}proc/config.gz"
  export PROC_CONFIG_PATH="${root}proc/config.gz"
  output=$(fetch_config 'TEST_MODE' '' '' '' "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  touch "$root/.config"

  # Say no to overwriting the file
  output=$(printf '%s\n' 'n' | fetch_config 'TEST_MODE' '' '' '' "$LOCAL_TARGET" | tail -n 1)
  assert_equals_helper 'The operation should have been aborted' "$LINENO" 'Operation aborted' "$output"

  # Say yes to overwriting the file
  expected_output=(
    "mkdir -p ${KW_CACHE_DIR}/config"
    "cp ${PWD}/.config ${KW_CACHE_DIR}/config"
    'zcat /proc/config.gz > .config'
    'make olddefconfig'
    "rm -rf ${KW_CACHE_DIR}/config"
    'Successfully retrieved .config'
  )

  output=$(printf '%s\n' 'y' | fetch_config 'TEST_MODE' '' '' '' "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  # Now using the --force option
  output=$(fetch_config 'TEST_MODE' 1 '' '' "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  expected_output=(
    "mkdir -p ${KW_CACHE_DIR}/config"
    "cp ${PWD}/.config ${KW_CACHE_DIR}/config"
    'zcat /proc/config.gz > newconfig'
    'make olddefconfig'
    "rm -rf ${KW_CACHE_DIR}/config"
    'Successfully retrieved newconfig'
  )

  output=$(fetch_config 'TEST_MODE' '' 'newconfig' '' "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  # Optimized
  rm -rf "${root:?}/"*

  mk_fake_kernel_root "$PWD"

  output=$(printf '%s\n' 'n' | fetch_config 'TEST_MODE' '' '' 1 "$LOCAL_TARGET")
  assert_equals_helper ' --remove' "$LINENO" 125 "$?"

  rm "$PWD/.config"
  mkdir "${root}proc"
  touch "${root}proc/config.gz"
  expected_output=(
    "mkdir -p ${KW_CACHE_DIR}/config"
    'zcat /proc/config.gz > .config'
    'make olddefconfig'
    "make localmodconfig LSMOD=$KW_CACHE_DIR/lsmod"
    "rm -f ${KW_CACHE_DIR}/lsmod"
    "rm -rf ${KW_CACHE_DIR}/config"
    'Successfully retrieved .config'
  )

  output=$(printf '%s\n' 'y' | fetch_config 'TEST_MODE' '' '' 1 "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  expected_output=(
    "ssh -p 1234 mary@localhost sudo \"mkdir -p /tmp/kw\""
    "ssh -p 1234 mary@localhost sudo \"[ -f /proc/config.gz ]\""
    "ssh -p 1234 mary@localhost sudo \"zcat /proc/config.gz > /tmp/kw/.config\""
    "rsync -e \"ssh -p 1234\" mary@localhost:/tmp/kw/.config $PWD"
    "ssh -p 1234 mary@localhost sudo \"rm -rf /tmp/kw\""
    'make olddefconfig'
    'Successfully retrieved .config'
  )

  # Compare sequence of commands to retrieve .config from remote machine
  remote_parameters['REMOTE_USER']='mary'
  remote_parameters['REMOTE_IP']='localhost'
  remote_parameters['REMOTE_PORT']='1234'
  output=$(printf '%s\n' 'y' | fetch_config 'TEST_MODE' '' '' '' "$REMOTE_TARGET")
  # TODO: There is nothing being tested here

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_get_config_with_env()
{
  local output

  # Create a fake env folder
  mkdir -p 'fake_env'
  options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']="${PWD}/fake_env"

  # Create a fake config file
  mkdir -p "${dot_configs_dir}"
  touch "${dot_configs_dir}/FAKE_CONFIG"

  # Add entry in the database
  insert_into 'kernel_config' '(name,path,last_updated_datetime)' "('FAKE_CONFIG','${dot_configs_dir}/FAKE_CONFIG','1998-04-17 12:23:21')"

  output=$(get_config 'FAKE_CONFIG' <<< 'y')
  assertTrue "${LINENO}: config file was not added to the env" '[[ -f "./fake_env/.config" ]]'
}

function test_kernel_config_manager_parser()
{
  unset options_values
  declare -gA options_values
  local expected
  local ret

  # Invalid options
  parse_kernel_config_manager_options '--save'
  ret="$?"
  parse_kernel_config_manager_options '-s'
  ret=$((ret + $?))
  assert_equals_helper 'Option without argument' "$LINENO" 44 "$ret"

  parse_kernel_config_manager_options '--remove'
  ret="$?"
  parse_kernel_config_manager_options '-r'
  ret=$((ret + $?))
  assert_equals_helper 'Option without argument' "$LINENO" 44 "$ret"

  parse_kernel_config_manager_options '--description'
  ret="$?"
  parse_kernel_config_manager_options '-d'
  ret=$((ret + $?))
  assert_equals_helper 'Option without argument' "$LINENO" 44 "$ret"

  parse_kernel_config_manager_options '--output'
  ret="$?"
  parse_kernel_config_manager_options '-o'
  ret=$((ret + $?))
  assert_equals_helper 'Option without argument' "$LINENO" 44 "$ret"

  parse_kernel_config_manager_options '--get'
  ret="$?"
  assert_equals_helper 'Option without argument' "$LINENO" 22 "$ret"

  parse_kernel_config_manager_options '--remote'
  ret="$?"
  assert_equals_helper 'Option without argument' "$LINENO" 22 "$ret"

  parse_kernel_config_manager_options '--LalaXpto' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option' "$LINENO" 22 "$ret"

  parse_kernel_config_manager_options '--wrongOption' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option' "$LINENO" 22 "$ret"

  # valid options
  parse_kernel_config_manager_options '--force'
  expected=1
  assert_equals_helper 'Set force flag' "$LINENO" "$expected" "${options_values['FORCE']}"

  parse_kernel_config_manager_options '-s' "$NAME_1" '-d' "$DESCRIPTION_1"
  assert_equals_helper 'Set save options' "$LINENO" "$NAME_1" "${options_values['SAVE']}"
  assert_equals_helper 'Set description options' "$LINENO" "$DESCRIPTION_1" "${options_values['DESCRIPTION']}"

  parse_kernel_config_manager_options '--get' "$NAME_1"
  assert_equals_helper 'Set get flag' "$LINENO" "$NAME_1" "${options_values['GET']}"

  parse_kernel_config_manager_options '--remove' "$NAME_1"
  assert_equals_helper 'Set remove flag' "$LINENO" "$NAME_1" "${options_values['REMOVE']}"

  parse_kernel_config_manager_options '--list'
  expected=1
  assert_equals_helper 'Set list flag' "$LINENO" "$expected" "${options_values['LIST']}"

  parse_kernel_config_manager_options '--fetch'
  expected=1
  assert_equals_helper 'Set fetch flag' "$LINENO" "$expected" "${options_values['FETCH']}"

  parse_kernel_config_manager_options '--output' "$NAME_1"
  assert_equals_helper 'Set output flag' "$LINENO" "$NAME_1" "${options_values['OUTPUT']}"

  parse_kernel_config_manager_options '--remote' "$NAME_1"
  assert_equals_helper 'Set remote flag' "$LINENO" 3 "${options_values['TARGET']}"

  parse_kernel_config_manager_options '--optimize'
  expected=1
  assert_equals_helper 'Set optimize flag' "$LINENO" "$expected" "${options_values['OPTIMIZE']}"
}

invoke_shunit
