#!/bin/bash

include './tests/utils'
include './src/explore.sh'

function suite
{
  suite_addTest "explore_files_under_git_repo_Test"
  suite_addTest "explore_git_log_Test"
  suite_addTest "explore_parser_Test"
  suite_addTest "explore_grep_Test"
  suite_addTest "explore_git_Test"
}

declare -r test_path="tests/.tmp"

# Note: these file names came from tests/samples/
declare -a samples_names=(
  "codestyle_check.c"
  "codestyle_correct.c"
  "codestyle_error.c"
  "codestyle_warning.c"
)

function setUp()
{
  local -r current_path="$PWD"

  rm -rf "$test_path"

  mkdir -p "$test_path"
  cd "$test_path"
  # Setup git repository for test
  git init &> /dev/null

  for commit in {0..3}; do
    local file_name="${samples_names[$commit]}"
    cp "$current_path/tests/samples/$file_name" ./
    git add "$file_name" &> /dev/null
    git commit -m "Commit number $commit" &> /dev/null
  done

  cp "$current_path/tests/samples/grep_check.c" .git

  cd "$current_path"
}

function tearDown()
{
  rm -rf "$test_path"
}

function explore_files_under_git_repo_Test
{
  local ID
  local MSG_OUT
  local -r current_path="$PWD"

  ID=1
  MSG_OUT="Expected string or parameter. See man for detail."
  output=$(explore)
  assertEquals "($ID) - Expected an error message." "$MSG_OUT" "$output"

  cd "$test_path"

  ID=2
  MSG_OUT="camelCase(void)"
  output=$(explore "camelCase" "" | cut -d ' ' -f2)
  assertEquals "($ID)" "$MSG_OUT" "$output"

  ID=3
  MSG_OUT="camel_case"
  output=$(explore "camel_case" codestyle_error.c | grep "$MSG_OUT" -o | head -n 1)
  assertEquals "($ID)" "$MSG_OUT" "$output"

  ID=4
  output=$(explore "GNU grep" "." "TEST_MODE")
  expected_result="git grep -e \"GNU grep\" -nI ."
  assertEquals "($ID)" "$expected_result" "$output"

  # Test if search only in files under git control
  ID=5
  cp "$current_path/tests/samples/grep_check.c" ./
  MSG_OUT="GNU grep"
  output=$(explore "GNU grep" | cut -d: -f1 )
  assertEquals "($ID)" "" "$output"
  git add "grep_check.c" &> /dev/null
  MSG_OUT="GNU grep"
  output=$(explore "GNU grep" | cut -d: -f1 )
  assertEquals "($ID)" "grep_check.c" "$output"

  cd "$current_path"
}

function explore_git_log_Test
{
  local ID
  local file_name
  local commit_msg
  local -r current_path="$PWD"

  cd "$test_path"

  ID=1
  commit_msg="Commit number 2"
  file_name="file_2.txt"
  output=$(explore --log "$commit_msg" | grep "$commit_msg" | awk '{print $1, $2, $3}')
  assertEquals "($ID)" "$commit_msg" "$output"

  cd "$current_path"
}

function explore_grep_Test
{
  local ID
  local expected_result
  local -r current_path="$PWD"

  cd "$test_path"

  ID=1
  output=$(explore --grep "GNU grep" | cut -d/ -f2 )
  assertEquals "($ID)" ".git" "$output"

  ID=2
  output=$(explore --grep "GNU grep" "." "TEST_MODE")
  expected_result="grep --color -nrI . -e \"GNU grep\""
  assertEquals "($ID)" "$expected_result" "$output"

  cd "$current_path"
}

function explore_git_Test
{
  local ID
  local expected_result
  local -r current_path="$PWD"

  cd "$test_path"

  ID=1
  output=$(explore --all "GNU grep" "." "TEST_MODE")
  expected_result="git grep --no-index -e \"GNU grep\" -nI ."
  assertEquals "($ID)" "$expected_result" "$output"

  # Test if the search ignores files in .git
  ID=2
  output=$(explore --all "GNU grep" | cut -d/ -f2 )
  assertEquals "($ID)" "" "$output"

  # Test if search files not under git control
  ID=3
  cp "$current_path/tests/samples/grep_check.c" ./
  MSG_OUT="GNU grep"
  output=$(explore --all "GNU grep" | cut -d: -f1 )
  assertEquals "($ID)" "grep_check.c" "$output"

  cd "$current_path"
}

function explore_parser_Test
{
  local ID

  # Expected behaviour
  # Expected behaviour
  ID=1
  output=$(explore_parser --log "something")
  ret="$?"
  assertEquals "($ID)" "1" "$ret"

  ID=2
  output=$(explore_parser --grep "something")
  ret="$?"
  assertEquals "($ID)" "2" "$ret"

  ID=3
  output=$(explore_parser -g "something")
  ret="$?"
  assertEquals "($ID)" "2" "$ret"

  ID=4
  output=$(explore_parser --all "something")
  ret="$?"
  assertEquals "($ID)" "3" "$ret"

  ID=5
  output=$(explore_parser -a "something")
  ret="$?"
  assertEquals "($ID)" "3" "$ret"

  ID=6
  output=$(explore_parser "something")
  ret="$?"
  assertEquals "($ID)" "4" "$ret"

  # Others
  ID=7
  output=$(explore_parser --logljkl)
  ret="$?"
  assertEquals "($ID)" "4" "$ret"

  ID=8
  output=$(explore_parser --grepljkl)
  ret="$?"
  assertEquals "($ID)" "4" "$ret"

  ID=9
  output=$(explore_parser)
  ret="$?"
  assertEquals "($ID)" "22" "$ret"
}

invoke_shunit
