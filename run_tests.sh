#!/bin/bash

. ./tests/utils --source-only
. ./src/miscellaneous.sh --source-only

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
  URL=$1
  PATH_TO=$2
  OVERWRITE=$3
  if $OVERWRITE; then
      ret=$(wget -N $URL -P $PATH_TO)
  else
      ret=$(wget -nc $URL -P $PATH_TO)
  fi

  if [ "$?" != 0 ] ; then
    return 113 # Host unreachable errno
  fi
}

function get_external_scripts()
{
  local OVERWRITE=$1
  local ret

  local -r CHECKPATCH_URL="https://raw.githubusercontent.com/torvalds/linux/master/scripts/checkpatch.pl"
  local -r CHECKPATCH_CONST_STRUCTS="https://raw.githubusercontent.com/torvalds/linux/master/scripts/const_structs.checkpatch"
  local -r CHECKPATCH_SPELLING="https://raw.githubusercontent.com/torvalds/linux/master/scripts/spelling.txt"
  local DOWNLOAD_URLS=( \
        CHECKPATCH_URL \
        CHECKPATCH_CONST_STRUCTS \
        CHECKPATCH_SPELLING )

  say "Downloading external scripts..."
  echo

  mkdir -p $PATH_TO_TESTS_EXTERNALS
   for url in "${DOWNLOAD_URLS[@]}"; do
       download_stuff ${!url} $PATH_TO_TESTS_EXTERNALS $OVERWRITE
       if [[ "$?" -eq 113 ]]; then
         echo
         return 113
        fi
   done

   echo
}

# Check and downloads required files for testing. Argument is $1 = true|false, wheter to update
# required files even if they exist already (true) or just download if they don't exist (false).
# Default, when no argument is given, is false.
function check_required_files()
{
    local force_update=false
    if [[ "$#" -eq 1 ]]; then
        force_update="$1"
    fi
	if [[ "$force_update" = false &&
           -f "$PATH_TO_TESTS_EXTERNALS/checkpatch.pl" &&
           -f "$PATH_TO_TESTS_EXTERNALS/const_structs.checkpatch" &&
           -f "$PATH_TO_TESTS_EXTERNALS/spelling.txt" ]] ; then
       # Errno code for File exist
       return 17
	else
        say "--> Preparing unit test"
        get_external_scripts $force_update
        if [[ "$?" -eq 113 ]]; then
            complain "Failed to download external scripts. Check your connection."
            complain "Cannot run kw tests"
            exit 1
        fi
	fi
}

function run_tests
{
  local rc=0
  for current_test in "${TESTS[@]}"; do
    say "Running test [${current_test}]"
    say $SEPARATOR
    (
      init_env
      ./tests/${current_test}.sh --source-only
    )
    if [[ "$?" -eq 1 ]]; then
      rc=1
    fi
  done
  if [[ "$rc" -ne 0 ]]; then
    complain $SEPARATOR
    complain "Some test(s) FAILED"
  else
    success $SEPARATOR
    success "Test(s) SUCCEEDED"
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
  check_required_files
  strip_path tests/*.sh
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
