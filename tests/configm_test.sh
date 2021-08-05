#!/bin/bash

include './src/config_manager.sh'
include './tests/utils.sh'

COMMAND_MSG_UNKNOWN="Unknown option"
COMMAND_MSG_INVALID_ARG="Invalid argument"
COMMAND_NO_SUCH_FILE="No such file or directory"

readonly YES_FORCE="1"
readonly NO_FORCE="0"

readonly CONTENT="The content"

readonly NAME_1="test_save_1"
readonly NAME_2="test_save_2"

readonly DESCRIPTION_1="This is the first description"
readonly DESCRIPTION_2="Hi, I'm the second description"

function setUp()
{
  local -r current_path="$PWD"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  touch .config
  echo "$CONTENT" > .config
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  mkdir "$SHUNIT_TMPDIR/configs"
  KW_DATA_DIR="$SHUNIT_TMPDIR"
  configs_path="$KW_DATA_DIR/configs"
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
  mkdir -p "$SHUNIT_TMPDIR"
}

function test_execute_config_manager_SAVE_fails()
{
  local msg_prefix=" --save"

  ret=$(execute_config_manager --save)
  assert_equals_helper "$msg_prefix" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save --lala)
  assert_equals_helper "$msg_prefix --lala" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -n)
  assert_equals_helper "$msg_prefix -n" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -d)
  assert_equals_helper "$msg_prefix -d" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -n -d)
  assert_equals_helper "$msg_prefix -n -d" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -n -lulu)
  assert_equals_helper "$msg_prefix -n -lulu" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -d)
  assert_equals_helper "$msg_prefix -d" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -d "lalala and xpto")
  assert_equals_helper "$msg_prefix -d" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --save -f)
  assert_equals_helper "$msg_prefix -f" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"
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
  assertTrue "$LINENO: The repository configs does not have .git" '[[ -d $configs_path/.git ]]'
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

function test_save_config_file_check_git_save_schema()
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
  cd "configs" || {
    fail "($LINENO) It was not possible to move to configs directory"
    return
  }
  ret=$(git rev-list --all --count)
  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from configs directory"
    return
  }

  assertTrue "$LINENO: We expected 2 commits, but we got $ret" '[[ $ret = "2" ]]'
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

function test_execute_config_manager_get_config_invalid_option()
{
  local msg_prefix=" --get"

  ret=$(execute_config_manager --get)
  assert_equals_helper "$msg_prefix" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager -get)
  assert_equals_helper "$msg_prefix" "$LINENO" "$COMMAND_MSG_UNKNOWN" "$ret"

  ret=$(execute_config_manager --get something_wrong)
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
  output=$(echo 'y' | get_config "$NAME_1")
  compare_command_sequence expected_output[@] "$output" "$LINENO"

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

function test_execute_config_manager_remove_that_should_fail()
{
  local msg_prefix=" -rm"

  ret=$(execute_config_manager -rm)
  assert_equals_helper "$msg_prefix" "$LINENO" "$COMMAND_MSG_INVALID_ARG" "$ret"

  ret=$(execute_config_manager --rm)
  assert_equals_helper "$msg_prefix" "$LINENO" "$COMMAND_MSG_UNKNOWN" "$ret"

  ret=$(execute_config_manager -rm something_wrong)
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
  ret=$(find configs/configs -type f -mindepth 1 | wc -l)
  # Case 1: We should have two files
  assertTrue "We expected , 2 files but got $ret" '[[ $ret = "2" ]]'

  # Case 2: Remove one config file
  remove_config "$NAME_1" 1 > /dev/null 2>&1
  ret=$(find configs/configs -type f -mindepth 1 | wc -l)
  assertTrue "$LINENO: We expected , 1 files but got $ret" '[[ $ret = "1" ]]'

  # Case 2: Remove all config files
  remove_config "$NAME_2" 1 > /dev/null 2>&1
  assertTrue "$LINENO: We expected no file related to config" '[[ ! -f configs/configs ]]'

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

invoke_shunit
