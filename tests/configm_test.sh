#!/bin/bash

. ./src/config_manager.sh --source-only
. ./tests/utils --source-only

LS_TITLE="Name\t\tDescription"
COMMAND_MSG_UNKNOWN="Unknown option"
COMMAND_MSG_INVALID_ARG="Invalid argument"

readonly YES_FORCE="1"
readonly NO_FORCE="0"

readonly CONTENT="The content"

readonly NAME_1="test_save_1"
readonly NAME_2="test_save_2"

readonly DESCRIPTION_1="This is the first description"
readonly DESCRIPTION_2="Hi, I'm the second description"

readonly LS_NO_FILES="There's no tracked .config file"

function suite
{
  suite_addTest "execute_config_manager_SAVE_fails_test"
  suite_addTest "save_config_file_CHECK_CONFIG_fails_test"
  suite_addTest "save_config_file_CHECK_CONFIGS_DIRECTORY_test"
  suite_addTest "save_config_file_CHECK_SAVED_CONFIG_FILE_test"
  suite_addTest "save_config_file_CHECK_DESCRIPTION_test"
  suite_addTest "save_config_file_CHECK_GIT_SAVE_SCHEMA_test"
  suite_addTest "save_config_file_CHECK_FORCE_test"
  suite_addTest "list_configs_CHECK_NO_CONFIGS_test"
  suite_addTest "list_configs_OUTPUT_test"
}

function setupConfigm()
{
  local -r test_path="tests/.tmp"
  local -r current_path=$PWD

  rm -rf $test_path

  mkdir -p $test_path
  cd $test_path
  touch .config
  echo $CONTENT > .config
  cd $current_path
}

function tearDownConfigm()
{
  local -r test_path="tests/.tmp"

  rm -rf $test_path
}

function test_expected_string()
{
  local msg="$1"
  local expected="$2"
  local target="$3"

  assertEquals "$msg" "$target" "$expected"
}

function execute_config_manager_SAVE_fails_test
{
  local msg_prefix=" --save"

  ret=$(execute_config_manager --save)
  test_expected_string "$msg_prefix" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save --lala)
  test_expected_string "$msg_prefix --lala" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -n)
  test_expected_string "$msg_prefix -n" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -d)
  test_expected_string "$msg_prefix -d" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -n -d)
  test_expected_string "$msg_prefix -n -d" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -n -lulu)
  test_expected_string "$msg_prefix -n -lulu" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -d)
  test_expected_string "$msg_prefix -d" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -d "lalala and xpto")
  test_expected_string "$msg_prefix -d" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -f)
  test_expected_string "$msg_prefix -f" "$COMMAND_MSG_INVALID_ARG" "$ret"
}

function save_config_file_CHECK_CONFIG_fails_test()
{
  local -r test_path="tests/.tmp"
  local current_path=$PWD
  local force=0
  local ret=0

  # Prepare teste
  setupConfigm

  # Test without config file -> should fail
  cd $test_path
  rm -f .config
  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  assertEquals "No .config file should return ENOENT" "$?" "2"

  # Test with different name
  touch .configuration
  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  assertEquals "Should return ENOENT, because '.config' != '.configuration'" "$?" "2"
  rm .configuration

  cd $current_path
  tearDownConfigm
}

