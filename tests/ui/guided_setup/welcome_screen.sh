#!/bin/bash

include './src/ui/guided_setup/welcome_screen.sh'
include './tests/utils.sh'

declare -gA screen_sequence=(
  ['SHOW_SCREEN']='welcome'
  ['SHOW_SCREEN_PARAMETER']=''
  ['RETURNING']=''
)

function test_welcome_setup()
{
  local target_array_list
  local output

  # shellcheck disable=SC2317
  function create_yes_no_message()
  {
    return 0
  }

  welcome_screen 'TEST_MODE'
  assert_equals_helper 'Expected build setup' "$LINENO" 'build_setup' "${screen_sequence['SHOW_SCREEN']}"
}

invoke_shunit
