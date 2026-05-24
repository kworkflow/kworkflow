#!/usr/bin/env bash

include './src/apply_patch.sh'
include './tests/unit/utils.sh'

function setUp()
{
  is_kernel_root()
  {
    # this is a mock function to simulate kernel root check for testing
    return 0
  }
  kw_git_is_repo_safe()
  {
    # this is a mock function to simulate git repo safety check for testing
    return 0
  }
}

function tearDown()
{
  unset curl
  unset git
}

function test_validate_correct_url()
{
  validate_url 'https://example.com/patch.diff'
  assert_equals_helper 'Valid URL should return 0' "$LINENO" 0 "$?"
}

function test_validate_incorrect_url()
{
  validate_url 'ftp://example.com/patch.diff'
  assert_equals_helper 'Invalid URL should return 22' "$LINENO" 22 "$?"
}

function test_validate_empty_url()
{
  validate_url ''
  assert_equals_helper 'Empty URL should return 22' "$LINENO" 22 "$?"
}

function test_download_patch_success()
{
  curl()
  {
    # this is a mock function to simulate curl behavior for testing
    printf "content\n\n200"
    return 0
  }
  download_patch '' "url"
  assert_equals_helper 'Download should succeed' "$LINENO" 0 "$?"
}

function test_download_patch_fail_when_curl_fails()
{
  curl()
  {
    # this is a mock function to simulate curl behavior for testing
    printf "content\n\n500"
    return 1
  }
  download_patch '' "url"
  assert_equals_helper 'Download should fail' "$LINENO" 1 "$?"
}

function test_download_patch_fail()
{
  curl()
  {
    # this is a mock function to simulate curl behavior for testing
    printf "content\n\n400"
    return 0
  }
  download_patch '' "url"
  assert_equals_helper 'Download should fail' "$LINENO" 1 "$?"
}

function test_apply_patch_main_fail_when_arg_invalid()
{
  apply_patch_main --invalid
  assert_equals_helper 'Should fail when arg is invalid' "$LINENO" 22 "$?"
}

function test_apply_patch_main_success()
{
  curl()
  {
    # this is a mock function to simulate curl behavior for testing
    printf "content\n\n200"
    return 0
  }
  git()
  {
    # this is a mock function to simulate git behavior for testing
    return 0
  }

  output=$(apply_patch_main "https://example.com/patch.diff")
  assert_substring_match 'Should fail when git am fail' "$LINENO" "Patch successfully applied!" "$output"
}

function test_apply_patch_main_fail_when_git_am_fails()
{
  curl()
  {
    # this is a mock function to simulate curl behavior for testing
    printf "content\n\n200"
    return 0
  }
  git()
  {
    # this is a mock function to simulate git behavior for testing
    arg1="$1"
    arg2="$2"
    if [[ "$arg1 $arg2" == "am --quiet" ]]; then
      return 1
    fi
    return 0
  }
  output=$(apply_patch_main "https://example.com/patch.diff")
  assert_substring_match 'Should fail when git am fail' "$LINENO" "Repository has been rolled back to original state, patch was NOT aplied." "$output"
}

function test_apply_patch_main_fail_when_git_am_fails()
{
  curl()
  {
    # this is a mock function to simulate curl behavior for testing
    printf "content\n\n200"
    return 0
  }
  git()
  {
    # this is a mock function to simulate git behavior for testing
    arg1="$1"
    arg2="$2"
    if [[ "$arg1 $arg2" == "am --quiet" ]] || [[ "$arg1 $arg2" == "am --abort" ]]; then
      return 1
    fi
    return 0
  }
  output=$(apply_patch_main "https://example.com/patch.diff")
  assert_substring_match 'Should fail when git am fail' "$LINENO" "WARNING: Could not rollback automatically. Repository may be in an inconsistent state." "$output"
}

# Source shunit2 and run tests
invoke_shunit
