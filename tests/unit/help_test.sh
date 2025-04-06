#!/usr/bin/env bash

include './tests/unit/utils.sh'
include './src/help.sh'

function test_kworkflow_help() {
  HELP_OUTPUT=$(kworkflow_help | head -n 1)
  [[ $HELP_OUTPUT =~ Usage:\ kw.* ]]
  assertTrue "Help text not displaying correctly." $?
}

function test_kworkflow_man() {
  export KW_MAN_DIR="$SHUNIT_TMPDIR"
  touch "$SHUNIT_TMPDIR/kw.1"
  expect="man -l $SHUNIT_TMPDIR/kw.1"
  output=$(kworkflow_man '' 'TEST_MODE')
  assertEquals "($LINENO) We expected kw general man." "$expect" "$output"
  rm "$SHUNIT_TMPDIR/kw.1"

  touch "$SHUNIT_TMPDIR/kw-feature.1"
  expect="man -l $SHUNIT_TMPDIR/kw-feature.1"
  output=$(kworkflow_man 'feature' 'TEST_MODE')
  assertEquals "($LINENO) We expected feature specific man." "$expect" "$output"
  rm "$SHUNIT_TMPDIR/feature.1"

  expect="Couldn't find the man page for kw-error!"
  output=$(kworkflow_man 'error' 'TEST_MODE')
  ret="$?"
  assertEquals "($LINENO) We expected an error." 2 "$ret"
  assertEquals "($LINENO) We expected an error message." "$expect" "$output"
}

function test_kworkflow_version() {
  local KW_LIB_DIR
  local output
  local expected_output

  # the mocked version for KW
  expected_output=$(printf 'beta\nBranch: bazz\nCommit: ffddee\n')

  # this value mocks a fake location for the version file, which is the file used
  # by KW to get information about the current version.
  KW_LIB_DIR="${SHUNIT_TMPDIR}"
  printf '%s' "${expected_output}" > "${KW_LIB_DIR}/VERSION"

  # check output
  output=$(kworkflow_version)
  assert_equals_helper 'Got wrong kw version.' "(${LINENO})" "${expected_output}" "${output}"
}

function test_kworkflow_version_in_repomode() {
  local branch_name
  local head_hash
  local version_name
  local output
  local original_path
  local path_to_git_repository
  local KW_REPO_MODE
  local KW_LIB_DIR

  # Initialize variables.
  original_path="$PWD"
  version_name='omega'
  branch_name='foo'
  path_to_git_repository="${SHUNIT_TMPDIR}/git_repo"
  KW_LIB_DIR="${path_to_git_repository}/src"

  # shellcheck disable=SC2034
  KW_REPO_MODE='y' # used to trigger repo-mode behavior

  # create the git repository
  mkdir --parents "${KW_LIB_DIR}"

  # cd into the repo, so we can run git commands there.
  # This is necessary because our helper `mk_fake_git` assumes the current
  # working directory is the directory in which we want to run git commands.
  cd "${path_to_git_repository}" || fail 'Failed to switch to git dir.'

  # print kw's version name
  printf '%s\n' "${version_name}" > "${KW_LIB_DIR}/VERSION"

  # Make fake git commits from the created branch.
  mk_fake_git

  # Create and switch to a new branch
  git switch --quiet --create "${branch_name}"

  # Get commit hash.
  head_hash=$(git rev-parse --short HEAD)

  # Get kw version.
  output=$(kworkflow_version)

  # Compare results.
  assert_substring_match 'Wrong version name' "(${LINENO})" "${version_name}" "${output}"
  assert_substring_match 'Wrong commit' "(${LINENO})" "Commit: ${head_hash}" "${output}"
  assert_substring_match 'Wrong branch' "(${LINENO})" "Branch: ${branch_name}" "${output}"

  # Go back to previous dir.
  cd "$original_path" || fail 'Failed to switch back to original directory.'
}

invoke_shunit
