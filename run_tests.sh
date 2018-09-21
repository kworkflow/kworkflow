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

# Reports tests results.
# Arguments are: $1: # of tests, $2: # of succeeded tests, $3: # of notfound tests and
# $4: # of failed tests
function report_results
{
    local -i total=$1
    local -i success=$2
    local -i notfound=$3
    local -i fail=$4

    if [[ $total -eq 0 ]]; then
        echo 'No test files.'
    elif [[ $success -eq $total ]]; then
      success $SEPARATOR
      success "Total: $total test file(s)"
      success "Test(s) SUCCEEDED"
    else
      complain $SEPARATOR
      complain "Total: $total test file(s)"
      if [[ $fail -gt 0 ]]; then
        complain "$fail test(s) FAILED"
      fi
      if [[ $notfound -gt 0 ]]; then
        complain "$notfound test(s) NOT FOUND"
      fi
    fi
}

function run_tests
{
  local -i total=${#TESTS[@]}
  local -i success=0
  local -i notfound=0
  local -i fail=0

  for current_test in "${TESTS[@]}"; do
    if [ -f ./tests/${current_test}.sh ]; then
        say "Running test [${current_test}]"
        say $SEPARATOR
        (
        init_env
        ./tests/${current_test}.sh
        )
        if [[ "$?" -eq 1 ]]; then
            fail+=1
        else
            success+=1
        fi
    else
        complain "Test file ./tests/${current_test}.sh not found."
        notfound+=1
    fi
  done
  report_results $total $success $notfound $fail
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
    say "  ${test_name}"
  done
elif [[ "$1" == "test" ]]; then
  strip_path ${@:2}
  run_tests
else
  show_help
fi
