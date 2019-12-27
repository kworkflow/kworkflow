#!/bin/bash

. ./tests/utils --source-only
. ./src/explore.sh --source-only

function suite
{
  suite_addTest "explore_files_under_git_repo_Test"
  suite_addTest "explore_git_log_Test"
  suite_addTest "explore_parser_Test"
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
  local original="$PWD"

  ID=1
  MSG_OUT="Expected string or 'log'"
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

  cd "$original"
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

function explore_parser_Test
{
  local ID

  # Expected behaviour
  ID=1
  output=$(explore_parser --log "something")
  ret="$?"
  assertEquals "($ID)" "1" "$ret"

  ID=2
  output=$(explore_parser "something")
  ret="$?"
  assertEquals "($ID)" "2" "$ret"

  # Others
  ID=3
  output=$(explore_parser --logljkl)
  ret="$?"
  assertEquals "($ID)" "2" "$ret"

  ID=4
  output=$(explore_parser)
  ret="$?"
  assertEquals "($ID)" "22" "$ret"
}

invoke_shunit
