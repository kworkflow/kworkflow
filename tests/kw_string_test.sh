#!/bin/bash

include './src/kw_string.sh'
include './tests/utils.sh'

function test_chop()
{
  local output
  local str_test='1234567'

  output=$(chop "$str_test")
  assert_equals_helper 'Chop did not work as expected' "$LINENO" '123456' "$output"

  output=$(chop "$output")
  assert_equals_helper 'Chop did not work as expected' "$LINENO" '12345' "$output"

  output=$(chop '')
  assert_equals_helper 'Expected an empty string' "$LINENO" "" "$output"
}

function test_last_char()
{
  local output
  local str_test='kworkflow'

  output=$(last_char "$str_test")
  assert_equals_helper 'We did not get the last char' "$LINENO" 'w' "$output"

  str_test='something$'
  output=$(last_char "$str_test")
  assert_equals_helper 'We did not get the last char' "$LINENO" '$' "$output"

  str_test=''
  output=$(last_char "$str_test")
  assert_equals_helper 'We did not get the last char' "$LINENO" '' "$output"
}

function test_str_is_a_number()
{
  local output
  local str_test=333

  str_is_a_number "$str_test"
  output="$?"
  assert_equals_helper 'We did not get the last char' "$LINENO" '0' "$output"

  str_is_a_number 234232
  output="$?"
  assert_equals_helper 'We did not get the last char' "$LINENO" '0' "$output"

  str_is_a_number 'kworkflow'
  output="$?"
  assert_equals_helper 'We did not get the last char' "$LINENO" '1' "$output"

  str_is_a_number '   73   '
  output="$?"
  assert_equals_helper 'Number around space, is a number' "$LINENO" '0' "$output"

  str_is_a_number ' -73 '
  output="$?"
  assert_equals_helper 'Negative number is a number' "$LINENO" '0' "$output"

}

function test_str_length()
{
  local output
  local string_sample="let's check the string lenght" # 29

  output=$(str_length "$string_sample")
  assert_equals_helper 'String lenght did not match' "$LINENO" 29 "$output"

  output=$(str_length '')
  assert_equals_helper 'Empty string should be 0 length' "$LINENO" 0 "$output"
}

function test_str_trim()
{
  local output
  local string_sample='This is a simple string'
  local expected_result='This is a s' # Trim at 11

  output=$(str_trim "$string_sample" 11)
  assert_equals_helper 'Wrong trim' "$LINENO" "$expected_result" "$output"

  output=$(str_trim "$string_sample" 1)
  assert_equals_helper 'We have an issue with 1 char trim' "$LINENO" 'T' "$output"

  output=$(str_trim "$string_sample" 100)
  assert_equals_helper 'Large trim value has problems' "$LINENO" "$string_sample" "$output"

  output=$(str_trim "$string_sample" 0)
  assert_equals_helper 'Trim 0 should be empty' "$LINENO" '' "$output"
}

function test_str_strip
{
  local output
  local string_sample='    lala xpto    '
  local expected_result='lala xpto'

  output=$(str_strip "$string_sample")
  assert_equals_helper 'Did not drop extra spaces' "$LINENO" "$expected_result" "$output"

  output=$(str_strip 'lala xpto    ')
  assert_equals_helper 'Did not drop extra spaces' "$LINENO" "$expected_result" "$output"

  output=$(str_strip '     lala xpto')
  assert_equals_helper 'Did not drop extra spaces' "$LINENO" "$expected_result" "$output"

  output=$(str_strip 'lala xpto')
  assert_equals_helper 'Did not drop extra spaces' "$LINENO" "$expected_result" "$output"

  output=$(str_strip "            Let's try to check things with contractions     ")
  expected_result="Let's try to check things with contractions"
  assert_equals_helper 'Did not drop extra spaces' "$LINENO" "$expected_result" "$output"
}

function test_str_remove_prefix()
{
  local output
  local string_sample='Hello world'
  local expected_result='world'

  output=$(str_remove_prefix "$string_sample" 'Hello ')
  assert_equals_helper 'Did not remove prefix' "$LINENO" "$expected_result" "$output"

  string_sample='/path/to/something'
  expected_result='something'
  output=$(str_remove_prefix "$string_sample" '/path/to/')
  assert_equals_helper 'Did not remove prefix' "$LINENO" "$expected_result" "$output"

  output=$(str_remove_prefix '' 're')
  expected_result=''
  assert_equals_helper 'There should be nothing to remove from an empty string' "$LINENO" "$expected_result" "$output"

  output=$(str_remove_prefix "$string_sample" '')
  assert_equals_helper 'String should have remained the same' "$LINENO" "$string_sample" "$output"

  output=$(str_remove_prefix '' '')
  assert_equals_helper 'Removing emptiness from emptiness should have remained emptiness' "$LINENO" '' "$output"
}

invoke_shunit