function save_config_file_CHECK_CONFIGS_DIRECTORY_test()
{
  local -r test_path="tests/.tmp"
  local current_path=$PWD
  config_files_path=$current_path/$test_path

  setupConfigm

  # There's no configs yet, initialize it
  cd $test_path
  $(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  cd $current_path

  # Check if all the expected files were created
  assertTrue "The configs dir was not created" '[[ -d $config_files_path/configs ]]'
  assertTrue "The repository configs does not have .git" '[[ -d $config_files_path/configs/.git ]]'
  assertTrue "The metadata dir is not available" '[[ -d $config_files_path/configs/metadata ]]'
  assertTrue "The configs dir is not available" '[[ -d $config_files_path/configs/configs ]]'

  tearDownConfigm
}

function save_config_file_CHECK_SAVED_CONFIG_FILE_test()
{
  local -r test_path="tests/.tmp"
  local current_path=$PWD
  local ret=0
  config_files_path=$current_path/$test_path

  setupConfigm

  # There's no configs yet, initialize it
  cd $test_path
  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  cd $current_path

  assertTrue "Failed to find $NAME_1" '[[ -f $config_files_path/configs/configs/$NAME_1 ]]'
  assertTrue "Failed the metadata related to $NAME_1" '[[ -f $config_files_path/configs/metadata/$NAME_1 ]]'

  cd $test_path
  ret=$(save_config_file $NO_FORCE $NAME_2)
  cd $current_path

  assertTrue "Failed to find $NAME_2" '[[ -f $config_files_path/configs/configs/$NAME_2 ]]'
  assertTrue "Failed the metadata related to $NAME_2" '[[ -f $config_files_path/configs/metadata/$NAME_2 ]]'

  local tmp=$(cat $config_files_path/configs/configs/$NAME_2)
  assertTrue "Content in the file does not match" '[[ $tmp = $CONTENT ]]'

  tearDownConfigm
}

function save_config_file_CHECK_DESCRIPTION_test()
{
  local -r test_path="tests/.tmp"
  local current_path=$PWD
  local ret=0
  config_files_path=$current_path/$test_path

  setupConfigm

  # There's no configs yet, initialize it
  cd $test_path
  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  cd $current_path

  local tmp=$(cat $config_files_path/configs/metadata/$NAME_1)
  assertTrue "The description content for $NAME_1 does not match" '[[ $tmp = $DESCRIPTION_1 ]]'

  cd $test_path
  ret=$(save_config_file $NO_FORCE $NAME_2 "$DESCRIPTION_2")
  cd $current_path

  tmp=$(cat $config_files_path/configs/metadata/$NAME_2)
  assertTrue "The description content for $NAME_2 does not match" '[[ $tmp = $DESCRIPTION_2 ]]'

  tearDownConfigm
}

function save_config_file_CHECK_GIT_SAVE_SCHEMA_test()
{
  local -r test_path="tests/.tmp"
  local current_path=$PWD
  local ret=0
  config_files_path=$current_path/$test_path

  setupConfigm

  # There's no configs yet, initialize it
  cd $test_path
  ret=$(save_config_file $NO_FORCE $NAME_1 "$DESCRIPTION_1")
  ret=$(save_config_file $NO_FORCE $NAME_2 "$DESCRIPTION_2")
  cd "configs"
  ret=$(git rev-list --all --count)
  cd $current_path

  assertTrue "We expected 2 commits, but we got $ret" '[[ $ret = "2" ]]'

  tearDownConfigm
}

function save_config_file_CHECK_FORCE_test()
{
  local -r test_path="tests/.tmp"
  local current_path=$PWD
  local ret=0
  config_files_path=$current_path/$test_path

  setupConfigm

  # There's no configs yet, initialize it
  cd $test_path
  ret=$(save_config_file $YES_FORCE $NAME_2 "$DESCRIPTION_2")
  ret=$(save_config_file $YES_FORCE $NAME_2 "$DESCRIPTION_2")
  cd $current_path
  assertTrue "We expected no changes" '[[ $ret =~ Warning ]]'

  tearDownConfigm
}

function list_configs_CHECK_NO_CONFIGS_test()
{
  local -r test_path="tests/.tmp"
  local current_path=$PWD
  local ret=0
  config_files_path=$current_path/$test_path

  setupConfigm

  # There's no configs yet, initialize it
  ret=$(list_configs)
  assertTrue "We expected no changes" '[[ $ret =~ $LS_NO_FILES ]]'

  tearDownConfigm
}

function list_configs_OUTPUT_test()
{
  local -r test_path="tests/.tmp"
  local current_path=$PWD
  local ret=0
  config_files_path=$current_path/$test_path

  setupConfigm

  # There's no configs yet, initialize it
  cd $test_path
  ret=$(save_config_file $YES_FORCE $NAME_1 "$DESCRIPTION_1")
  ret=$(save_config_file $YES_FORCE $NAME_2 "$DESCRIPTION_2")
  cd $current_path

  # There's no configs yet, initialize it
  ret=$(list_configs)
  assertTrue "We expected 'Name' in the output, but we got $ret" '[[ $ret =~ Name ]]'
  assertTrue "We expected 'Description' in the output, but we got $ret" '[[ $ret =~ Description ]]'
  assertTrue "We expected $NAME_1 in the output, but we got $ret" '[[ $ret =~ $NAME_1 ]]'
  assertTrue "We expected $DESCRIPTION_1 in the output, but we got $ret" '[[ $ret =~ $DESCRIPTION_1 ]]'
  assertTrue "We expected $NAME_2 in the output, but we got $ret" '[[ $ret =~ $NAME_2 ]]'
  assertTrue "We expected $DESCRIPTION_2 in the output, but we got $ret" '[[ $ret =~ $DESCRIPTION_2 ]]'

  tearDownConfigm
}

invoke_shunit
