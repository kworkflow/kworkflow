#!/bin/bash

. ./src/get_maintainer_wrapper.sh --source-only
. ./tests/utils --source-only

# TODO: unit test for execute_get_maintainer

function suite
{
  suite_addTest "testPrintFileAuthorForFile"
  suite_addTest "testPrintFileAuthorForDir"
}

# Hold the the lines print_files_authors should print when given the file
# samples/print_file_author_test_dir directory and
# samples/print_file_author_test_dir/code1.c file, respectively
CORRECT_DIR_MSG=(
    "========================================================="
    "MODULE AUTHORS:"
    "code1.c: John Doe <johndoe@community.com>, Caesar Doe <caesar@community.com>, Michael Doe <michael@community.com>"
    "code2.c: Bob Hilson <bob@opensource.com>"
)
CORRECT_FILE_MSG=(
    "========================================================="
    "MODULE AUTHORS:"
    "code1.c: John Doe <johndoe@community.com>, Caesar Doe <caesar@community.com>, Michael Doe <michael@community.com>"
)

function testPrintFileAuthorForFile
{
  local counter=0
  while read -r line
  do
    local expected=${CORRECT_FILE_MSG[$counter]}
    if [[ "$line" != "$expected" ]]; then
        fail "Expecting line $counter to be:\n\"$expected\"\nBut got:\n\"$line\""
        true # Reset return value
        return
    fi
    ((counter+=1))
  done < <(print_files_authors "tests/samples/print_file_author_test_dir/code1.c")
  true # Reset return value
}

function testPrintFileAuthorForDir
{
    local counter=0
    while read -r line
    do
      local expected=${CORRECT_DIR_MSG[$counter]}
      if [[ "$line" != "$expected" ]]; then
          fail "Expecting line $counter to be:\n\"$expected\"\nBut got:\n\"$line\""
          true # Reset return value
          return
      fi
      ((counter+=1))
    done < <(print_files_authors "tests/samples/print_file_author_test_dir")
    true # Reset return value
}


invoke_shunit
