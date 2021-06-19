#!/bin/bash

include './src/get_maintainer_wrapper.sh'
include './src/kwlib.sh'
include './tests/utils.sh'

function suite()
{
  suite_addTest "is_kernel_root_Test"
  suite_addTest "cmd_manager_check_test_mode_option_Test"
  suite_addTest "cmd_manager_check_silent_option_Test"
  suite_addTest "cmdManagerSAY_COMPLAIN_WARNING_SUCCESS_Test"
  suite_addTest "detect_distro_Test"
  suite_addTest "join_path_Test"
  suite_addTest "find_kernel_root_Test"
  suite_addTest "is_a_patch_Test"
  suite_addTest "get_based_on_delimiter_Test"
  suite_addTest "store_statistics_data_Test"
  suite_addTest "update_statistics_database_Test"
  suite_addTest "statistics_manager_Test"
  suite_addTest "command_exists_Test"
}

KW_DATA_DIR="tests/.tmp"
TARGET_YEAR_MONTH="2020/05"
FAKE_STATISTICS_PATH="$KW_DATA_DIR/statistics"
FAKE_STATISTICS_MONTH_PATH="$FAKE_STATISTICS_PATH/$TARGET_YEAR_MONTH"
FAKE_STATISTICS_DAY_PATH="$FAKE_STATISTICS_MONTH_PATH/03"

