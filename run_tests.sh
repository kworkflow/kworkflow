#!/bin/bash

for test_entry in tests/*.sh; do
  echo "Running test file $test_entry"
  ./$test_entry
done

