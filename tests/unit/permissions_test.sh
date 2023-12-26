#!/bin/bash

include './tests/unit/utils.sh'

function test_src_permissions()
{
  local perm
  local expected=6
  local -a files
  files=$(find ./src -name '*.sh')

  for file in $files; do
    # retrieve files permissions in octal form and get only the first digit
    perm=$(stat -c %a "$file")
    perm="${perm:0:1}"

    assert_equals_helper "Wrong permission: $file" "$LINENO" "$expected" "$perm"
  done
}

invoke_shunit
