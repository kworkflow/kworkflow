#!/bin/bash

include './src/maintainers.sh'
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

  setupFakeKernelRepo
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
  is_kernel_root "$SHUNIT_TMPDIR"
  [[ "$?" != 0 ]] && fail "Failed to check if a directory is a kernel root."
  true # Reset return value
}

function test_cmd_manager_eacces()
{
  local output
  local ret

  output=$(cmd_manager 'TEST_MODE' 'dmesg -H' 'KW_REDIRECT_MODE' "/an/invalid/path")
  ret="$?"
  assertEquals "($LINENO): We expected 13 as a return" 13 "$ret"
}

function test_cmd_manager_with_iterative_option()
{
  local output
  local fake_file_path="$SHUNIT_TMPDIR/fakefile.log"
  local expected_output

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  touch "$fake_file_path"

  output=$(cmd_manager 'TEST_MODE' 'dmesg -H' 'KW_REDIRECT_MODE' "$fake_file_path")
  expected_output="dmesg -H | tee $fake_file_path"
  assertEquals "($LINENO): " "$expected_output" "$output"
}

function test_cmd_manager_check_silent_option()
{
  local ret

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  ret=$(cmd_manager 'SILENT' 'ls')

  assertFalse "$LINENO: We used SILENT mode, we should not find ls" '[[ $ret =~ ls ]]'
  assertTrue "$LINENO: We expected to find MAINTAINERS" '[[ $ret =~ MAINTAINERS ]]'
  assertTrue "$LINENO: We expected to find CREDITS" '[[ $ret =~ CREDITS ]]'
  assertTrue "$LINENO: We expected to find README" '[[ $ret =~ README ]]'
  assertTrue "$LINENO: We expected to find arch" '[[ $ret =~ arch ]]'
  assertTrue "$LINENO: We expected to find scripts" '[[ $ret =~ scripts ]]'

  # Test command with parameters
  ret=$(cmd_manager 'SILENT' 'help pwd')
  assertTrue "$LINENO: We expected to find -P" '[[ $ret =~ -P ]]'
  assertTrue "$LINENO: We expected to find -L" '[[ $ret =~ -L ]]'
}

# The difference between say, complain, warning, and success it is the color
# because of this we test all of them together
function test_cmd_manager_say_complain_warning_highlight_cmd_success()
{
  local ret

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # Default option
  ret=$(cmd_manager '' ls)
  assertTrue "$LINENO: We expected to find the ls command" '[[ $ret =~ ls ]]'
  assertTrue "$LINENO: We expected to find MAINTAINERS" '[[ $ret =~ MAINTAINERS ]]'
  assertTrue "$LINENO: We expected to find arch" '[[ $ret =~ arch ]]'
  assertTrue "$LINENO: We expected to find scripts" '[[ $ret =~ scripts ]]'

  # TODO: There's an alternative to discover the color?
  ret=$(cmd_manager 'COMPLAIN' 'help pwd')
  assertTrue "($LINENO): We expected to find -P" '[[ $ret =~ -P ]]'
  assertTrue "($LINENO): We expected to find -L" '[[ $ret =~ -L ]]'

  ret=$(cmd_manager 'WARNING' 'ls')
  assertTrue "($LINENO): We expected to find the ls command" '[[ $ret =~ ls ]]'
  assertTrue "($LINENO): We expected to find MAINTAINERS" '[[ $ret =~ MAINTAINERS ]]'
  assertTrue "($LINENO): We expected to find arch" '[[ $ret =~ arch ]]'
  assertTrue "($LINENO): We expected to find scripts" '[[ $ret =~ scripts ]]'

  ret=$(cmd_manager 'SUCCESS' 'ls')
  assertTrue "($LINENO): We expected to find the ls command" '[[ $ret =~ ls ]]'
  assertTrue "($LINENO): We expected to find MAINTAINERS" '[[ $ret =~ MAINTAINERS ]]'
  assertTrue "($LINENO): We expected to find arch" '[[ $ret =~ arch ]]'
  assertTrue "($LINENO): We expected to find scripts" '[[ $ret =~ scripts ]]'

  ret=$(cmd_manager 'HIGHLIGHT_CMD' 'ls')
  assertTrue "($LINENO): We expected to find the ls command" '[[ $ret =~ ls ]]'
  assertTrue "($LINENO): We expected to find MAINTAINERS" '[[ $ret =~ MAINTAINERS ]]'
  assertTrue "($LINENO): We expected to find arch" '[[ $ret =~ arch ]]'
  assertTrue "($LINENO): We expected to find scripts" '[[ $ret =~ scripts ]]'
}

