#!/bin/bash

for test_entry in tests/*.sh; do
  . ./$test_entry
done

