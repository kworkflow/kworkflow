#!/bin/bash

. ./src/get_maintainer_wrapper.sh --source-only
. ./tests/utils --source-only

# TODO: unit test for execute_get_maintainer

function suite
{
  suite_addTest "testPrintFileAuthorForFile"
  suite_addTest "testPrintFileAuthorForDir"
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

invoke_shunit