function test_cmd_manager_check_test_mode_option()
{
  local ret

  ret=$(cmd_manager 'TEST_MODE' 'pwd')
  assertEquals "Expected pwd, but we got $ret" "$ret" "pwd"

  ret=$(cmd_manager 'TEST_MODE' 'ls -lah')
  assertEquals "Expected ls -lah, but we got $ret" "$ret" "ls -lah"
}

function test_detect_distro_root_path_only()
{
  local root_path
  local output

  root_path="${SAMPLES_DIR}/os/arch"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  root_path="${SAMPLES_DIR}/os/manjaro"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  root_path="${SAMPLES_DIR}/os/ubuntu"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'debian'

  root_path="${SAMPLES_DIR}/os/debian"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'debian'

  root_path="${SAMPLES_DIR}/os/raspbian"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'debian'

  root_path="${SAMPLES_DIR}/os/fedora"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'fedora'

  root_path="${SAMPLES_DIR}/os/arch-linux-arm"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  root_path="${SAMPLES_DIR}/os/endeavouros"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  root_path="${SAMPLES_DIR}/os/steamos"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  root_path="${SAMPLES_DIR}/os/popos"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'debian'

  root_path="${SAMPLES_DIR}/os/none"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" "$output" 'none'
}

function test_detect_distro_str_check()
{
  local root_path
  local output

  output=$(detect_distro '/' 'arch')
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  output=$(detect_distro '' 'debian')
  assert_equals_helper '' "$LINENO" "$output" 'debian'

  output=$(detect_distro '' 'fedora')
  assert_equals_helper '' "$LINENO" "$output" 'fedora'

  output=$(detect_distro '' 'ubuntu')
  assert_equals_helper '' "$LINENO" "$output" 'none'

  output=$(detect_distro '' 'ubuntu debian')
  assert_equals_helper '' "$LINENO" "$output" 'debian'

  output=$(detect_distro '' 'manjaro steamos lala arch')
  assert_equals_helper '' "$LINENO" "$output" 'arch'
}

function test_detect_distro_from_raw_data()
{
  local root_path_string
  local os_release_data
  local output

  root_path="${SAMPLES_DIR}/os/arch/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  root_path="${SAMPLES_DIR}/os/manjaro/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  root_path="${SAMPLES_DIR}/os/ubuntu/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'debian'

  root_path="${SAMPLES_DIR}/os/debian/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'debian'

  root_path="${SAMPLES_DIR}/os/raspbian/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'debian'

  root_path="${SAMPLES_DIR}/os/fedora/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'fedora'

  root_path="${SAMPLES_DIR}/os/arch-linux-arm/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  root_path="${SAMPLES_DIR}/os/endeavouros/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  root_path="${SAMPLES_DIR}/os/steamos/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'arch'

  root_path="${SAMPLES_DIR}/os/popos/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'debian'

  root_path="${SAMPLES_DIR}/os/none/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" "$output" 'none'
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
  local fake_path="$SHUNIT_TMPDIR/lala/xpto"
  local kernel_path

  mkdir -p "$fake_path"

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
  local ip_port_str="IP:PORT"
  local hostname="kw@remote-machine"
  local a_weird_pattern="IP:PORT:kw@remote-machine"
  local incorrect_str="IPPORT"

  output=$(get_based_on_delimiter "$ip_port_str" ":" 1)
  ret="$?"

  assert_equals_helper 'We should find IP' "$LINENO" "IP" "$output"
  assert_equals_helper 'We expected 0 as a return' "$LINENO" 0 "$ret"

  output=$(get_based_on_delimiter "$ip_port_str" ":" 2)
  ret="$?"

  assert_equals_helper 'We should find PORT' "$LINENO" "PORT" "$output"
  assert_equals_helper 'We expected 0 as a return' "$LINENO" 0 "$ret"

  output=$(get_based_on_delimiter "$ip_port_str" ":" 3)
  ret="$?"
  assert_equals_helper 'We expected the same string' "$LINENO" "$ip_port_str" "$output"
  assert_equals_helper 'We expected 22 as a return' "$LINENO" 22 "$ret"

  output=$(get_based_on_delimiter "$incorrect_str" ":" 1)
  ret="$?"
  assert_equals_helper 'We expected the same string' "$LINENO" "$incorrect_str" "$output"
  assert_equals_helper 'We expected 22 as a return' "$LINENO" 22 "$ret"

  output=$(get_based_on_delimiter "$hostname" "@" 1)
  ret="$?"
  assert_equals_helper 'We used $hostname, @, and 1 args; we should see kw' "$LINENO" "kw" "$output"
  assert_equals_helper 'We expected 0 as a return' "$LINENO" 0 "$ret"

  output=$(get_based_on_delimiter "$hostname" "@" 2)
  ret="$?"
  assert_equals_helper 'We used $hostname, @, and 2 args; we should see remote-machine' "$LINENO" "remote-machine" "$output"
  assert_equals_helper 'We expected 0 as a return' "$LINENO" 0 "$ret"

  output=$(get_based_on_delimiter "$a_weird_pattern" "@" 2)
  ret="$?"
  assert_equals_helper "We used $a_weird_pattern, @, and 2 args; we should see remote-machine" "$LINENO" "remote-machine" "$output"
  assert_equals_helper 'We expected 0 as a return' "$LINENO" 0 "$ret"

  output=$(get_based_on_delimiter "$a_weird_pattern" ":" 2)
  ret="$?"
  assert_equals_helper "We used $a_weird_pattern, :, and 2 args; we should see PORT" "$LINENO" "PORT" "$output"
  assert_equals_helper 'We expected 0 as a return' "$LINENO" 0 "$ret"
}

