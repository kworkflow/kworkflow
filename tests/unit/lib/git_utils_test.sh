#!/usr/bin/env bash

include './src/maintainers.sh'
include './src/lib/kwlib.sh'
include './src/unit/utils'
include './src/lib/git_utils.sh'
include './tests/unit/utils.sh'

function oneTimeSetUp()
{
  declare -gr ORIGINAL_DIR="$PWD"
  declare -gr FAKE_DATA="${SHUNIT_TMPDIR}/db_testing"

  mkdir -p "$FAKE_DATA"

  KW_DATA_DIR="$FAKE_DATA"
  KW_DB_DIR="$(realpath './database')"

  setupFakeKernelRepo
}

function setupPatch()
{
  cp -f tests/unit/samples/test.patch "$SHUNIT_TMPDIR"
}

function tearDown()
{
  cd "$ORIGINAL_DIR" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

function setupGitRepository()
{
  declare -gr PATH_TO_GIT_REPOSITORY="${SHUNIT_TMPDIR}/git_repository"
  mkdir -p "$PATH_TO_GIT_REPOSITORY"
  git -C "$PATH_TO_GIT_REPOSITORY" init --initial-branch='master' --quiet
  git -C "$PATH_TO_GIT_REPOSITORY" config user.name kw
  git -C "$PATH_TO_GIT_REPOSITORY" config user.email kw@kw
}

function teardownGitRepository()
{
  is_safe_path_to_remove "$PATH_TO_GIT_REPOSITORY"
  if [[ "$?" == 0 ]]; then
    rm -rf "$PATH_TO_GIT_REPOSITORY"
  fi
}

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

function test_get_all_git_config()
{
  local expected
  local output
  local ret

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Unable to move to temp directory"
    return "$ret"
  }

  output=$(get_all_git_config test-config '' 'TEST_MODE' | sort -d)
  expected=$'global\t'"git config --get-all --global test-config"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_all_git_config test-config 'local' 'TEST_MODE')
  expected=$'global\tgit config --get-all --global test-config'
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  # only possible test at a global scope, as we have limited control over
  # the user's system
  output=$(get_all_git_config test-config 'global' 'TEST_MODE')
  expected=$'global\tgit config --get-all --global test-config'
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  mk_fake_git

  output=$(get_all_git_config test-config '' 'TEST_MODE' | sort -d)
  expected=$'global\t'"git config --get-all --global test-config"$'\n'
  expected+=$'local\t'"git config --get-all --local test-config"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_all_git_config test-config 'local' 'TEST_MODE')
  expected=$'local\tgit config --get-all --local test-config'
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_all_git_config test-config 'global' 'TEST_MODE')
  expected=$'global\tgit config --get-all --global test-config'
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_all_git_config user.name)
  expected='Xpto Lala'
  assertTrue "($LINENO): Expected to find user Xpto Lala" '[[ $output =~ $expected ]]'

  output=$(get_all_git_config user.name 'local')
  expected='Xpto Lala'
  assertTrue "($LINENO): Expected to find user Xpto Lala" '[[ $output =~ $expected ]]'

  output=$(get_all_git_config user.email)
  expected='test@email.com'
  assertTrue "($LINENO): Expected to find email test@email.com" '[[ $output =~ $expected ]]'

  output=$(get_all_git_config test.config)
  expected='value'
  assertTrue "($LINENO): Expected to find test value" '[[ $output =~ $expected ]]'

  rm -rf .git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Unable to move back from temp directory"
    return "$ret"
  }
}

function test_get_git_config_regex()
{
  local expected
  local output
  local ret

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Unable to move to temp directory"
    return "$ret"
  }

  output=$(get_git_config_regex test-config '' 'TEST_MODE' | sort -d)
  expected=$'global\t'"git config --get-regexp --global 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_git_config_regex test-config 'local' 'TEST_MODE')
  expected=$'global\t'"git config --get-regexp --global 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  # only possible test with at global scope, as we have limited control over
  # the user's system
  output=$(get_git_config_regex test-config 'global' 'TEST_MODE')
  expected=$'global\t'"git config --get-regexp --global 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  mk_fake_git

  output=$(get_git_config_regex test-config '' 'TEST_MODE' | sort -d)
  expected=$'global\t'"git config --get-regexp --global 'test-config'"$'\n'
  expected+=$'local\t'"git config --get-regexp --local 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_git_config_regex test-config 'local' 'TEST_MODE')
  expected=$'local\t'"git config --get-regexp --local 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_git_config_regex test-config 'global' 'TEST_MODE')
  expected=$'global\t'"git config --get-regexp --global 'test-config'"
  assert_equals_helper 'Testing command' "$LINENO" "$expected" "$output"

  output=$(get_git_config_regex name)
  expected='Xpto Lala'
  assertTrue "($LINENO): Expected to find name" '[[ $output =~ $expected ]]'

  output=$(get_git_config_regex email)
  expected='test@email.com'
  assertTrue "($LINENO): Expected to find email" '[[ $output =~ $expected ]]'

  output=$(get_git_config_regex user)
  expected='name'
  assertTrue "($LINENO): Expected to find name" '[[ $output =~ $expected ]]'
  expected='email'
  assertTrue "($LINENO): Expected to find email" '[[ $output =~ $expected ]]'

  output=$(get_git_config_regex test.config)
  expected='value'
  assertTrue "($LINENO): Expected to find test value" '[[ $output =~ $expected ]]'

  rm -rf .git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Unable to move back from temp directory"
    return "$ret"
  }
}

