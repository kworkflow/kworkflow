#!/usr/bin/env bash

include './tests/unit/utils.sh'
include './src/explore.sh'

# Note: these file names came from tests/unit/samples/
declare -a samples_names=(
  'codestyle_check.c'
  'codestyle_correct.c'
  'codestyle_error.c'
  'codestyle_warning.c'
  'codestyle_check.h'
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

  for commit in {0..4}; do
    local file_name="${samples_names[$commit]}"
    cp "$current_path/tests/unit/samples/$file_name" ./
    git add "$file_name" &> /dev/null
    git commit -m "Commit number $commit" &> /dev/null
  done

  cp "$current_path/tests/unit/samples/grep_check.c" .git

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
  output=$(explore_main)
  assertEquals "($LINENO) - Expected an error message." "$MSG_OUT" "$output"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  MSG_OUT='camelCase(void)'
  output=$(explore_main 'camelCase' '' | head -n 1 | cut -d ' ' -f2)
  assertEquals "($LINENO)" "$MSG_OUT" "$output"

  MSG_OUT='camel_case'
  output=$(explore_main 'camel_case' codestyle_error.c | grep "$MSG_OUT" -o | head -n 1)
  assertEquals "($LINENO)" "$MSG_OUT" "$output"

  output=$(explore_main 'GNU grep' '.' 'TEST_MODE')
  expected_result="git grep --context 0 -e 'GNU grep' --line-number -I ."
  assertEquals "($LINENO)" "$expected_result" "$output"

  # Test for non zero context value
  output=$(explore_main --show-context=5 'GNU grep' '.' 'TEST_MODE')
  expected_result="git grep --context 5 -e 'GNU grep' --line-number -I ."
  assertEquals "(${LINENO})" "$expected_result" "$output"

  # Test if search only in files under git control
  cp "$current_path/tests/unit/samples/grep_check.c" ./
  MSG_OUT='GNU grep'
  output=$(explore_main 'GNU grep' | cut -d: -f1)
  assertEquals "($LINENO)" '' "$output"
  git add 'grep_check.c' &> /dev/null
  MSG_OUT='GNU grep'
  output=$(explore_main 'GNU grep' | cut -d: -f1)
  assertEquals "($LINENO)" 'grep_check.c' "$output"

  # Test only-source and only-header
  MSG_OUT='3'
  output=$(explore_main 'camelCase' | wc --lines)
  assertEquals "($LINENO)" "$MSG_OUT" "$output"
  MSG_OUT='2'
  output=$(explore_main -c 'camelCase' | wc --lines)
  assertEquals "($LINENO)" "$MSG_OUT" "$output"
  MSG_OUT='1'
  output=$(explore_main -H 'camelCase' | wc --lines)
  assertEquals "($LINENO)" "$MSG_OUT" "$output"

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
  output=$(explore_main --log "$commit_msg" | grep "$commit_msg" | awk '{print $1, $2, $3}')
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

  output=$(explore_main --grep 'GNU grep' | cut -d/ -f2)
  assertEquals "($LINENO)" '.git' "$output"

  output=$(explore_main --grep 'GNU grep' '.' 'TEST_MODE')
  expected_result="grep --color --line-number --recursive -I . --context 0 -e 'GNU grep'"
  assertEquals "(${LINENO})" "$expected_result" "$output"

  output=$(explore_main --grep --show-context=5 'GNU grep' '.' 'TEST_MODE')
  expected_result="grep --color --line-number --recursive -I . --context 5 -e 'GNU grep'"
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

  output=$(explore_main --all 'GNU grep' '.' 'TEST_MODE')
  expected_result="git grep --no-index --context 0 -e 'GNU grep' --line-number -I ."
  assertEquals "(${LINENO})" "$expected_result" "$output"

  output=$(explore_main --all --show-context=5 'GNU grep' '.' 'TEST_MODE')
  expected_result="git grep --no-index --context 5 -e 'GNU grep' --line-number -I ."
  assertEquals "($LINENO)" "$expected_result" "$output"

  # Test if the search ignores files in .git
  output=$(explore_main --all 'GNU grep' | cut -d/ -f2)
  assertEquals "($LINENO)" '' "$output"

  # Test if search files not under git control
  cp "$current_path/tests/unit/samples/grep_check.c" ./
  MSG_OUT='GNU grep'
  output=$(explore_main --all 'GNU grep' | cut -d: -f1)
  assertEquals "($LINENO)" 'grep_check.c' "$output"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_explore_context()
{
  local -r current_path="$PWD"
  local expected_context='3'
  local expected_match='avoid'
  local msg_out='7'

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Check the number of output lines
  output=$(explore_main --show-context=3 'avoid' codestyle_error.c | wc --lines)
  assertEquals "(${LINENO})" "$msg_out" "$output"

  output=$(explore_main --show-context="$expected_context" "$expected_match" codestyle_error.c)

  # Check if the expected match and context lines are present in the output
  assert_substring_match 'Expected match not found!' "${LINENO}" "${expected_match}" "$output"

  # Check context lines below the match
  for ((i = 1; i <= expected_context; i++)); do
    CONTEXT_LINE=$((i + 4)) # Assuming match is on line 4
    CONTEXT_LINE_CONTENT=$(printf '%s' "$output" | head -n "${CONTEXT_LINE}" | tail --lines 1)
    assert_line_match "Context line ${CONTEXT_LINE} below match" "$CONTEXT_LINE_CONTENT" "$output"
  done

  # Check context lines above the match
  for ((i = 1; i <= expected_context; i++)); do
    CONTEXT_LINE=$((4 - i)) # Assuming match is on line 4
    CONTEXT_LINE_CONTENT=$(printf '%s' "$output" | head -n ${CONTEXT_LINE} | tail -n 1)
    assert_line_match "Context line ${CONTEXT_LINE} above match" "$CONTEXT_LINE_CONTENT" "$output"
  done

  cd "$current_path" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }
}

