#!/usr/bin/env bash

include './tests/utils.sh'
include './src/explore.sh'

# Note: these file names came from tests/samples/
declare -a samples_names=(
  'codestyle_check.c'
  'codestyle_correct.c'
  'codestyle_error.c'
  'codestyle_warning.c'
)

function setUp()
{
  local -r current_path="$PWD"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  # Setup git repository for test
  mk_fake_git

  for commit in {0..3}; do
    local file_name="${samples_names[$commit]}"
    cp "$current_path/tests/samples/$file_name" ./
    git add "$file_name" &> /dev/null
    git commit -m "Commit number $commit" &> /dev/null
  done

  cp "$current_path/tests/samples/grep_check.c" .git

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
  mkdir -p "$SHUNIT_TMPDIR"
}

function test_explore_files_under_git_repo()
{
  local MSG_OUT
  local -r current_path="$PWD"

  MSG_OUT='Expected string or parameter. See man for detail.'
  output=$(explore)
  assertEquals "($LINENO) - Expected an error message." "$MSG_OUT" "$output"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  MSG_OUT='camelCase(void)'
  output=$(explore 'camelCase' '' | cut -d ' ' -f2)
  assertEquals "($LINENO)" "$MSG_OUT" "$output"

  MSG_OUT='camel_case'
  output=$(explore 'camel_case' codestyle_error.c | grep "$MSG_OUT" -o | head -n 1)
  assertEquals "($LINENO)" "$MSG_OUT" "$output"

  output=$(explore 'GNU grep' '.' 'TEST_MODE')
  expected_result="git grep -e 'GNU grep' -nI ."
  assertEquals "($LINENO)" "$expected_result" "$output"

  # Test if search only in files under git control
  cp "$current_path/tests/samples/grep_check.c" ./
  MSG_OUT='GNU grep'
  output=$(explore 'GNU grep' | cut -d: -f1)
  assertEquals "($LINENO)" '' "$output"
  git add 'grep_check.c' &> /dev/null
  MSG_OUT='GNU grep'
  output=$(explore 'GNU grep' | cut -d: -f1)
  assertEquals "($LINENO)" 'grep_check.c' "$output"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_explore_git_log()
{
  local file_name
  local commit_msg
  local -r current_path="$PWD"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  commit_msg='Commit number 2'
  file_name='file_2.txt'
  output=$(explore --log "$commit_msg" | grep "$commit_msg" | awk '{print $1, $2, $3}')
  assertEquals "($LINENO)" "$commit_msg" "$output"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_explore_grep()
{
  local expected_result
  local -r current_path="$PWD"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(explore --grep 'GNU grep' | cut -d/ -f2)
  assertEquals "($LINENO)" '.git' "$output"

  output=$(explore --grep 'GNU grep' '.' 'TEST_MODE')
  expected_result="grep --color -nrI . -e 'GNU grep'"
  assertEquals "($LINENO)" "$expected_result" "$output"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_explore_git()
{
  local expected_result
  local -r current_path="$PWD"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(explore --all 'GNU grep' '.' 'TEST_MODE')
  expected_result="git grep --no-index -e 'GNU grep' -nI ."
  assertEquals "($LINENO)" "$expected_result" "$output"

  # Test if the search ignores files in .git
  output=$(explore --all 'GNU grep' | cut -d/ -f2)
  assertEquals "($LINENO)" '' "$output"

  # Test if search files not under git control
  cp "$current_path/tests/samples/grep_check.c" ./
  MSG_OUT='GNU grep'
  output=$(explore --all 'GNU grep' | cut -d: -f1)
  assertEquals "($LINENO)" 'grep_check.c' "$output"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_explore_parser()
{
  # Expected behaviour
  output=$(explore_parser --log 'something')
  ret="$?"
  assertEquals "($LINENO)" '1' "$ret"

  output=$(explore_parser --grep 'something')
  ret="$?"
  assertEquals "($LINENO)" '2' "$ret"

  output=$(explore_parser -g 'something')
  ret="$?"
  assertEquals "($LINENO)" '2' "$ret"

  output=$(explore_parser --all 'something')
  ret="$?"
  assertEquals "($LINENO)" '3' "$ret"

  output=$(explore_parser -a 'something')
  ret="$?"
  assertEquals "($LINENO)" '3' "$ret"

  output=$(explore_parser 'something')
  ret="$?"
  assertEquals "($LINENO)" '4' "$ret"

  # Others
  output=$(explore_parser --logljkl)
  ret="$?"
  assertEquals "($LINENO)" '4' "$ret"

  output=$(explore_parser --grepljkl)
  ret="$?"
  assertEquals "($LINENO)" '4' "$ret"

  output=$(explore_parser)
  ret="$?"
  assertEquals "($LINENO)" '22' "$ret"
}

invoke_shunit
