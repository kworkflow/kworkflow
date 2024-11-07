#!/usr/bin/env bash

. ./src/lib/kw_include.sh --source-only
include './tests/unit/utils.sh'
include './tests/integration/utils.sh'
include './src/lib/kwio.sh'

declare -a TESTS
declare TESTS_DIR=''
declare CLEAR_INTEGRATION_CACHE=0
declare CLEAR_UNIT_CACHE=0
declare VERBOSE=0

function show_help()
{
  printf '%s\n' "Usage: $0 [--flags] [help] [list] [test <tfile1> ...]" \
    'Run tests for kworkflow.' \
    "Example: $0 test kw_test" \
    '' \
    'OPTIONS' \
    '  -i, --integration' \
    '         Limit tests to integration tests' \
    '  -u, --unit' \
    '         Limit tests to unit tests' \
    '  -v, --verbose' \
    '         Increase verbosity of the output' \
    '' \
    'COMMANDS' \
    '  clear-cache - clears tests cache' \
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

    return 1 # EPERM
  fi
}

function run_tests()
{
  local -i total=${#TESTS[@]}
  local -i success=0
  local -i notfound=0
  local -i fail=0
  local test_failure_list=''
  local test_dir
  local current_test
  local target

  for target in "${TESTS[@]}"; do
    if [[ -f "$target" ]]; then

      test_dir=$(dirname "${target}")

      # Format the test name to be displayed in the output.
      current_test="$(basename "$test_dir")/$(basename "$target" | sed 's/.sh//')"

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

  if [[ "$test_dir" =~ '/integration' && "$VERBOSE" -eq 1 ]]; then
    say '' # add new line after the last "OK"
    say 'Tearing down containers used in integration tests...'
    teardown_containers
    say ''
  fi

  report_results "$total" "$success" "$notfound" "$fail" "$test_failure_list"
}

function clear_unit_tests_cache()
{
  say 'Unit tests: nothing cached to clear.'
}

function clear_integration_tests_cache()
{
  say 'Integration tests: cleaning cache...'
  teardown_container_environment "$@"
}

function set_tests()
{
  local file
  TESTS=()
  for file in "$@"; do
    if [[ "$file" == *'_test.sh' ]]; then
      TESTS+=("$file")
    fi
  done
}

function list_tests()
{
  local index
  local files_list

  index=0
  files_list=$(find "$TESTS_DIR" -name '*_test.sh')

  # shellcheck disable=SC2086
  set_tests $files_list

  for test_name in "${TESTS[@]}"; do
    ((index++))
    say "$index) ${test_name}"
  done
}

function run_all_tests()
{
  local files_list

  files_list=$(find "$TESTS_DIR" -name '*_test.sh' | grep --extended-regexp --invert-match 'samples/.*|/shunit2/')

  # Note: Usually we want to use double-quotes on bash variables, however,
  # in this case we want a set of parameters instead of a single one.
  # shellcheck disable=SC2086
  set_tests $files_list

  # Set the environment variable LANGUAGE to `en_US.UTF_8` to avoid the host
  # locale settings from interfering in the tests.
  LANGUAGE=en_US.UTF_8 run_tests
}

function run_user_provided_tests()
{
  local regex
  local files_list

  # Create a regular expression from the provided arguments. Replace all spaces
  # in the arguments with '|', creating an expression that matches any of the
  # provided terms. For example, if the arguments are "test1 test2 test3", the
  # resulting expression will be "(test1|test2|test3)".
  regex="($(sed 's/ /|/g' <<< "${@}"))"
  files_list=$(find "$TESTS_DIR" | grep --perl-regexp "$regex" | grep --extended-regexp --invert-match 'samples/.*|/shunit2/')

  # shellcheck disable=SC2086
  set_tests $files_list
  LANGUAGE=en_US.UTF_8 run_tests
}

# Parse flag
while [[ "$1" =~ ^- && ! "$1" == '--' ]]; do
  case "$1" in
    --unit | -u)
      TESTS_DIR='./tests/unit'
      CLEAR_UNIT_CACHE=1
      shift
      ;;
    --integration | -i)
      TESTS_DIR='./tests/integration'
      CLEAR_INTEGRATION_CACHE=1
      shift
      ;;
    --all | -a)
      TESTS_DIR='./tests'
      shift
      ;;
    --verbose | -v)
      VERBOSE=1
      export VERBOSE
      shift
      ;;
    *)
      show_help
      exit 1
      ;;
  esac
done

action=${1:-all}
shift

# Default to unit tests if no specific type is provided
if [[ -z "$TESTS_DIR" ]]; then
  TESTS_DIR='./tests/unit'
fi

case "$action" in
  all)
    run_all_tests
    ;;
  list)
    list_tests
    ;;
  test)
    run_user_provided_tests "$@"
    ;;
  clear-cache)
    [[ "$CLEAR_UNIT_CACHE" -eq 1 ]] && clear_unit_tests_cache "$@"
    [[ "$CLEAR_INTEGRATION_CACHE" -eq 1 ]] && clear_integration_tests_cache "$@"
    ;;
  *)
    show_help
    ;;
esac
