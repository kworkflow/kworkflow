#!/bin/bash

. ./src/lib/kw_include.sh --source-only
include './src/lib/kwio.sh'

function main()
{
  cd integration_tests || exit_msg 'Failed to navigate to the integration tests directory.'

  if [[ "$#" -eq 0 ]]; then
    files_list=$(find ./ -name '*_integration_test.sh')
    strip_path "$files_list"
    run_integration_tests
  elif [[ "$1" == 'list' ]]; then
    index=0
    files_list=$(find ./ -name '*integration_test.sh')
    strip_path "$files_list"
    for test_name in "${TESTS[@]}"; do
      ((index++))
      say "${index}) ${test_name}"
    done
  fi
}

function run_integration_tests()
{
  for current_integration_test in "${TESTS[@]}"; do
    target=$(find ./ -name "${current_integration_test}*.sh")
    if [[ -f "$target" ]]; then
      say "Running test [${current_integration_test}]"
      say "$SEPARATOR"
      (
        export -f include
        "$target"
      )
    fi
  done
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

main "$@"
