#!/bin/bash

. ./tests/utils --source-only
. ./src/kwio.sh --source-only

declare -r PATH_TO_TESTS_EXTERNALS="tests/external"

function show_help
{
  echo "Usage: $0 [help] [list] [test tfile1 tfile2 ... tfilen] [prepare [-f|--force-update]]"
  echo "Run tests for kworkflow."
  printf "Example: $0 test kw_test\n\n"
  echo "  help - displays this help message"
  echo "  list - lists all test files under tests/"
  echo "  test - runs the given test files"
  echo "  prepare - prepare environment for tests. -f will update environment, even if already prepared."
}

function download_stuff()
{
  local URL="$1"
  local PATH_TO="$2"
  local OVERWRITE="$3"

  if "$OVERWRITE"; then
      ret=$(wget -N "$URL" -P "$PATH_TO")
  else
      ret=$(wget -nc "$URL" -P "$PATH_TO")
  fi

  if [[ "$?" != 0 ]]; then
    return 113 # Host unreachable errno
  fi
}

function get_external_scripts()
{
  local OVERWRITE="$1"
  local ret
  local -r CHECKPATCH_URL="https://raw.githubusercontent.com/torvalds/linux/master/scripts/checkpatch.pl"
  local -r MAINTAINER_URL="https://raw.githubusercontent.com/torvalds/linux/master/scripts/get_maintainer.pl"
  local -r CHECKPATCH_CONST_STRUCTS="https://raw.githubusercontent.com/torvalds/linux/master/scripts/const_structs.checkpatch"
  local -r CHECKPATCH_SPELLING="https://raw.githubusercontent.com/torvalds/linux/master/scripts/spelling.txt"
  local DOWNLOAD_URLS=( \
        CHECKPATCH_URL \
        CHECKPATCH_CONST_STRUCTS \
        CHECKPATCH_SPELLING \
        MAINTAINER_URL )

  say "Downloading external scripts..."
  echo

  mkdir -p "$PATH_TO_TESTS_EXTERNALS"
  for url in ${DOWNLOAD_URLS[@]}; do
    download_stuff "${!url}" "$PATH_TO_TESTS_EXTERNALS" "$OVERWRITE"
    if [[ "$?" -eq 113 ]]; then
     return 113 # Host unreachable errno
    fi
  done
}

# Check and downloads required files for testing. Argument is $1 = true|false,
# whether to update required files even if they exist already (true) or just
# download if they don't exist (false). Default, when no argument is given, is
# false.
function check_required_files()
{
  local force_update="$1"

  force_update=${force_update:-'false'}

  if [[ "$force_update" == 'false' &&
           -f "$PATH_TO_TESTS_EXTERNALS/checkpatch.pl" &&
           -f "$PATH_TO_TESTS_EXTERNALS/const_structs.checkpatch" &&
           -f "$PATH_TO_TESTS_EXTERNALS/spelling.txt" &&
           -f "$PATH_TO_TESTS_EXTERNALS/get_maintainer.pl" ]]; then
       # Errno code for File exist
       return 17
  else
        say "--> Preparing unit test"
        get_external_scripts "$force_update"
        if [[ "$?" -eq 113 ]]; then
            complain "Failed to download external scripts. Check your connection."
            complain "Cannot run kw tests"
            exit 1
        fi
  fi
}

# Reports tests results.
# Arguments are: $1: # of tests, $2: # of succeeded tests, $3: # of notfound tests and
# $4: # of failed tests
function report_results
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

      echo
      complain "Take a look at:"
      IF=' ' read -r -a test_failure_array <<< "$test_failure_list"
      for failed in "${test_failure_array[@]}"; do
        complain "-> $failed"
      done

      return 1
    fi
}

function run_tests
{
  local -i total=${#TESTS[@]}
  local -i success=0
  local -i notfound=0
  local -i fail=0
  local test_failure_list=''

  for current_test in "${TESTS[@]}"; do
    target=$(find ./tests -name "*$current_test*.sh")
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
      complain "Test file $target not found."
      notfound+=1
    fi
  done
  report_results "$total" "$success" "$notfound" "$fail" "$test_failure_list"
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
  check_required_files
  files_list=$(find ./tests -name "*_test.sh")
  # Note: Usually we want to use double-quotes on bash variables, however,
  # in this case we want a set of parameters instead of a single one.
  strip_path $files_list
  run_tests
elif [[ "$1" == "list" ]]; then
  strip_path tests/*.sh
  for test_name in "${TESTS[@]}"; do
    say "  ${test_name}"
  done
elif [[ "$1" == "test" ]]; then
  check_required_files
  strip_path ${@:2}
  run_tests
elif [[ "$1" == "prepare" ]]; then
  if [[ "$#" -gt  1 && ("$2" == "--force-update" || "$2" == "-f") ]]; then
      check_required_files true
  else
      check_required_files
  fi
  if [[ "$?" -eq 17 ]]; then
    say "You are ready for running the unit test"
  fi
else
  show_help
fi