function test_store_statistics_data()
{
  local fake_day_path="$FAKE_STATISTICS_DAY_PATH"

  setupPatch

  store_statistics_data "$fake_day_path" "test_value" "33"
  stored_value=$(cat "$fake_day_path")
  assertEquals "($LINENO)" "test_value 33" "$stored_value"

  store_statistics_data "/wrong/path" "test_value" "33"
  ret="$?"
  assertEquals "($LINENO)" "22" "$ret"

  store_statistics_data "$fake_day_path" "" "33"
  ret="$?"
  assertEquals "($LINENO)" "22" "$ret"

  store_statistics_data "$fake_day_path"
  ret="$?"
  assertEquals "($LINENO)" "22" "$ret"
}

function test_update_statistics_database()
{
  setupPatch

  update_statistics_database "$TARGET_YEAR_MONTH" "19"
  assertTrue "Statistics update failure" '[[ -f "$FAKE_STATISTICS_MONTH_PATH/19" ]]'

  update_statistics_database "$TARGET_YEAR_MONTH" ""
  ret="$?"
  assertEquals "($LINENO)" "22" "$ret"
}

function test_statistics_manager()
{
  local this_year_and_month
  local today

  this_year_and_month=$(date +%Y/%m)
  today=$(date +%d)

  setupPatch

  output=$(statistics_manager "values" "33")
  assertTrue "($LINENO) - Database folders failures" '[[ -d "$FAKE_STATISTICS_PATH/$this_year_and_month" ]]'

  assertTrue "($LINENO) Database day" '[[ -f "$FAKE_STATISTICS_PATH/$this_year_and_month/$today" ]]'

  stored_value=$(cat "$FAKE_STATISTICS_PATH/$this_year_and_month/$today")
  assertEquals "($LINENO)" "values 33" "$stored_value"

  tearDown

  configurations['disable_statistics_data_track']='yes'
  assertTrue "($LINENO) - Database day" '[[ ! -f "$FAKE_STATISTICS_PATH/$this_year_and_month/$today" ]]'
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
  compare_command_sequence '' "$LINENO" 'expected_output' "$out"
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

  output=$(generate_tarball "$path_to_compress" "$file_path" 'gzip' '' 'SUCCESS')
  assertEquals "($LINENO)" "tar --gzip --directory='$path_to_compress' --create --file='$file_path' ." "$output"

  assertTrue 'Compressed file was not created' "[[ -f $SHUNIT_TMPDIR/compressed.tar.gz ]]"

  output=$(tar -taf "$file_path" | sort -d)
  compare_command_sequence '' "$LINENO" 'expected_files' "$output"

  output=$(generate_tarball "$SHUNIT_TMPDIR/vacation/photos" "$file_path" 'gzip' '' 'SUCCESS')
  assertEquals "($LINENO)" "$SHUNIT_TMPDIR/vacation/photos does not exist" "$output"

  output=$(generate_tarball "$path_to_compress" "$file_path" 'zipper')
  assertEquals "($LINENO)" 'Invalid compression type: zipper' "$output"

  output=$(generate_tarball "$path_to_compress" "$SHUNIT_TMPDIR/file/file" 2> /dev/null)
  assertEquals "($LINENO)" 'Error archiving modules.' "$output"
}

