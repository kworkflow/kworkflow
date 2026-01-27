#!/usr/bin/env bash

include './src/lib/git.sh'
include './tests/unit/utils.sh'

setUp()
{
  mk_fake_kernel_root "$SHUNIT_TMPDIR"
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move into temporary directory"
    return
  }
}

tearDown()
{
  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

oneTimeSetUp()
{
  original_dir="$PWD"
}

function test_kw_git_is_repo_safe_no_git_dir()
{
  local ret

  # Clean state - no git operations in progress
  [[ -d '.git/rebase-merge' ]] && rm --recursive '.git/rebase-merge'
  [[ -f '.git/MERGE_HEAD' ]] && rm '.git/MERGE_HEAD'
  [[ -f '.git/BISECT_LOG' ]] && rm '.git/BISECT_LOG'
  [[ -d '.git/rebase-apply' ]] && rm --recursive '.git/rebase-apply'

  kw_git_is_repo_safe
  ret="$?"

  assertEquals "($LINENO) kw_git_is_repo_safe should return 0" 0 "$ret"
}

invoke_shunit
