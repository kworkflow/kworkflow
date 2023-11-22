#!/bin/bash

. ./src/lib/kw_include.sh --source-only
include './tests/unit/utils.sh'
include './src/lib/kwio.sh'

function show_help()
{
  printf '%s\n' "Usage: $0 [--flags] [help] [list] [test <tfile1> ...]" \
    'Run tests for kworkflow.' \
    "Example: $0 test kw_test" \
    '' \
    'OPTIONS' \
    '  -u, --unit' \
    '         Limit tests to unit tests' \
    '' \
    'COMMANDS' \
    '  help - displays this help message' \
    '  list - lists all test files under tests/' \
    '  test - runs the given test'
}

# Reports tests results.
# Arguments are: $1: # of tests, $2: # of succeeded tests, $3: # of notfound tests and
# $4: # of failed tests
function report_results()
{
  local -i total="$1"
  local -i success="$2"
  local -i notfound="$3"
  local -i fail="$4"
  local test_failure_list="$5"

  if [[ "$total" -eq 0 ]]; then
    printf '%s\n' 'No test files.'
  elif [[ "$success" -eq "$total" ]]; then
    success "$SEPARATOR"
    success "Total: $total test file(s)"
    success 'Test file(s) SUCCEEDED'
  else
    complain "$SEPARATOR"
    complain "Total: $total test file(s)"
    if [[ "$fail" -gt 0 ]]; then
      complain "$fail test file(s) FAILED"
    fi
    if [[ "$notfound" -gt 0 ]]; then
      complain "$notfound test file(s) NOT FOUND"
    fi

    if [[ -n "$test_failure_list" ]]; then
      complain $'\nTake a look at:'
      IF=' ' read -r -a test_failure_array <<< "$test_failure_list"
      for failed in "${test_failure_array[@]}"; do
        complain "-> $failed"
      done
    fi

    return 1
  fi
}

function run_tests()
{
  local -i total=${#TESTS[@]}
  local -i success=0
  local -i notfound=0
  local -i fail=0
  local test_failure_list=''

  for current_test in "${TESTS[@]}"; do
    target=$(find "$TESTS_DIR" -name "${current_test}*.sh" | grep --extended-regexp --invert-match 'samples/.*|/shunit2/')
    if [[ -f "$target" ]]; then
      say "Running test [${current_test}]"
      say "$SEPARATOR"
      (
        init_env
        "$target"
      )
      if [[ "$?" -eq 0 ]]; then
        success+=1
      else
        fail+=1
        test_failure_list="$target $test_failure_list"
      fi
    else
      if [[ -n "$target" ]]; then
        complain "Test file $target not found."
      else
        complain "Test file '$current_test' not found."
      fi
      notfound+=1
    fi
  done
  report_results "$total" "$success" "$notfound" "$fail" "$test_failure_list"
}

declare -a TESTS
function strip_path()
{
  local base
  TESTS=()
  for file in "$@"; do
    base=$(basename "${file}")
    TESTS+=("${base%.*}")
  done
}

declare TESTS_DIR=./tests
if [[ "$1" == '--unit' || "$1" == '-u' ]]; then
  TESTS_DIR=./tests/unit
  shift
fi

check_files="$?"
#shellcheck disable=SC2086
if [[ "$#" -eq 0 ]]; then
  files_list=$(find "$TESTS_DIR" -name '*_test.sh' | grep --extended-regexp --invert-match 'samples/.*|/shunit2/')
  # Note: Usually we want to use double-quotes on bash variables, however,
  # in this case we want a set of parameters instead of a single one.
  strip_path $files_list
  # Set the environment variable LANGUAGE to `en_US.UTF_8` to avoid the host
  # locale settings from interfering in the tests.
  LANGUAGE=en_US.UTF_8 run_tests
elif [[ "$1" == 'list' ]]; then
  index=0
  files_list=$(find "$TESTS_DIR" -name '*_test.sh')
  strip_path $files_list
  for test_name in "${TESTS[@]}"; do
    ((index++))
    say "$index) ${test_name}"
  done
elif [[ "$1" == 'test' ]]; then
  strip_path "${@:2}"
  LANGUAGE=en_US.UTF_8 run_tests
else
  show_help
fi
