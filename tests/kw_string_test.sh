#!/bin/bash

include './src/kw_string.sh'
include './tests/utils'

function suite
{
  suite_addTest 'chop_Test'
  suite_addTest 'last_char_Test'
  suite_addTest 'str_is_a_number_Test'
}

function chop_Test
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

function last_char_Test
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

function str_is_a_number_Test
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
}

invoke_shunit
