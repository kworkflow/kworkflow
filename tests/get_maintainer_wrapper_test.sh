#!/bin/bash

. ./src/get_maintainer_wrapper.sh --source-only
. ./tests/utils --source-only

# TODO: make execute_get_maintainer's tests cover more corner cases?

function suite
{
  suite_addTest "testPrintFileAuthorForFile"
  suite_addTest "testPrintFileAuthorForDir"
  suite_addTest "testGetMaintainers"
}

# The following variables hold the the lines print_files_authors should
# print when given the file samples/print_file_author_test_dir directory
# and samples/print_file_author_test_dir/code1.c file, respectively.
CORRECT_DIR_MSG="=========================================================
MODULE AUTHORS:
code1.c: John Doe <johndoe@community.com>, Caesar Doe <caesar@community.com>, Michael Doe <michael@community.com>
code2.c: Bob Hilson <bob@opensource.com>"
CORRECT_FILE_MSG="=========================================================
MODULE AUTHORS:
code1.c: John Doe <johndoe@community.com>, Caesar Doe <caesar@community.com>, Michael Doe <michael@community.com>"

# The following variables hold the the lines execute_get_maintainer
# should print when given the path tests/.tmp and tests/.tmp/fs,
# respectively.
CORRECT_TMP_MSG="=========================================================
HERE:
Jane Doe <jane@email.com>,kernel@list.org"
CORRECT_TMP_FS_MSG="=========================================================
HERE:
John Doe <john@email.com>,Jane Doe <jane@email.com>,fs@list.org,kernel@list.org"

function setupGetMaintainers
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

function tearDownGetMainteiners
{
  rm -rf "tests/.tmp"
}

function testPrintFileAuthorForFile
{
  local -r ret=$(print_files_authors "tests/samples/print_file_author_test_dir/code1.c")
  if [[ "$ret" != "$CORRECT_FILE_MSG" ]]; then
    local -r expected_prefixed=$(prefix_multiline "$CORRECT_FILE_MSG")
    local -r got_prefixed=$(prefix_multiline "$ret")
    fail "Expecting return:\n$expected_prefixed\nBut got:\n$got_prefixed"
  fi
  true # Reset return value
}

function testPrintFileAuthorForDir
{
  local -r ret=$(print_files_authors "tests/samples/print_file_author_test_dir")
  if [[ "$ret" != "$CORRECT_DIR_MSG" ]]; then
    local -r expected_prefixed=$(prefix_multiline "$CORRECT_DIR_MSG")
    local -r got_prefixed=$(prefix_multiline "$ret")
    fail "Expecting return:\n$expected_prefixed\nBut got:\n$got_prefixed"
  fi
  true # Reset return value
}

function testGetMaintainers
{
  local ret
  local got_prefixed
  local -r expected_tmp_prefixed=$(prefix_multiline "$CORRECT_TMP_MSG")
  local -r expected_tmp_fs_prefixed=$(prefix_multiline "$CORRECT_TMP_FS_MSG")

  setupGetMaintainers

  ret="$(execute_get_maintainer tests/.tmp)"
  if [[ "$ret" != "$CORRECT_TMP_MSG" ]]; then
    got_prefixed=$(prefix_multiline "$ret")
    fail "Expecting return:\n$expected_tmp_prefixed\nBut got:\n$got_prefixed\n(Calling lkr from outside lkr)"
  fi

  cd tests/.tmp
  ret="$(execute_get_maintainer .)"
  if [[ "$ret" != "$CORRECT_TMP_MSG" ]]; then
    got_prefixed=$(prefix_multiline "$ret")
    fail "Expecting return:\n$expected_tmp_prefixed\nBut got:\n$got_prefixed\n(Calling lkr from lkr)"
  fi

  ret="$(execute_get_maintainer fs)"
  if [[ "$ret" != "$CORRECT_TMP_FS_MSG" ]]; then
    got_prefixed=$(prefix_multiline "$ret")
    fail "Expecting return:\n$expected_tmp_fs_prefixed\nBut got:\n$got_prefixed\n(Calling lkr/fs from lkr)"
  fi

  cd fs
  ret="$(execute_get_maintainer ..)"
  if [[ "$ret" != "$CORRECT_TMP_MSG" ]]; then
    got_prefixed=$(prefix_multiline "$ret")
    fail "Expecting return:\n$expected_tmp_prefixed\nBut got:\n$got_prefixed\n(Calling lkr from lkr/fs)"
  fi

  ret="$(execute_get_maintainer .)"
  if [[ "$ret" != "$CORRECT_TMP_FS_MSG" ]]; then
    got_prefixed=$(prefix_multiline "$ret")
    fail "Expecting return:\n$expected_tmp_fs_prefixed\nBut got:\n$got_prefixed\n(Calling lkr/fs from lkr/fs)"
  fi
  cd ../../../

  tearDownGetMainteiners
}

invoke_shunit
