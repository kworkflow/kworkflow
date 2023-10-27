#!/bin/bash

invoke_shunit()
{
  if command -v shunit2 > /dev/null; then
    # shunit2 is installed, run the tests
    printf "Running tests with shunit2...\n"
    . shunit2
  else
    # shunit2 is not installed
    printf "Error: shunit2 not found. Make sure shunit2 is installed or adjust the executable path.\n"
    exit 1
  fi
}
