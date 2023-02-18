#!/bin/bash

include './src/kernel_config_manager.sh'
include './tests/utils.sh'

COMMAND_MSG_UNKNOWN='Unknown option'
COMMAND_MSG_INVALID_ARG='Invalid argument'
COMMAND_NO_SUCH_FILE='No such file or directory'

readonly YES_FORCE='1'
readonly NO_FORCE='0'

readonly CONTENT='The content'

readonly NAME_1='test_save_1'
readonly NAME_2='test_save_2'

readonly DESCRIPTION_1='This is the first description'
readonly DESCRIPTION_2="Hi, I'm the second description"

function setUp()
{
  local -r current_path="$PWD"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  touch .config
  printf '%s\n' "$CONTENT" > .config

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  export KW_CACHE_DIR="${SHUNIT_TMPDIR}/cache"
  mkdir -p "${SHUNIT_TMPDIR}/configs"

  KW_DATA_DIR="$SHUNIT_TMPDIR"
  export configs_path="${KW_DATA_DIR}/configs"

  parse_configuration "$KW_CONFIG_SAMPLE"
  parse_configuration "$KW_BUILD_CONFIG_SAMPLE" build_config
  declare -la expected_cmd=()
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
  mkdir -p "$SHUNIT_TMPDIR"
  unset expected_cmd
}

function test_kernel_config_manager_main_SAVE_fails()
{
  local msg_prefix=" --save"
  local ret

  ret=$(kernel_config_manager_main --save 2>&1 > /dev/null)
  assert_equals_helper "$msg_prefix" "$LINENO" "$?" 22

  ret=$(kernel_config_manager_main --save --lala)
  assert_equals_helper "$msg_prefix --lala" "$LINENO" "$ret" "$COMMAND_MSG_INVALID_ARG"

  ret=$(kernel_config_manager_main --save -n)
  assert_equals_helper "$msg_prefix -n" "$LINENO" "$ret" "$COMMAND_MSG_INVALID_ARG"

  ret=$(kernel_config_manager_main --save -d)
  assert_equals_helper "$msg_prefix -d" "$LINENO" "$ret" "$COMMAND_MSG_INVALID_ARG"

  ret=$(kernel_config_manager_main --save -d)
  assert_equals_helper "$msg_prefix -d" "$LINENO" "$ret" "$COMMAND_MSG_INVALID_ARG"

  ret=$(kernel_config_manager_main --save -d "lalala and xpto")
  assert_equals_helper "$msg_prefix -d" "$LINENO" "$ret" "$COMMAND_MSG_INVALID_ARG"

  ret=$(kernel_config_manager_main --save -f)
  assert_equals_helper "$msg_prefix -f" "$LINENO" "$ret" "$COMMAND_MSG_INVALID_ARG"
}

