#!/usr/bin/env bash

include './src/maintainers.sh'
include './src/lib/kwlib.sh'
include './tests/unit/utils.sh'

function test_is_inside_work_tree()
{
  local expected
  local output
  local ret

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Unable to move to temp directory"
    return "$ret"
  }

  output=$(is_inside_work_tree 'TEST_MODE')
  expected='git rev-parse --is-inside-work-tree &> /dev/null'
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(is_inside_work_tree '')
  ret="$?"
  assert_equals_helper 'Not in a git work tree, should fail' "$LINENO" 128 "$ret"

  mk_fake_git

  output=$(is_inside_work_tree '')
  ret="$?"
  assert_equals_helper 'Inside a git work tree' "$LINENO" 0 "$ret"

  rm -rf .git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Unable to move back from temp directory"
    return "$ret"
  }
}
