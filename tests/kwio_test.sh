#!/bin/bash

include './tests/utils'
include './src/kwio.sh'
include './src/kwlib.sh'

# NOTE: All executions off 'alert_completion' in this test file must be done
# inside a subshell (i.e. "$(alert_completion ...)"), because this function
# invokes other commands in the background. So if not done inside a subshell,
# the function will return before the background commands finish.

declare -A configurations
sound_file="$PWD/tests/.kwio_test_aux/sound.file"
visual_file="$PWD/tests/.kwio_test_aux/visual.file"

function suite
{
  suite_addTest "alert_completion_options_Test"
  suite_addTest "alert_completition_validate_config_file_options_Test"
  suite_addTest "alert_completion_visual_alert_Test"
  suite_addTest "alert_completion_sound_alert_Test"
}

function setUp
{
  mkdir -p tests/.kwio_test_aux
  configurations["sound_alert_command"]="touch $sound_file"
  configurations["visual_alert_command"]="touch $visual_file"
}

function tearDown
{
  rm -rf tests/.kwio_test_aux
}


function alert_completion_options_Test
{
  configurations["alert"]="n"

  rm -f "$sound_file" "$visual_file"
  $(alert_completion "" "--alert=vs")
  [[ -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's vs option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  $(alert_completion "" "--alert=sv")
  [[ -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's sv option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  $(alert_completion "" "--alert=s")
  [[ -f "$sound_file" && ! -f "$visual_file" ]]
  assertTrue "Alert's s option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  $(alert_completion "" "--alert=v")
  [[ ! -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's v option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  $(alert_completion "" "--alert=n")
  [[ ! -f "$sound_file" && ! -f "$visual_file" ]]
  assertTrue "Alert's n option didn't work." $?

  true
}

function alert_completition_validate_config_file_options_Test
{
  mkdir -p tests/.kwio_test_aux

  rm -f "$sound_file" "$visual_file"
  configurations["alert"]="vs"
  $(alert_completion "" "")
  [[ -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's vs option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  configurations["alert"]="sv"
  $(alert_completion "" "")
  [[ -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's sv option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  configurations["alert"]="s"
  $(alert_completion "" "")
  [[ -f "$sound_file" && ! -f "$visual_file" ]]
  assertTrue "Alert's s option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  configurations["alert"]="v"
  $(alert_completion "" "")
  [[ ! -f "$sound_file" && -f "$visual_file" ]]
  assertTrue "Alert's v option didn't work." $?

  rm -f "$sound_file" "$visual_file"
  configurations["alert"]="n"
  $(alert_completion "" "")
  [[ ! -f "$sound_file" && ! -f "$visual_file" ]]
  assertTrue "Alert's n option didn't work." $?

  true
}

function alert_completion_visual_alert_Test
{
  local output
  local expected="TESTING COMMAND"

  configurations["visual_alert_command"]="/bin/echo \$COMMAND"
  output="$(alert_completion "$expected" "--alert=v")"
  assertEquals "Variable v should exist." "$output" "$expected"
}

function alert_completion_sound_alert_Test
{
  local output
  local expected="TESTING COMMAND"

  configurations["sound_alert_command"]="/bin/echo \$COMMAND"
  output="$(alert_completion "$expected" "--alert=s")"
  assertEquals "Variable s should exist." "$output" "$expected"
}

invoke_shunit
