#!/bin/bash

. ./src/kw_include.sh --source-only
include './src/kwio.sh'
include './src/kwlib.sh'

function main()
{
  cd integration_tests || exit_msg "Could not move to integration tests folder"

  files_list=$(find ./ -name "*_test.sh" | grep --invert-match "/shunit2/\|/*kernel/")
  # Note: Usually we want to use double-quotes on bash variables, however,
  # in this case we want a set of parameters instead of a single one.
  #shellcheck disable=SC2086
  strip_path $files_list

  if [[ "$#" -eq 0 ]]; then
    check_resources
    run_tests
  elif [[ "$1" == "list" ]]; then
    index=0
    for test_name in "${TESTS[@]}"; do
      ((index++))
      say "$index) ${test_name}"
    done
  elif [[ "$1" == "test" ]]; then
    strip_path "${*:2}"
    run_tests
  elif [[ "$1" == "prepare" ]]; then
    if [[ "$#" -gt 1 && ("$2" == "--force-update" || "$2" == "-f") ]]; then
      force_redownload
    else
      check_resources
    fi
  else
    show_help
  fi
}

# Strip path from test names
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

# Download all resources necessary for the integration tests
function check_resources()
{
  if [[ ! -d "./mainline_kernel" ]]; then
    say 'Cloning mainline kernel'
    git clone git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git --depth=1 ./mainline_kernel
    if [[ $? ]]; then
      warning 'Cloning mainline kernel failed, check your internet connection and git configuration.'
    fi
  fi
}

# Run all tests listed in TESTS
function run_tests()
{
  local -i total=${#TESTS[@]}
  local -i success=0
  local -i notfound=0
  local -i fail=0
  local test_failure_list=''

  for current_test in "${TESTS[@]}"; do
    target=$(find ./ -name "*$current_test*.sh")
    if [[ -f "$target" ]]; then
      say "Running test [${current_test}]"
      say "$SEPARATOR"
      (
        export -f include
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
    echo 'No test files.'
  elif [[ "$success" -eq "$total" ]]; then
    success "$SEPARATOR"
    success "Total: $total test file(s)"
    success "Test file(s) SUCCEEDED"
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
      echo
      complain 'Take a look at:'
      IF=' ' read -r -a test_failure_array <<< "$test_failure_list"
      for failed in "${test_failure_array[@]}"; do
        complain "-> $failed"
      done
    fi

    return 1
  fi
}

# Force all resources to be re-downloaded
function force_redownload()
{
  rm -rf "./mainline_kernel"
  check_resources
}

function show_help()
{
  echo "Usage: $0 [help] [list] [test tfile1 tfile2 ... tfilen] [prepare [-f|--force-update]]"
  echo "Run integration tests for kworkflow."
  printf "Example: %s test kw_test\n\n" "$0"
  echo "  help - displays this help message"
  echo "  list - lists all test files under integration_tests/"
  echo "  test - runs the given test files"
  echo "  prepare - prepare environment for tests. -f will update environment, even if already prepared."
}

main "$@"