function test_parse_explore_options()
{
  # Expected behaviour
  unset options_values
  declare -gA options_values
  parse_explore_options --log 'something'
  ret="$?"
  assertEquals "($LINENO)" '0' "$ret"
  assertEquals "($LINENO)" '1' "${options_values['TYPE']}"

  unset options_values
  declare -gA options_values
  parse_explore_options --grep 'something'
  ret="$?"
  assertEquals "($LINENO)" '0' "$ret"
  assertEquals "($LINENO)" '2' "${options_values['TYPE']}"

  unset options_values
  declare -gA options_values
  parse_explore_options -g 'something'
  ret="$?"
  assertEquals "($LINENO)" '0' "$ret"
  assertEquals "($LINENO)" '2' "${options_values['TYPE']}"

  unset options_values
  declare -gA options_values
  parse_explore_options --all 'something'
  ret="$?"
  assertEquals "($LINENO)" '0' "$ret"
  assertEquals "($LINENO)" '3' "${options_values['TYPE']}"

  unset options_values
  declare -gA options_values
  parse_explore_options -a 'something'
  ret="$?"
  assertEquals "($LINENO)" '0' "$ret"
  assertEquals "($LINENO)" '3' "${options_values['TYPE']}"

  unset options_values
  declare -gA options_values
  parse_explore_options 'something'
  ret="$?"
  assertEquals "($LINENO)" '0' "$ret"
  assertEquals "($LINENO)" '' "${options_values['TYPE']}"

  unset options_values
  declare -gA options_values
  parse_explore_options --verbose
  assertEquals "($LINENO)" '1' "${options_values['VERBOSE']}"

  unset options_values
  declare -gA options_values
  parse_explore_options -c 'something'
  ret="$?"
  assertEquals "($LINENO)" '0' "$ret"
  assertEquals "($LINENO)" 'SOURCE' "${options_values['SCOPE']}"

  unset options_values
  declare -gA options_values
  parse_explore_options -H 'something'
  ret="$?"
  assertEquals "($LINENO)" '0' "$ret"
  assertEquals "($LINENO)" 'HEADER' "${options_values['SCOPE']}"

  unset options_values
  declare -gA options_values
  parse_explore_options -C
  ret="$?"
  assertEquals "(${LINENO})" '0' "$ret"
  assertEquals "(${LINENO})" '3' "${options_values['CONTEXT']}"

  unset options_values
  declare -gA options_values
  parse_explore_options --show-context=5
  ret="$?"
  assertEquals "(${LINENO})" '0' "$ret"
  assertEquals "(${LINENO})" '5' "${options_values['CONTEXT']}"

  # Others
  parse_explore_options --logljkl
  ret="$?"
  assertEquals "($LINENO)" '22' "$ret" # messy arg, should return 22

  parse_explore_options --grepljkl
  ret="$?"
  assertEquals "($LINENO)" '22' "$ret" # messy arg, should return 22

  unset options_values
  declare -gA options_values
  parse_explore_options --log --grep
  ret="$?"
  assertEquals "($LINENO)" '22' "$ret"
  assertEquals "($LINENO)" 'Invalid arguments: Multiple search type!' "${options_values['ERROR']}"

  unset options_values
  declare -gA options_values
  parse_explore_options --grep --all
  ret="$?"
  assertEquals "($LINENO)" '22' "$ret"
  assertEquals "($LINENO)" 'Invalid arguments: Multiple search type!' "${options_values['ERROR']}"

  unset options_values
  declare -gA options_values
  parse_explore_options --all --log
  ret="$?"
  assertEquals "($LINENO)" '22' "$ret"
  assertEquals "($LINENO)" 'Invalid arguments: Multiple search type!' "${options_values['ERROR']}"

  unset options_values
  declare -gA options_values
  parse_explore_options --show-context=invalid
  ret="$?"
  assertEquals "($LINENO)" '22' "$ret"
  assertEquals "($LINENO)" 'Context value must be a non-negative integer!' "${options_values['ERROR']}"

  parse_explore_options main
  ret="$?"
  assertEquals "($LINENO)" '0' "$ret"

  parse_explore_options main ./src
  ret="$?"
  assertEquals "($LINENO)" '0' "$ret"

  unset options_values
  declare -gA options_values
  parse_explore_options main ./src abaabaaba
  ret="$?"
  assertEquals "($LINENO)" '22' "$ret"
  assertEquals "($LINENO)" 'Too many parameters' "${options_values['ERROR']}"
}

invoke_shunit
