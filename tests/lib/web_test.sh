#!/bin/bash

include './src/lib/web.sh'
include './tests/utils.sh'

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

function test_replace_http_by_https()
{
  local output
  local expected='https://lore.kernel.org/'

  output=$(replace_http_by_https 'http://lore.kernel.org/')
  assert_equals_helper 'Expected https' "($LINENO)" "$output" "$expected"

  output=$(replace_http_by_https 'https://lore.kernel.org/')
  assert_equals_helper 'Expected https' "($LINENO)" "$output" "$expected"

  expected='lore.kernel.org/'
  output=$(replace_http_by_https 'lore.kernel.org/')
  assert_equals_helper 'No http prefix' "($LINENO)" "$?" 1
  assert_equals_helper 'Expected https' "($LINENO)" "$output" "$expected"
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

invoke_shunit