function test_extract_tarball()
{
  local file="$SHUNIT_TMPDIR/compressed.tar.gz"
  local output

  output=$(extract_tarball "$file" "$SHUNIT_TMPDIR" 'gzip' 'SUCCESS')
  assertEquals "($LINENO)" "tar --gzip -xf $file -C $SHUNIT_TMPDIR" "$output"

  assertTrue 'Extraction not done' "[[ -f $SHUNIT_TMPDIR/file1 ]] && [[ -f $SHUNIT_TMPDIR/file2 ]]"

  output=$(extract_tarball "$SHUNIT_TMPDIR/i/dont/exist.tar" "$SHUNIT_TMPDIR")
  assertEquals "($LINENO)" "We could not find $SHUNIT_TMPDIR/i/dont/exist.tar" "$output"

  output=$(extract_tarball "$file" "$SHUNIT_TMPDIR/me/neither")
  assertEquals "($LINENO)" "$SHUNIT_TMPDIR/me/neither does not exist" "$output"

  output=$(extract_tarball "$file" "$SHUNIT_TMPDIR" 'zipper' 'SUCCESS')
  assertEquals "($LINENO)" 'Invalid compression type: zipper' "$output"
}

function test_get_file_name_from_path()
{
  local file_path='documents/file.txt'
  local output
  local expected_result='file.txt'

  output=$(get_file_name_from_path "$file_path")
  assertEquals "($LINENO)" "$expected_result" "$output"

  file_path='/pictures/vacation/path/photo.png'
  expected_result='photo.png'
  output=$(get_file_name_from_path "$file_path")
  assertEquals "($LINENO)" "$expected_result" "$output"

  output=$(get_file_name_from_path '')
  assertEquals "($LINENO) Should have returned an empty string" '' "$output"

  output=$(get_file_name_from_path 'pictures/vacation/')
  assertEquals "($LINENO) Should have returned an empty string" '' "$output"
}

function test_is_inside_work_tree()
{
  local expected
  local output
  local ret

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Unable to move to temp directory"
    return "$ret"
  }

  output=$(is_inside_work_tree 'TEST_MODE')
  expected='git rev-parse --is-inside-work-tree &> /dev/null'
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(is_inside_work_tree '')
  ret="$?"
  assert_equals_helper 'Not in a git work tree, should fail' "$LINENO" 128 "$ret"

  mk_fake_git

  output=$(is_inside_work_tree '')
  ret="$?"
  assert_equals_helper 'Inside a git work tree' "$LINENO" 0 "$ret"

  rm -rf .git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Unable to move back from temp directory"
    return "$ret"
  }
}

function test_get_all_git_config()
{
  local expected
  local output
  local ret

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Unable to move to temp directory"
    return "$ret"
  }

  output=$(get_all_git_config test-config '' 'TEST_MODE' | sort -d)
  expected=$'global\t'"git config --get-all --global test-config"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_all_git_config test-config 'local' 'TEST_MODE')
  expected=$'global\tgit config --get-all --global test-config'
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  # only possible test at a global scope, as we have limited control over
  # the user's system
  output=$(get_all_git_config test-config 'global' 'TEST_MODE')
  expected=$'global\tgit config --get-all --global test-config'
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  mk_fake_git

  output=$(get_all_git_config test-config '' 'TEST_MODE' | sort -d)
  expected=$'global\t'"git config --get-all --global test-config"$'\n'
  expected+=$'local\t'"git config --get-all --local test-config"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_all_git_config test-config 'local' 'TEST_MODE')
  expected=$'local\tgit config --get-all --local test-config'
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_all_git_config test-config 'global' 'TEST_MODE')
  expected=$'global\tgit config --get-all --global test-config'
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_all_git_config user.name)
  expected='Xpto Lala'
  assertTrue "($LINENO): Expected to find user Xpto Lala" '[[ $output =~ $expected ]]'

  output=$(get_all_git_config user.name 'local')
  expected='Xpto Lala'
  assertTrue "($LINENO): Expected to find user Xpto Lala" '[[ $output =~ $expected ]]'

  output=$(get_all_git_config user.email)
  expected='test@email.com'
  assertTrue "($LINENO): Expected to find email test@email.com" '[[ $output =~ $expected ]]'

  output=$(get_all_git_config test.config)
  expected='value'
  assertTrue "($LINENO): Expected to find test value" '[[ $output =~ $expected ]]'

  rm -rf .git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Unable to move back from temp directory"
    return "$ret"
  }
}

