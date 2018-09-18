#!/bin/bash

. ./tests/utils --source-only
. ./src/miscellaneous.sh --source-only

function run_tests
{
  local rc=0
  for t in "$@"; do
    echo "Running test file $t"
    ./$t
    if [[ "$?" -eq 1 ]]; then
      rc=1
    fi
  done
  if [[ "$rc" -ne 0 ]]; then
    complain "Some test(s) FAILED"
  fi
}

if [[ "$#" -eq 0 ]]; then
  run_tests tests/*.sh
elif [[ "$1" == "list" ]]; then
  for t in tests/*.sh; do
    echo "$t"
  done
elif [[ "$1" == "test" ]]; then
  run_tests ${@:2}
else
  echo "Usage: $0 [help] [list] [test tfile1 tfile2 ... tfilen]"
  echo "Run tests for kworkflow."
  printf "Example: $0 test tests/kw_test.sh\n\n"
  echo "  help - displays this help message"
  echo "  list - lists all test files under tests/"
  echo "  test - runs the given test files"
fi
