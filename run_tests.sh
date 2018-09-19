#!/bin/bash

. ./tests/utils --source-only
. ./src/miscellaneous.sh --source-only

function show_help
{
  echo "Usage: $0 [help] [list] [test tfile1 tfile2 ... tfilen]"
  echo "Run tests for kworkflow."
  printf "Example: $0 test kw_test\n\n"
  echo "  help - displays this help message"
  echo "  list - lists all test files under tests/"
  echo "  test - runs the given test files"
}

function run_tests
{
  local rc=0
  for current_test in "${TESTS[@]}"; do
    echo "Running test [${current_test}]"
    ./tests/${current_test}.sh
    if [[ "$?" -eq 1 ]]; then
      rc=1
    fi
  done
  if [[ "$rc" -ne 0 ]]; then
    complain "Some test(s) FAILED"
  fi
}

declare -a TESTS
function strip_path
{
  TESTS=( )
  for file in "$@"; do
    local base=$(basename ${file})
    TESTS+=("${base%.*}")
  done
}

if [[ "$#" -eq 0 ]]; then
  strip_path tests/*.sh
  run_tests
elif [[ "$1" == "list" ]]; then
  strip_path tests/*.sh
  for test_name in "${TESTS[@]}"; do
    echo "${test_name}"
  done
elif [[ "$1" == "test" ]]; then
  strip_path ${@:2}
  run_tests
else
  show_help
fi