function setupFakeOSInfo()
{
  mkdir -p tests/.tmp/detect_distro/{arch,manjaro,debian,ubuntu}/etc
  cp -f tests/samples/os/arch/* tests/.tmp/detect_distro/arch/etc
  cp -f tests/samples/os/debian/* tests/.tmp/detect_distro/debian/etc
  cp -f tests/samples/os/manjaro/* tests/.tmp/detect_distro/manjaro/etc
  cp -f tests/samples/os/ubuntu/* tests/.tmp/detect_distro/ubuntu/etc
}

function setupPatch()
{
  mkdir -p "$FAKE_STATISTICS_MONTH_PATH"
  touch "$FAKE_STATISTICS_DAY_PATH"
  cp -f tests/samples/test.patch tests/.tmp/
}

function setupFakeKernelRepo()
{
  # This creates tests/.tmp which should mock a kernel tree root. A .git
  # dir is also created inside tests/.tmp so that get_maintainer.pl thinks
  # it is a git repo. This is done in order to avoid some warnings that
  # get_maintainer.pl prints when no .git is found.
  mkdir -p "tests/.tmp"
  cd "tests/.tmp"
  touch "COPYING"
  touch "CREDITS"
  touch "Kbuild"
  touch "Makefile"
  touch "README"
  mkdir -p "Documentation"
  mkdir -p "arch"
  mkdir -p "include"
  mkdir -p "drivers"
  mkdir -p "fs"
  mkdir -p "init"
  mkdir -p "ipc"
  mkdir -p "kernel"
  mkdir -p "lib"
  mkdir -p "scripts"
  mkdir -p ".git"
  cd ../../
  cp -f tests/samples/MAINTAINERS tests/.tmp/MAINTAINERS
  cp -f tests/external/get_maintainer.pl tests/.tmp/scripts/
}

function tearDownSetup()
{
  rm -rf "$FAKE_STATISTICS_PATH"
}

function is_kernel_root_Test()
{
  setupFakeKernelRepo
  is_kernel_root "tests/.tmp"
  [[ "$?" != 0 ]] && fail "Failed to check if a directory is a kernel root."
  tearDownSetup
  true # Reset return value
}

function cmd_manager_check_silent_option_Test()
{
  setupFakeKernelRepo
  cd "tests/.tmp"
  ret=$(cmd_manager SILENT ls)

  assertFalse "We used SILENT mode, we should not find ls" '[[ $ret =~ ls ]]'
  assertTrue "We expected to find MAINTAINERS" '[[ $ret =~ MAINTAINERS ]]'
  assertTrue "We expected to find CREDITS" '[[ $ret =~ CREDITS ]]'
  assertTrue "We expected to find README" '[[ $ret =~ README ]]'
  assertTrue "We expected to find arch" '[[ $ret =~ arch ]]'
  assertTrue "We expected to find scripts" '[[ $ret =~ scripts ]]'

  # Test command with parameters
  ret=$(cmd_manager SILENT help pwd)
  assertTrue "We expected to find -P" '[[ $ret =~ -P ]]'
  assertTrue "We expected to find -L" '[[ $ret =~ -L ]]'

  cd ../../
  tearDownSetup
}

# The difference between say, complain, warning, and success it is the color
# because of this we test all of them together
function cmdManagerSAY_COMPLAIN_WARNING_SUCCESS_Test()
{
  setupFakeKernelRepo
  cd "tests/.tmp"
  ret=$(cmd_manager ls)

  assertTrue "We expected to find the ls command" '[[ $ret =~ ls ]]'
  assertTrue "We expected to find MAINTAINERS" '[[ $ret =~ MAINTAINERS ]]'
  assertTrue "We expected to find arch" '[[ $ret =~ arch ]]'
  assertTrue "We expected to find scripts" '[[ $ret =~ scripts ]]'

  # TODO: There's an alternative to discover the color?
  ret=$(cmd_manager COMPLAIN help pwd)
  assertTrue "We expected to find -P" '[[ $ret =~ -P ]]'
  assertTrue "We expected to find -L" '[[ $ret =~ -L ]]'

  ret=$(cmd_manager WARNING ls)
  assertTrue "We expected to find the ls command" '[[ $ret =~ ls ]]'
  assertTrue "We expected to find MAINTAINERS" '[[ $ret =~ MAINTAINERS ]]'
  assertTrue "We expected to find arch" '[[ $ret =~ arch ]]'
  assertTrue "We expected to find scripts" '[[ $ret =~ scripts ]]'

  ret=$(cmd_manager SUCCESS ls)
  assertTrue "We expected to find the ls command" '[[ $ret =~ ls ]]'
  assertTrue "We expected to find MAINTAINERS" '[[ $ret =~ MAINTAINERS ]]'
  assertTrue "We expected to find arch" '[[ $ret =~ arch ]]'
  assertTrue "We expected to find scripts" '[[ $ret =~ scripts ]]'

  cd ../../
  tearDownSetup
}

function cmd_manager_check_test_mode_option_Test()
{
  ret=$(cmd_manager TEST_MODE pwd)
  assertEquals "Expected pwd, but we got $ret" "$ret" "pwd"

  ret=$(cmd_manager TEST_MODE ls -lah)
  assertEquals "Expected ls -lah, but we got $ret" "$ret" "ls -lah"
}

function detect_distro_Test()
{
  setupFakeOSInfo
  local root_path="tests/.tmp/detect_distro/arch"
  local ret

  ret=$(detect_distro $root_path)
  assertEquals "We got $ret." "$ret" "arch"

  root_path="tests/.tmp/detect_distro/debian"
  ret=$(detect_distro $root_path)
  assertEquals "We got $ret." "$ret" "debian"

  root_path="tests/.tmp/detect_distro/manjaro"
  ret=$(detect_distro $root_path)
  assertEquals "We got $ret." "$ret" "arch"

  root_path="tests/.tmp/detect_distro/ubuntu"
  ret=$(detect_distro $root_path)
  assertEquals "We got $ret." "$ret" "debian"

  root_path="tests/.tmp/detect_distro/debian/etc/lala"
  ret=$(detect_distro $root_path)
  assertEquals "We got $ret." "$ret" "none"
}

function join_path_Test()
{
  local base="/lala/xpto"
  local ret

  ret=$(join_path "/lala" "///xpto")
  assertEquals "Expect /lala/xpto" "$ret" "$base"

  ret=$(join_path "/lala" "/xpto////")
  assertEquals "Expect /lala/xpto" "$ret" "$base"

  ret=$(join_path "/lala" "////xpto////")
  assertEquals "Expect /lala/xpto" "$ret" "$base"

  ret=$(join_path "/lala" "//test///xpto////")
  assertEquals "Expect /lala/test/xpto" "$ret" "/lala/test/xpto"

  ret=$(join_path "/lala/")
  assertEquals "Expect /lala/" "$ret" "/lala/"
}

function find_kernel_root_Test()
{
  setupFakeKernelRepo

  local fake_path="tests/.tmp/lala/xpto"
  mkdir -p $fake_path
  local kernel_path

  kernel_path=$(find_kernel_root $fake_path)
  assertEquals "We expected to find a kernel path" "$kernel_path" "tests/.tmp"

  kernel_path=$(find_kernel_root "/tmp")
  assertEquals "We should not find a path" "$kernel_path" ""

  kernel_path=$(find_kernel_root "test/")
  assertEquals "We should not find a path" "$kernel_path" ""

  tearDownSetup
}

function is_a_patch_Test()
{
  setupPatch
  is_a_patch "tests/.tmp/test.patch"
  [[ "$?" != 0 ]] && fail "Failed to check if a file is a patch."
  tearDownSetup
  true # Reset return value
}

function get_based_on_delimiter_Test()
{
  local ID
  local ip_port_str="IP:PORT"
  local hostname="kw@remote-machine"
  local a_weird_pattern="IP:PORT:kw@remote-machine"
  local incorrect_str="IPPORT"

  ID=1
  output=$(get_based_on_delimiter "$ip_port_str" ":" 1)
  ret="$?"

  assertEquals "$ID - We should find IP" "IP" "$output"
  assertEquals "$ID - We expected 0 as a return" 0 "$ret"

  ID=2
  output=$(get_based_on_delimiter "$ip_port_str" ":" 2)
  ret="$?"

  assertEquals "$ID - We should find PORT" "PORT" "$output"
  assertEquals "$ID - We expected 0 as a return" 0 "$ret"

  ID=3
  output=$(get_based_on_delimiter "$ip_port_str" ":" 3)
  ret="$?"
  assertEquals "$ID - We expected the same string" "$ip_port_str" "$output"
  assertEquals "$ID - We expected 22 as a return" 22 "$ret"

  ID=4
  output=$(get_based_on_delimiter "$incorrect_str" ":" 1)
  ret="$?"
  assertEquals "$ID - We expected the same string" "$incorrect_str" "$output"
  assertEquals "$ID - We expected 22 as a return" 22 "$ret"

  ID=5
  output=$(get_based_on_delimiter "$hostname" "@" 1)
  ret="$?"
  assertEquals "$ID - We used $hostname, @, and 1 args; we should see kw" "kw" "$output"
  assertEquals "$ID - We expected 0 as a return" 0 "$ret"

  ID=6
  output=$(get_based_on_delimiter "$hostname" "@" 2)
  ret="$?"
  assertEquals "$ID - We used $hostname, @, and 2 args; we should see remote-machine" "remote-machine" "$output"
  assertEquals "$ID - We expected 0 as a return" 0 "$ret"

  ID=7
  output=$(get_based_on_delimiter "$a_weird_pattern" "@" 2)
  ret="$?"
  assertEquals "$ID - We used $a_weird_pattern, @, and 2 args; we should see remote-machine" "remote-machine" "$output"
  assertEquals "$ID - We expected 0 as a return" 0 "$ret"

  output=$(get_based_on_delimiter "$a_weird_pattern" ":" 2)
  ret="$?"
  assertEquals "$ID - We used $a_weird_pattern, :, and 2 args; we should see PORT" "PORT" "$output"
  assertEquals "$ID - We expected 0 as a return" 0 "$ret"

}

function store_statistics_data_Test()
{
  local ID
  local fake_day_path="$FAKE_STATISTICS_DAY_PATH"

  setupPatch

  ID=1
  store_statistics_data "$fake_day_path" "test_value" "33"
  stored_value=$(cat "$fake_day_path")
  assertEquals "($ID) - " "test_value 33" "$stored_value"

  ID=2
  store_statistics_data "/wrong/path" "test_value" "33"
  ret="$?"
  assertEquals "($ID) - " "22" "$ret"

  ID=3
  store_statistics_data "$fake_day_path" "" "33"
  ret="$?"
  assertEquals "($ID) - " "22" "$ret"

  ID=4
  store_statistics_data "$fake_day_path"
  ret="$?"
  assertEquals "($ID) - " "22" "$ret"

  tearDownSetup
}

function update_statistics_database_Test()
{
  local ID

  setupPatch

  ID=1
  update_statistics_database "$TARGET_YEAR_MONTH" "19"
  assertTrue "Statistics update failure" '[[ -f "$FAKE_STATISTICS_MONTH_PATH/19" ]]'

  ID=2
  update_statistics_database "$TARGET_YEAR_MONTH" ""
  ret="$?"
  assertEquals "($ID) - " "22" "$ret"

  tearDownSetup
}

function statistics_manager_Test()
{
  local ID
  local this_year_and_month
  local today

  this_year_and_month=$(date +%Y/%m)
  today=$(date +%d)

  setupPatch

  ID=1
  output=$(statistics_manager "values" "33")
  assertTrue "($ID) Database folders failures" '[[ -d "$FAKE_STATISTICS_PATH/$this_year_and_month" ]]'

  ID=2
  assertTrue "($ID) Database day" '[[ -f "$FAKE_STATISTICS_PATH/$this_year_and_month/$today" ]]'

  ID=3
  stored_value=$(cat "$FAKE_STATISTICS_PATH/$this_year_and_month/$today")
  assertEquals "($ID) - " "values 33" "$stored_value"

  tearDownSetup

  ID=4
  configurations['disable_statistics_data_track']='yes'
  assertTrue "($ID) Database day" '[[ ! -f "$FAKE_STATISTICS_PATH/$this_year_and_month/$today" ]]'
}

function command_exists_Test()
{
  local fake_command="a-non-existent-command -p"
  local real_command="mkdir"

  output=$(command_exists "$fake_command")
  ret="$?"
  assertEquals "$LINENO - We expected 22 as a return" 22 "$ret"

  output=$(command_exists "$real_command")
  ret="$?"
  assertEquals "$LINENO - We expected 0 as a return" 0 "$ret"
}

invoke_shunit