function test_save_config_file_check_save_failures()
{
  local current_path="$PWD"
  local ret=0

  # Test without config file -> should fail
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  rm -f .config
  ret=$(save_config_file "$NO_FORCE $NAME_1" "$DESCRIPTION_1")
  assert_equals_helper 'No .config file should return ENOENT' "$LINENO" "$?" "2"

  # Test with different name
  touch .configuration
  ret=$(save_config_file "$NO_FORCE $NAME_1" "$DESCRIPTION_1")
  assert_equals_helper "Should return ENOENT, because '.config' != '.configuration'" "$LINENO" "$?" "2"
  rm .configuration

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_save_config_file_check_directories_creation()
{
  local current_path="$PWD"

  # There's no configs yet, initialize it
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  # Check if all the expected files were created
  assertTrue "$LINENO: The configs dir was not created" '[[ -d $configs_path ]]'
  assertTrue "$LINENO: The metadata dir is not available" '[[ -d $configs_path/metadata ]]'
  assertTrue "$LINENO: The configs dir is not available" '[[ -d $configs_path/configs ]]'
}

function test_save_config_file_check_saved_config()
{
  local current_path="$PWD"
  local ret=0
  local msg
  local tmp

  # There's no configs yet, initialize it
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  msg="Failed to find $NAME_1"
  assertTrue "$LINENO: $msg" '[[ -f $configs_path/configs/$NAME_1 ]]'
  msg="Failed the metadata related to $NAME_1"
  assertTrue "$LINENO: $msg" '[[ -f $configs_path/metadata/$NAME_1 ]]'

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  ret=$(save_config_file $NO_FORCE $NAME_2)
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  msg="Failed to find $NAME_2"
  assertTrue "$LINENO: $msg" '[[ -f $configs_path/configs/$NAME_2 ]]'
  msg="Failed the metadata related to $NAME_2"
  assertTrue "$LINENO: $msg" '[[ -f $configs_path/metadata/$NAME_2 ]]'

  tmp=$(cat "$configs_path/configs/$NAME_2")
  msg="Content in the file does not match"
  assertTrue "$LINENO: $msg" '[[ $tmp = $CONTENT ]]'
}

function test_save_config_file_check_description()
{
  local current_path="$PWD"
  local ret=0
  local msg
  local tmp

  # There's no configs yet, initialize it
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  tmp=$(cat "$configs_path/metadata/$NAME_1")
  msg="The description content for $NAME_1 does not match"
  assertTrue "$LINENO: $msg" '[[ $tmp = $DESCRIPTION_1 ]]'

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  ret=$(save_config_file $NO_FORCE $NAME_2 "$DESCRIPTION_2")
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  tmp=$(cat "$configs_path/metadata/$NAME_2")
  msg="The description content for $NAME_2 does not match"
  assertTrue "$LINENO: $msg" '[[ $tmp = $DESCRIPTION_2 ]]'
}

function test_save_config_file_check_force()
{
  local current_path="$PWD"
  local ret=0

  # There's no configs yet, initialize it
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  ret=$(save_config_file $YES_FORCE $NAME_2 "$DESCRIPTION_2")
  ret=$(save_config_file $YES_FORCE $NAME_2 "$DESCRIPTION_2")
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
  assertTrue "$LINENO: We expected no changes" '[[ $ret =~ Warning ]]'
}

function test_list_config_check_when_there_is_no_config()
{
  local current_path="$PWD"
  local ret=0

  # There's no configs yet, initialize it
  ret=$(list_configs)
  assertTrue "$LINENO: We expected no changes" '[[ $ret =~ $LS_NO_FILES ]]'
}

function test_list_config_normal_output()
{
  local current_path="$PWD"
  local ret=0
  local msg

  # There's no configs yet, initialize it
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  ret=$(save_config_file $YES_FORCE $NAME_1 "$DESCRIPTION_1")
  ret=$(save_config_file $YES_FORCE $NAME_2 "$DESCRIPTION_2")
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  # There's no configs yet, initialize it
  ret=$(list_configs)
  msg="We expected 'Name' in the output, but we got $ret"
  assertTrue "$LINENO: $msg" '[[ $ret =~ Name ]]'

  msg="We expected 'Description' in the output, but we got $ret"
  assertTrue "$LINENO: $msg" '[[ $ret =~ Description ]]'

  msg="We expected $NAME_1 in the output, but we got $ret"
  assertTrue "$LINENO: $msg" '[[ $ret =~ $NAME_1 ]]'

  msg="We expected $DESCRIPTION_1 in the output, but we got $ret"
  assertTrue "$LINENO: $msg" '[[ $ret =~ $DESCRIPTION_1 ]]'

  msg="We expected $NAME_2 in the output, but we got $ret"
  assertTrue "$LINENO: $msg" '[[ $ret =~ $NAME_2 ]]'

  msg="We expected $DESCRIPTION_2 in the output, but we got $ret"
  assertTrue "$LINENO:$msg" '[[ $ret =~ $DESCRIPTION_2 ]]'
}

function test_kernel_config_manager_main_get_config_invalid_option()
{
  local msg_prefix=" --get"

  ret=$(kernel_config_manager_main --get 2>&1 > /dev/null)
  assert_equals_helper "$msg_prefix" "$LINENO" "$?" 22

  ret=$(kernel_config_manager_main --get something_wrong)
  assert_equals_helper "$msg_prefix" "$LINENO" "$COMMAND_NO_SUCH_FILE: something_wrong" "$ret"
}

function test_get_config()
{
  local current_path="$PWD"
  local ret=0
  local msg="This operation will override the current .config file"
  local replace_msg="Current config file updated based on $NAME_1"

  declare -a expected_output=(
    "$msg"
    "$replace_msg"
  )

  # There's no configs yet, initialize it
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  ret=$(save_config_file $NO_FORCE $NAME_2 "$DESCRIPTION_2")
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  # Case 1: We already have a local config, pop up with replace question
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  output=$(printf '%s\n' 'y' | get_config "$NAME_1")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  # Case 2: There's no local .config file
  rm -f .config
  output=$(get_config "$NAME_1")
  ret=$(cat .config)
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  assertTrue "$LINENO: We expected $CONTENT, but we got $ret" '[[ $ret =~ $CONTENT ]]'
}

function test_get_config_with_force()
{
  local current_path="$PWD"
  local ret=0

  # There's no configs yet, initialize it
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  ret=$(save_config_file $NO_FORCE $NAME_2 "$DESCRIPTION_2")
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  # Case 1: There's no local .config file
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  rm -f .config
  get_config "$NAME_1" 1 > /dev/null 2>&1
  ret=$(cat .config)
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  assertTrue "$LINENO: We expected $CONTENT, but we got $ret" '[[ $ret =~ $CONTENT ]]'

  # Case 2: There's a .config file
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  get_config "$NAME_2" 1 > /dev/null 2>&1
  ret=$(cat .config)
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  assertTrue "$LINENO: We expected $CONTENT, but we got $ret" '[[ $ret =~ $CONTENT ]]'
}

function test_kernel_config_manager_main_remove_that_should_fail()
{
  local msg_prefix=" -r"

  ret=$(kernel_config_manager_main -r 2>&1 > /dev/null)
  assert_equals_helper "$msg_prefix" "$LINENO" "$?" 22

  ret=$(kernel_config_manager_main -r something_wrong)
  assert_equals_helper "$msg_prefix" "$LINENO" "$COMMAND_NO_SUCH_FILE: something_wrong" "$ret"
}

function test_remove_config()
{
  local current_path="$PWD"
  local ret=0

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  ret=$(save_config_file $NO_FORCE $NAME_2 "$DESCRIPTION_2")
  ret=$(find configs/configs -mindepth 1 -type f | wc -l)
  # Case 1: We should have two files
  assertTrue "We expected , 2 files but got $ret" '[[ $ret = "2" ]]'

  # Case 2: Remove one config file
  remove_config "$NAME_1" 1 > /dev/null 2>&1
  ret=$(find configs/configs -mindepth 1 -type f | wc -l)
  assertTrue "$LINENO: We expected , 1 files but got $ret" '[[ $ret = "1" ]]'

  # Case 2: Remove all config files
  remove_config "$NAME_2" 1 > /dev/null 2>&1
  assertTrue "$LINENO: We expected no file related to config" '[[ ! -f configs/configs ]]'

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
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
  local -r current_path="$PWD"
  local output
  declare -la expected_cmd=()

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  get_config_from_proc 'TEST_MODE' '' 1
  assert_equals_helper 'proc/config.gz is not supported for VM' "$LINENO" "$?" 95

  # 2) Local
  # Mocking non-existent proc
  mkdir 'proc'
  export PROC_CONFIG_PATH='proc/config.gz'

  declare -la expected_cmd=(
    'sudo modprobe -q configs && [ -s proc/config.gz ]'
    'zcat /proc/config.gz > .config'
  )

  output=$(get_config_from_proc 'TEST_MODE' '.config' 2)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Creating a fake config
  touch "proc/config.gz"

  expected_cmd=()
  declare -a expected_cmd=(
    'zcat /proc/config.gz > .config'
  )

  output=$(get_config_from_proc 'TEST_MODE' '.config' 2)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

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
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Removing fake proc
  rm -rf 'proc'

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_get_config_from_boot()
{
  local -r current_path="$PWD"
  local output

  function uname()
  {
    printf '%s\n' '5.5.0-rc2-VKMS+'
  }

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  get_config_from_boot 'TEST_MODE' '' 1
  assert_equals_helper 'We do not support VMs yet' "$LINENO" "$?" 95

  # Preparing
  export root="./"

  # LOCAL
  get_config_from_boot 'SILENT' '.config' 2
  assert_equals_helper 'We do not have a config file' "$LINENO" "$?" 95

  mk_fake_boot
  get_config_from_boot 'SILENT' '.config' 2
  assert_equals_helper 'We did not copy the target file' "$LINENO" "$?" 0

  # REMOTE: We need integration test to cover remote in this case

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_get_config_from_defconfig()
{
  local -r current_path="$PWD"
  local output
  local single_cmd

  get_config_from_defconfig 'TEST_MODE' '.config' > /dev/null
  assert_equals_helper 'We should fail if we are not in a kernel dir' "$LINENO" "$?" 125

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  mk_fake_kernel_root "$PWD"
  # Case with different config
  single_cmd='make defconfig ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-'
  single_cmd+=" && mv $PWD/.config lala && mv $PWD/cache/config/.config $PWD/.config"
  output=$(get_config_from_defconfig 'TEST_MODE' 'lala')
  assert_equals_helper 'Config file backup' "$LINENO" "$output" "$single_cmd"

  # Case with cross-compile
  single_cmd='make defconfig ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-'
  output=$(get_config_from_defconfig 'TEST_MODE' '.config')
  assert_equals_helper 'Cross compilation failed' "$LINENO" "$output" "$single_cmd"

  build_config[arch]=''
  output=$(get_config_from_defconfig 'TEST_MODE' '.config')
  single_cmd='make defconfig CROSS_COMPILE=aarch64-linux-gnu-'
  assert_equals_helper 'No arch' "$LINENO" "$output" "$single_cmd"

  build_config[cross_compile]=''
  output=$(get_config_from_defconfig 'TEST_MODE' '.config')
  single_cmd='make defconfig'
  assert_equals_helper 'No arch' "$LINENO" "$output" "$single_cmd"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_fetch_config()
{
  local output
  local current_path="$PWD"
  local LOCAL_TARGET=2
  local REMOTE_TARGET=3

  declare -a expected_output

  export root="$SHUNIT_TMPDIR/kernel/"

  mkdir -p "$root"
  mkdir -p "$KW_CACHE_DIR"

  function uname()
  {
    printf '%s\n' 'x86'
  }

  cd "$root" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # Check error message when run optimize outside kernel structure
  output=$(printf '%s\n' 'y' | fetch_config 'TEST_MODE' '' '' 1)
  assert_equals_helper 'No fake kernel should be here' "$LINENO" "$output" \
    'This command should be run in a kernel tree.'

  # Retrieve config using local
  mk_fake_kernel_root "$PWD"

  expected_output=(
    # Note: since we are creating a faking /proc, we dropped '/'.
    'sudo modprobe -q configs && [ -s proc/config.gz ]'
    'zcat /proc/config.gz > .config'
    'make olddefconfig'
    'Successfully retrieved .config'
  )
  output=$(fetch_config 'TEST_MODE' '' '' '' "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  expected_output=(
    'zcat /proc/config.gz > .config'
    'make olddefconfig'
    'Successfully retrieved .config'
  )

  mkdir "${root}proc"
  touch "${root}proc/config.gz"
  export PROC_CONFIG_PATH="${root}proc/config.gz"
  output=$(fetch_config 'TEST_MODE' '' '' '' "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  touch "$root/.config"

  # Say no to overwriting the file
  output=$(printf '%s\n' 'n' | fetch_config 'TEST_MODE' '' '' '' "$LOCAL_TARGET")
  assert_equals_helper 'The operation should have been aborted' "$LINENO" "$output" 'Operation aborted'

  # Say yes to overwriting the file
  output=$(printf '%s\n' 'y' | fetch_config 'TEST_MODE' '' '' '' "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  # Now using the --force option
  output=$(fetch_config 'TEST_MODE' 1 '' '' "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  expected_output=(
    'zcat /proc/config.gz > newconfig'
    'make olddefconfig'
    'Successfully retrieved newconfig'
  )

  output=$(fetch_config 'TEST_MODE' '' 'newconfig' '' "$LOCAL_TARGET")
  compare_command_sequence '' "$LINENO" 'expected_output' "$output"

  # Optimized
  rm -rf "${root:?}/"*

  mk_fake_kernel_root "$PWD"

  output=$(printf '%s\n' 'n' | fetch_config 'TEST_MODE' '' '' 1 "$LOCAL_TARGET")
  assert_equals_helper 'The operation should have been aborted' "$LINENO" "$output" 'Operation aborted'

  rm "$PWD/.config"
  mkdir "${root}proc"
  touch "${root}proc/config.gz"
  expected_output=(
    'zcat /proc/config.gz > .config'
    'make olddefconfig'
    "make localmodconfig LSMOD=$KW_CACHE_DIR/lsmod"
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

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_get_config_with_env()
{
  local current_path="$PWD"
  local ret=0
  local output

  declare -a expected_output=(
    "$msg"
    "$replace_msg"
  )

  # There's no configs yet, initialize it
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # Create a fake env folder
  mkdir -p 'fake_env'
  options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']="${PWD}/fake_env"

  # Create a fake config file
  mkdir -p "${configs_path}/configs"
  touch "${configs_path}/configs/FAKE_CONFIG"

  output=$(printf '%s\n' 'y' | get_config 'FAKE_CONFIG')

  assertTrue "($LINENO): config file was not added to the env" "[[ -f ./fake_env/.config ]]"
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
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
  assert_equals_helper 'Option without argument' "$LINENO" "$ret" 44

  parse_kernel_config_manager_options '--remove'
  ret="$?"
  parse_kernel_config_manager_options '-r'
  ret=$((ret + $?))
  assert_equals_helper 'Option without argument' "$LINENO" "$ret" 44

  parse_kernel_config_manager_options '--description'
  ret="$?"
  parse_kernel_config_manager_options '-d'
  ret=$((ret + $?))
  assert_equals_helper 'Option without argument' "$LINENO" "$ret" 44

  parse_kernel_config_manager_options '--output'
  ret="$?"
  parse_kernel_config_manager_options '-o'
  ret=$((ret + $?))
  assert_equals_helper 'Option without argument' "$LINENO" "$ret" 44

  parse_kernel_config_manager_options '--get'
  ret="$?"
  assert_equals_helper 'Option without argument' "$LINENO" "$ret" 22

  parse_kernel_config_manager_options '--remote'
  ret="$?"
  assert_equals_helper 'Option without argument' "$LINENO" "$ret" 22

  parse_kernel_config_manager_options '--LalaXpto' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option' "$LINENO" "$ret" 22

  parse_kernel_config_manager_options '--wrongOption' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option' "$LINENO" "$ret" 22

  # valid options
  parse_kernel_config_manager_options '--force'
  expected=1
  assert_equals_helper 'Set force flag' "$LINENO" "${options_values['FORCE']}" "$expected"

  parse_kernel_config_manager_options '-s' "$NAME_1" '-d' "$DESCRIPTION_1"
  assert_equals_helper 'Set save options' "$LINENO" "${options_values['SAVE']}" "$NAME_1"
  assert_equals_helper 'Set description options' "$LINENO" "${options_values['DESCRIPTION']}" "$DESCRIPTION_1"

  parse_kernel_config_manager_options '--get' "$NAME_1"
  assert_equals_helper 'Set get flag' "$LINENO" "${options_values['GET']}" "$NAME_1"

  parse_kernel_config_manager_options '--remove' "$NAME_1"
  assert_equals_helper 'Set remove flag' "$LINENO" "${options_values['REMOVE']}" "$NAME_1"

  parse_kernel_config_manager_options '--list'
  expected=1
  assert_equals_helper 'Set list flag' "$LINENO" "${options_values['LIST']}" "$expected"

  parse_kernel_config_manager_options '--fetch'
  expected=1
  assert_equals_helper 'Set fetch flag' "$LINENO" "${options_values['FETCH']}" "$expected"

  parse_kernel_config_manager_options '--output' "$NAME_1"
  assert_equals_helper 'Set output flag' "$LINENO" "${options_values['OUTPUT']}" "$NAME_1"

  parse_kernel_config_manager_options '--remote' "$NAME_1"
  assert_equals_helper 'Set remote flag' "$LINENO" "${options_values['TARGET']}" 3

  parse_kernel_config_manager_options '--optimize'
  expected=1
  assert_equals_helper 'Set optimize flag' "$LINENO" "${options_values['OPTIMIZE']}" "$expected"
}

invoke_shunit
