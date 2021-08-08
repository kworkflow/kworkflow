#!/bin/bash

include './src/get_maintainer_wrapper.sh'
include './src/kwlib.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  KW_DATA_DIR="$SHUNIT_TMPDIR"
  TARGET_YEAR_MONTH="2020/05"
  FAKE_STATISTICS_PATH="$KW_DATA_DIR/statistics"
  FAKE_STATISTICS_MONTH_PATH="$FAKE_STATISTICS_PATH/$TARGET_YEAR_MONTH"
  FAKE_STATISTICS_DAY_PATH="$FAKE_STATISTICS_MONTH_PATH/03"
  ORIGINAL_DIR="$PWD"
}

function setupFakeOSInfo()
{
  mkdir -p "$SHUNIT_TMPDIR"/detect_distro/{arch,manjaro,debian,ubuntu}/etc
  cp -f tests/samples/os/arch/* "$SHUNIT_TMPDIR/detect_distro/arch/etc"
  cp -f tests/samples/os/debian/* "$SHUNIT_TMPDIR/detect_distro/debian/etc"
  cp -f tests/samples/os/manjaro/* "$SHUNIT_TMPDIR/detect_distro/manjaro/etc"
  cp -f tests/samples/os/ubuntu/* "$SHUNIT_TMPDIR/detect_distro/ubuntu/etc"
}

function setupPatch()
{
  mkdir -p "$FAKE_STATISTICS_MONTH_PATH"
  touch "$FAKE_STATISTICS_DAY_PATH"
  cp -f tests/samples/test.patch "$SHUNIT_TMPDIR"
}

function setupFakeKernelRepo()
{
  # This makes $SHUNIT_TMPDIR should mock a kernel tree root. A .git
  # dir is also created inside $SHUNIT_TMPDIR so that get_maintainer.pl thinks
  # it is a git repo. This is done in order to avoid some warnings that
  # get_maintainer.pl prints when no .git is found.
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
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
  cd "$ORIGINAL_DIR" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
  cp -f tests/samples/MAINTAINERS "$SHUNIT_TMPDIR/MAINTAINERS"
  cp -f tests/external/get_maintainer.pl "$SHUNIT_TMPDIR/scripts/"
}

function tearDown()
{
  rm -rf "$FAKE_STATISTICS_PATH"
  cd "$ORIGINAL_DIR" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

function test_is_kernel_root()
{
  setupFakeKernelRepo
  is_kernel_root "$SHUNIT_TMPDIR"
  [[ "$?" != 0 ]] && fail "Failed to check if a directory is a kernel root."
  true # Reset return value
}

function test_cmd_manager_check_silent_option()
{
  setupFakeKernelRepo
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
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
}

# The difference between say, complain, warning, and success it is the color
# because of this we test all of them together
function test_cmdManagerSAY_COMPLAIN_WARNING_SUCCESS()
{
  setupFakeKernelRepo
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
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
}

function test_cmd_manager_check_test_mode_option()
{
  ret=$(cmd_manager TEST_MODE pwd)
  assertEquals "Expected pwd, but we got $ret" "$ret" "pwd"

  ret=$(cmd_manager TEST_MODE ls -lah)
  assertEquals "Expected ls -lah, but we got $ret" "$ret" "ls -lah"
}

function test_detect_distro()
{
  setupFakeOSInfo
  local root_path="$SHUNIT_TMPDIR/detect_distro/arch"
  local ret

  ret=$(detect_distro "$root_path")
  assertEquals "We got $ret." "$ret" "arch"

  root_path="$SHUNIT_TMPDIR/detect_distro/debian"
  ret=$(detect_distro "$root_path")
  assertEquals "We got $ret." "$ret" "debian"

  root_path="$SHUNIT_TMPDIR/detect_distro/manjaro"
  ret=$(detect_distro "$root_path")
  assertEquals "We got $ret." "$ret" "arch"

  root_path="$SHUNIT_TMPDIR/detect_distro/ubuntu"
  ret=$(detect_distro "$root_path")
  assertEquals "We got $ret." "$ret" "debian"

  root_path="$SHUNIT_TMPDIR/detect_distro/debian/etc/lala"
  ret=$(detect_distro "$root_path")
  assertEquals "We got $ret." "$ret" "none"
}

function test_join_path()
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

function test_find_kernel_root()
{
  setupFakeKernelRepo

  local fake_path="$SHUNIT_TMPDIR/lala/xpto"
  mkdir -p "$fake_path"
  local kernel_path

  kernel_path=$(find_kernel_root "$fake_path")
  assertEquals "We expected to find a kernel path" "$kernel_path" "$SHUNIT_TMPDIR"

  kernel_path=$(find_kernel_root "/tmp")
  assertEquals "We should not find a path" "$kernel_path" ""

  kernel_path=$(find_kernel_root "test/")
  assertEquals "We should not find a path" "$kernel_path" ""
}

function test_is_a_patch()
{
  setupPatch
  is_a_patch "$SHUNIT_TMPDIR/test.patch"
  [[ "$?" != 0 ]] && fail "Failed to check if a file is a patch."
  true # Reset return value
}

function test_get_based_on_delimiter()
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

function test_store_statistics_data()
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
}

function test_update_statistics_database()
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
}

function test_statistics_manager()
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

  tearDown

  ID=4
  configurations['disable_statistics_data_track']='yes'
  assertTrue "($ID) Database day" '[[ ! -f "$FAKE_STATISTICS_PATH/$this_year_and_month/$today" ]]'
}

function test_command_exists()
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

function test_exit_msg()
{
  local default_msg='Something went wrong!'
  local custom_msg='Custom error message.'

  # The `:` operation always returns 0, giving us consistent outputs
  output=$(: && exit_msg)
  ret="$?"
  assertEquals "($LINENO) We expected the default msg" "$default_msg" "$output"
  assertEquals "($LINENO) We expected 0 as a return" 0 "$ret"

  output=$(: && exit_msg "$custom_msg")
  ret="$?"
  assertEquals "($LINENO) We expected the custom msg" "$custom_msg" "$output"
  assertEquals "($LINENO) We expected 0 as a return" 0 "$ret"

  output=$(: && exit_msg '' 3)
  ret="$?"
  assertEquals "($LINENO) We expected the default msg" "$default_msg" "$output"
  assertEquals "($LINENO) We expected 3 as a return" 3 "$ret"

  output=$(: && exit_msg "$custom_msg" 3)
  ret="$?"
  assertEquals "($LINENO) We expected the custom msg" "$custom_msg" "$output"
  assertEquals "($LINENO) We expected 3 as a return" 3 "$ret"
}

function test_kw_parse()
{
  local long_options='xpto:,foo,bar'
  local short_options='x:,f,b'
  local out
  local expected

  out="$(kw_parse "$short_options" "$long_options" --xpto 1 --foo --bar biz)"
  expected=" --xpto '1' --foo --bar -- 'biz'"
  assertEquals "($LINENO)" "$expected" "$out"
}

function test_kw_parse_get_errors()
{
  local long_options='xpto:,foo,bar'
  local short_options='x:,f,b'
  local out
  local -a expected_output

  out="$(kw_parse_get_errors 'kw' "$short_options" "$long_options" --fee --bar biz --xpto)"
  expected_output=(
    "kw: unrecognized option '--fee'"
    "kw: option '--xpto' requires an argument"
  )
  compare_command_sequence 'expected_output' "$out" "$LINENO"
}

function test_generate_tarball()
{
  local path_to_compress="$SHUNIT_TMPDIR/files"
  local file_path="$SHUNIT_TMPDIR/compressed.tar.gz"
  local output

  mkdir -p "$SHUNIT_TMPDIR/files"
  touch "$SHUNIT_TMPDIR/files/file1"
  touch "$SHUNIT_TMPDIR/files/file2"

  declare -a expected_files=(
    './'
    './file1'
    './file2'
  )

  output=$(generate_tarball "$path_to_compress" "$file_path" 'gzip' 'SUCCESS')
  assertEquals "($LINENO)" "tar -C $path_to_compress --gzip -cf $file_path ." "$output"

  assertTrue 'Compressed file was not created' "[[ -f $SHUNIT_TMPDIR/compressed.tar.gz ]]"

  output=$(tar -taf "$file_path" | sort -d)
  compare_command_sequence expected_files "$output" "$LINENO"

  output=$(generate_tarball "$SHUNIT_TMPDIR/vacation/photos" "$file_path" 'gzip' 'SUCCESS')
  assertEquals "($LINENO)" "$SHUNIT_TMPDIR/vacation/photos does not exist" "$output"

  output=$(generate_tarball "$path_to_compress" "$file_path" 'zipper')
  assertEquals "($LINENO)" 'Invalid compression type: zipper' "$output"

  output=$(generate_tarball "$path_to_compress" "$SHUNIT_TMPDIR/file/file" 2> /dev/null)
  assertEquals "($LINENO)" 'Error archiving modules.' "$output"
}

invoke_shunit