function test_get_git_config_regex()
{
  local expected
  local output
  local ret

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Unable to move to temp directory"
    return "$ret"
  }

  output=$(get_git_config_regex test-config '' 'TEST_MODE' | sort -d)
  expected=$'global\t'"git config --get-regexp --global 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_git_config_regex test-config 'local' 'TEST_MODE')
  expected=$'global\t'"git config --get-regexp --global 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  # only possible test with at global scope, as we have limited control over
  # the user's system
  output=$(get_git_config_regex test-config 'global' 'TEST_MODE')
  expected=$'global\t'"git config --get-regexp --global 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  mk_fake_git

  output=$(get_git_config_regex test-config '' 'TEST_MODE' | sort -d)
  expected=$'global\t'"git config --get-regexp --global 'test-config'"$'\n'
  expected+=$'local\t'"git config --get-regexp --local 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_git_config_regex test-config 'local' 'TEST_MODE')
  expected=$'local\t'"git config --get-regexp --local 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_git_config_regex test-config 'global' 'TEST_MODE')
  expected=$'global\t'"git config --get-regexp --global 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_git_config_regex name)
  expected='Xpto Lala'
  assertTrue "($LINENO): Expected to find name" '[[ $output =~ $expected ]]'

  output=$(get_git_config_regex email)
  expected='test@email.com'
  assertTrue "($LINENO): Expected to find email" '[[ $output =~ $expected ]]'

  output=$(get_git_config_regex user)
  expected='name'
  assertTrue "($LINENO): Expected to find name" '[[ $output =~ $expected ]]'
  expected='email'
  assertTrue "($LINENO): Expected to find email" '[[ $output =~ $expected ]]'

  output=$(get_git_config_regex test.config)
  expected='value'
  assertTrue "($LINENO): Expected to find test value" '[[ $output =~ $expected ]]'

  rm -rf .git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Unable to move back from temp directory"
    return "$ret"
  }
}

function test_get_kernel_release()
{
  local output

  function get_current_env_name()
  {
    printf ''
    return 2
  }

  output=$(get_kernel_release 'TEST_MODE')
  assertEquals "($LINENO)" 'make kernelrelease 2> /dev/null' "$output"
}

function test_get_kernel_release_with_env()
{
  local output
  local expected="make kernelrelease O=${KW_CACHE_DIR}/fake_env --silent 2> /dev/null"

  function get_current_env_name()
  {
    printf 'fake_env'
  }

  output=$(get_kernel_release 'TEST_MODE')
  assertEquals "($LINENO)" "$expected" "$output"
}

function test_get_kernel_version()
{
  local output

  function get_current_env_name()
  {
    printf ''
    return 2
  }

  output=$(get_kernel_version 'TEST_MODE')
  assertEquals "($LINENO)" 'make kernelversion 2> /dev/null' "$output"
}

function test_get_kernel_version_with_env()
{
  local output
  local expected="make kernelversion O=${KW_CACHE_DIR}/fake_env --silent 2> /dev/null"

  function get_current_env_name()
  {
    printf 'fake_env'
  }

  output=$(get_kernel_version 'TEST_MODE')
  assertEquals "($LINENO)" "$expected" "$output"
}

function test_get_current_env_name()
{
  local output

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  mk_fake_kw_env

  output=$(get_current_env_name)
  assertEquals "($LINENO)" 0 "$?"
  assertEquals "($LINENO)" 'fake_env' "$output"

  cd "$ORIGINAL_DIR" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

invoke_shunit
