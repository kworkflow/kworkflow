#!/usr/bin/env bash

include './src/lib/web.sh'
include './tests/unit/utils.sh'

oneTimeSetUp()
{
  export KW_CACHE_DIR='fake_cache'

  cp --recursive "${SAMPLES_DIR}/web/." "$SHUNIT_TMPDIR"
}

function setUp()
{
  export ORIGINAL_PATH="$PWD"

  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO): setUp(): It was not possible to move into ${SHUNIT_TMPDIR}"
    return
  }
}

function tearDown()
{
  cd "${ORIGINAL_PATH}" || {
    fail "($LINENO): tearDown(): It was not possible to move into ${ORIGINAL_PATH}"
    return
  }
}

function test_download()
{
  local output
  local expected
  local ret

  output=$(download '' '' '' 'TEST_MODE')
  ret="$?"
  expected='URL must not be empty.'
  assert_equals_helper 'We expected to get an error for an empty URL' "($LINENO)" 22 "$ret"
  assert_equals_helper 'We expected an error message' "($LINENO)" "$expected" "$output"

  output=$(download 'http://some-url.com' '' '' 'TEST_MODE')
  expected="curl --silent 'http://some-url.com' --output 'fake_cache/page.xml'"
  assert_equals_helper 'We expected the correct curl command' "($LINENO)" "$expected" "$output"

  output=$(download 'http://some-url.com' 'some-file.html' '' 'TEST_MODE')
  expected="curl --silent 'http://some-url.com' --output 'fake_cache/some-file.html'"
  assert_equals_helper 'We expected a custom file name' "($LINENO)" "$expected" "$output"

  output=$(download 'http://some-url.com' 'some-file.html' 'alt_path' 'TEST_MODE')
  expected="curl --silent 'http://some-url.com' --output 'alt_path/some-file.html'"
  assert_equals_helper 'We expected a custom file name and path' "($LINENO)" "$expected" "$output"
}

function test_replace_http_by_https()
{
  local output
  local expected='https://lore.kernel.org/'

  output=$(replace_http_by_https 'http://lore.kernel.org/')
  assert_equals_helper 'Expected https' "($LINENO)" "$expected" "$output"

  output=$(replace_http_by_https 'https://lore.kernel.org/')
  assert_equals_helper 'Expected https' "($LINENO)" "$expected" "$output"

  expected='lore.kernel.org/'
  output=$(replace_http_by_https 'lore.kernel.org/')
  assert_equals_helper 'No http prefix' "($LINENO)" 1 "$?"
  assert_equals_helper 'Expected https' "($LINENO)" "$expected" "$output"
}

function test_is_html_file_with_non_html_files()
{
  local file_path

  file_path="${SHUNIT_TMPDIR}/inexistent.path"
  is_html_file "$file_path"
  assert_equals_helper 'Invalid file path should return 2' "$LINENO" 2 "$?"

  file_path="${SHUNIT_TMPDIR}/textfile.txt"
  touch "$file_path"
  printf 'Hey, I am just a\nsimple\nplain text\nor, if you prefer,\na .txt' > "$file_path"
  is_html_file "$file_path"
  assert_equals_helper 'Non HTML file should return 1' "$LINENO" 1 "$?"
}

function test_is_html_file_with_html_files()
{
  local file_path

  file_path="${SHUNIT_TMPDIR}/sample1.html"
  is_html_file "$file_path"
  assert_equals_helper 'Valid HTML file should return 0' "$LINENO" 0 "$?"

  file_path="${SHUNIT_TMPDIR}/sample2.html"
  is_html_file "$file_path"
  assert_equals_helper 'Valid HTML file should return 0' "$LINENO" 0 "$?"

  file_path="${SHUNIT_TMPDIR}/sample3.html"
  is_html_file "$file_path"
  assert_equals_helper 'Valid HTML file should return 0' "$LINENO" 0 "$?"

  file_path="${SHUNIT_TMPDIR}/sample4.html"
  is_html_file "$file_path"
  assert_equals_helper 'Valid HTML file should return 0' "$LINENO" 0 "$?"

  file_path="${SHUNIT_TMPDIR}/sample5.html"
  is_html_file "$file_path"
  assert_equals_helper 'Valid HTML file should return 0' "$LINENO" 0 "$?"

  file_path="${SHUNIT_TMPDIR}/sample6.html"
  is_html_file "$file_path"
  assert_equals_helper 'Valid HTML file should return 0' "$LINENO" 0 "$?"
}

function test_url_encode()
{
  local output
  local expected

  output=$(url_encode '')
  expected=''
  assert_equals_helper 'Should output an empty string' "$LINENO" "$expected" "$output"

  output=$(url_encode 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
  expected='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
  assert_equals_helper 'Should not alter valid ASCII letters' "$LINENO" "$expected" "$output"

  output=$(url_encode '0123456789')
  expected='0123456789'
  assert_equals_helper 'Should not alter valid ASCII numbers' "$LINENO" "$expected" "$output"

  output=$(url_encode '.~_-')
  expected='.~_-'
  assert_equals_helper 'Should not alter valid ASCII special characters' "$LINENO" "$expected" "$output"

  output=$(url_encode ' !"#$%&'"'"'()*+,/:;<=>?@[\]^`{|}')
  expected='%20%21%22%23%24%25%26%27%28%29%2A%2B%2C%2F%3A%3B%3C%3D%3E%3F%40%5B%5C%5D%5E%60%7B%7C%7D'
  assert_equals_helper 'Should percent-encode all invalid ASCII chars' "$LINENO" "$expected" "$output"

  output=$(url_encode '■éøπ…≤µ∂˚')
  expected='%E2%96%A0%C3%A9%C3%B8%CF%80%E2%80%A6%E2%89%A4%C2%B5%E2%88%82%CB%9A'
  assert_equals_helper 'Should correctly percent-encode non-ASCII chars' "$LINENO" "$expected" "$output"

  output=$(url_encode 'string to éncodî')
  expected='string%20to%20%C3%A9ncod%C3%AE'
  assert_equals_helper 'Wrong encoding of string' "$LINENO" "$expected" "$output"
}

invoke_shunit
