#!/bin/bash

. ./src/get_maintainer_wrapper.sh --source-only
. ./src/kwlib.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "linuxRootCheckTest"
  suite_addTest "cmdManagerTESTMODETest"
  suite_addTest "cmdManagerSILENTTest"
  suite_addTest "cmdManagerSAY_COMPLAIN_WARNING_SUCCESS_Test"
  suite_addTest "detectDistroTest"
  suite_addTest "joinPathTest"
  suite_addTest "findKernelRootTest"
  suite_addTest "isAPatchTest"
  suite_addTest "get_from_colon_Test"
}

function setupFakeOSInfo
{
  mkdir -p tests/.tmp/detect_distro/{arch,debian}/etc
  cp -f tests/samples/os/arch/* tests/.tmp/detect_distro/arch/etc
  cp -f tests/samples/os/debian/* tests/.tmp/detect_distro/debian/etc
}

function setupPatch
{
  mkdir -p "tests/.tmp"
  cp -f tests/samples/test.patch tests/.tmp/
}

function setupFakeKernelRepo
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

function tearDownSetup
{
  rm -rf "tests/.tmp"
}

function linuxRootCheckTest
{
  setupFakeKernelRepo
  is_kernel_root "tests/.tmp"
  [[ "$?" != 0 ]] && fail "Failed to check if a directory is a kernel root."
  tearDownSetup
  true # Reset return value
}

function cmdManagerSILENTTest
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
  ret=$(cmd_manager SILENT pwd --help)
  assertTrue "We expected to find -P" '[[ $ret =~ -P ]]'
  assertTrue "We expected to find -L" '[[ $ret =~ -L ]]'

  cd ../../
  tearDownSetup
}

# The difference between say, complain, warning, and success it is the color
# because of this we test all of them together
function cmdManagerSAY_COMPLAIN_WARNING_SUCCESS_Test
{
  setupFakeKernelRepo
  cd "tests/.tmp"
  ret=$(cmd_manager ls)

  assertTrue "We expected to find the ls command" '[[ $ret =~ ls ]]'
  assertTrue "We expected to find MAINTAINERS" '[[ $ret =~ MAINTAINERS ]]'
  assertTrue "We expected to find arch" '[[ $ret =~ arch ]]'
  assertTrue "We expected to find scripts" '[[ $ret =~ scripts ]]'

  # TODO: There's an alternative to discover the color?
  ret=$(cmd_manager COMPLAIN pwd --help)
  assertTrue "We expected to find the ls command" '[[ $ret =~ --help ]]'
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

function cmdManagerTESTMODETest
{
  ret=$(cmd_manager TEST_MODE pwd)
  assertEquals "Expected pwd, but we got $ret" "$ret" "pwd"

  ret=$(cmd_manager TEST_MODE ls -lah)
  assertEquals "Expected ls -lah, but we got $ret" "$ret" "ls -lah"
}

function detectDistroTest
{
  setupFakeOSInfo
  local root_path="tests/.tmp/detect_distro/arch"
  local ret=$(detect_distro $root_path)

  assertEquals "We got $ret." "$ret" "arch"

  root_path="tests/.tmp/detect_distro/debian"
  ret=$(detect_distro $root_path)
  assertEquals "We got $ret." "$ret" "debian"

  root_path="tests/.tmp/detect_distro/debian/etc/lala"
  ret=$(detect_distro $root_path)
  assertEquals "We got $ret." "$ret" "none"
}

function joinPathTest
{
  local base="/lala/xpto"
  local ret=$(join_path "/lala" "///xpto")
 
  assertEquals "Expect /lala/xpto" "$ret" "$base"

  ret=$(join_path "/lala" "/xpto////")
  assertEquals "Expect /lala/xpto" "$ret" "$base"

  ret=$(join_path "/lala" "////xpto////")
  assertEquals "Expect /lala/xpto" "$ret" "$base"

  ret=$(join_path "/lala/")
  assertEquals "Expect /lala/" "$ret" "/lala/"
}

function findKernelRootTest
{
  setupFakeKernelRepo

  local fake_path="tests/.tmp/lala/xpto"
  mkdir -p $fake_path
  local kernel_path=$(find_kernel_root $fake_path)

  assertEquals "We expected to find a kernel path" "$kernel_path" "tests/.tmp"

  kernel_path=$(find_kernel_root "/tmp")
  assertEquals "We should not find a path" "$kernel_path" ""

  kernel_path=$(find_kernel_root "test/")
  assertEquals "We should not find a path" "$kernel_path" ""

  tearDownSetup
}

function isAPatchTest
{
  setupPatch
  is_a_patch "tests/.tmp/test.patch"
  [[ "$?" != 0 ]] && fail "Failed to check if a file is a patch."
  tearDownSetup
  true # Reset return value
}

function get_from_colon_Test
{
  local correct_str="IP:PORT"
  local incorrect_str="IPPORT"

  output=$(get_from_colon "$correct_str" 1)
  ret="$?"

  assertEquals "We should find IP" "IP" "$output"
  assertEquals "We expected 0 as a return" 0 "$ret"

  output=$(get_from_colon "$correct_str" 2)
  ret="$?"

  assertEquals "We should find PORT" "PORT" "$output"
  assertEquals "We expected 0 as a return" 0 "$ret"

  output=$(get_from_colon "$correct_str" 3)
  ret="$?"
  assertEquals "We expected an empty string" "" "$output"
  assertEquals "We expected 22 as a return" 22 "$ret"

  output=$(get_from_colon "$incorrect_str" 1)
  ret="$?"
  assertEquals "We expected an empty string" "" "$output"
  assertEquals "We expected 22 as a return" 22 "$ret"
}

invoke_shunit