function test_get_git_repository_branches()
{
  declare -A branches

  setupGitRepository

  # Prepare git repository
  git -C "$PATH_TO_GIT_REPOSITORY" commit --allow-empty --message='commit_subject1' --quiet
  git -C "$PATH_TO_GIT_REPOSITORY" checkout -b 'not_master' --quiet
  git -C "$PATH_TO_GIT_REPOSITORY" commit --allow-empty --message='commit_subject2' --quiet
  git -C "$PATH_TO_GIT_REPOSITORY" checkout -b 'main' --quiet
  git -C "$PATH_TO_GIT_REPOSITORY" checkout -b 'not_main' --quiet
  git -C "$PATH_TO_GIT_REPOSITORY" commit --allow-empty --message='commit_subject3' --quiet

  # Test setting of 'branches'
  get_git_repository_branches "$PATH_TO_GIT_REPOSITORY" 'branches'
  assert_equals_helper 'Wrong value for "master" key' "$LINENO" 'commit_subject1' "${branches['master']}"
  assert_equals_helper 'Wrong value for "not_master" key' "$LINENO" 'commit_subject2' "${branches['not_master']}"
  assert_equals_helper 'Wrong value for "main" key' "$LINENO" 'commit_subject2' "${branches['main']}"
  assert_equals_helper 'Wrong value for "not_main" key' "$LINENO" 'commit_subject3' "${branches['not_main']}"

  # Delete a branch
  git -C "$PATH_TO_GIT_REPOSITORY" switch master --quiet
  git -C "$PATH_TO_GIT_REPOSITORY" branch -D not_master --quiet

  # Test unsetting of 'branches'
  get_git_repository_branches "$PATH_TO_GIT_REPOSITORY" 'branches'
  assert_equals_helper 'Branch "not_master" was deleted and should not be set' "$LINENO" '' "${branches['not_master']}"

  teardownGitRepository
}

function test_find_commit_references()
{
  local output
  local ret

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Failed to move to temp dir"
    exit "$ret"
  }

  find_commit_references
  ret="$?"
  assert_equals_helper 'No arguments given' "$LINENO" 22 "$ret"

  find_commit_references @^
  ret="$?"
  assert_equals_helper 'Outside git repo should return 125' "$LINENO" 125 "$ret"

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  output="$(find_commit_references invalid_ref)"
  ret="$?"
  assert_equals_helper 'Invalid ref should not work' "$LINENO" 22 "$ret"
  assertTrue "($LINENO) Invalid ref should be empty" '[[ -z "$output" ]]'

  output="$(find_commit_references '@^..@')"
  ret="$?"
  assert_equals_helper '@^..@ should be a valid reference' "$LINENO" 0 "$ret"
  assertTrue "($LINENO) @^..@ should generate a reference" '[[ -n "$output" ]]'

  output="$(find_commit_references @)"
  ret="$?"
  assert_equals_helper '@ should be a valid reference' "$LINENO" 0 "$ret"
  assertTrue "($LINENO) @ should generate a reference" '[[ -n "$output" ]]'

  output="$(find_commit_references some args @ around)"
  ret="$?"
  assert_equals_helper '@ should be a valid reference' "$LINENO" 0 "$ret"
  assertTrue "($LINENO) @ should generate a reference" '[[ -n "$output" ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_add_config()
{
  local output
  local expected
  local ret

  options_values['test.opt']='value'
  options_values['CMD_SCOPE']='global'

  # test default values
  output=$(add_config 'test.opt' '' '' 'TEST_MODE')
  expected="git config --global test.opt 'value'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$expected" "$output"

  output=$(add_config 'test.option' 'test_value' 'local' 'TEST_MODE')
  expected="git config --local test.option 'test_value'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$expected" "$output"
}

invoke_shunit