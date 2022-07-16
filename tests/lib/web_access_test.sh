#!/bin/bash

include './src/lib/web_access.sh'
include './tests/utils.sh'

oneTimeSetUp()
{
  export KW_CACHE_DIR='fake_cache'
}

function test_download()
{
  local output
  local expected
  local ret

  output=$(download '' '' '' 'TEST_MODE')
  ret="$?"
  expected='URL must not be empty.'
  assert_equals_helper 'We expected to get an error for an empty URL' "($LINENO)" "$ret" 22
  assert_equals_helper 'We expected an error message' "($LINENO)" "$output" "$expected"

  output=$(download 'http://some-url.com' '' '' 'TEST_MODE')
  expected="curl --silent 'http://some-url.com' --output 'fake_cache/page.xml'"
  assert_equals_helper 'We expected the correct curl command' "($LINENO)" "$output" "$expected"

  output=$(download 'http://some-url.com' 'some-file.html' '' 'TEST_MODE')
  expected="curl --silent 'http://some-url.com' --output 'fake_cache/some-file.html'"
  assert_equals_helper 'We expected a custom file name' "($LINENO)" "$output" "$expected"

  output=$(download 'http://some-url.com' 'some-file.html' 'alt_path' 'TEST_MODE')
  expected="curl --silent 'http://some-url.com' --output 'alt_path/some-file.html'"
  assert_equals_helper 'We expected a custom file name and path' "($LINENO)" "$output" "$expected"
}

invoke_shunit
