#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
  REPO_ROOT=$(realpath "$(dirname "$BATS_TEST_FILENAME")/..")
  GIT_HELPER="$REPO_ROOT/src/lib/git_helper.sh"
}

@test "kw_git_get_head_hash returns valid short hash" {
  run bash -c "source \"$GIT_HELPER\" && kw_git_get_head_hash \"$REPO_ROOT\""
  assert_success
  assert_output --regexp '^[a-f0-9]{7}$'
}

@test "kw_git_get_branch_name returns current branch" {
  run bash -c "source \"$GIT_HELPER\" && kw_git_get_branch_name \"$REPO_ROOT\""
  assert_success
  assert_output --regexp '^[a-zA-Z0-9._/-]+$'
}
