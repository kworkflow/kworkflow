#!/usr/bin/env bash

include './src/signal_manager.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  declare -gr test_phrase="This is a phrase."
  declare -gr file_name="out.tmp"
  declare -gr original_dir="$PWD"
}

function setUp()
{
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO): It was not possible to cd into temporary directory"
    return
  }
}

function write_to_file()
{
  printf '%s\n' "$test_phrase" > "$file_name"
}

function test_default_handler()
{
  local -r expected=$'\nOh no! An interruption! See ya...'

  trap 'kill -s SIGTERM $!' SIGUSR1
  {
    signal_manager default_interrupt_handler SIGINT SIGTERM
    sleep infinity &
    printf '%s\n' $! > sleep_pid
    kill -s SIGUSR1 $$ # Send SIGUSR1 to parent process
    wait $!            # wait for SIGTERM
  } > out.tmp &

  wait $! # wait for SIGUSR1
  kill "$(cat sleep_pid)"
  assertEquals "($LINENO)" "$expected" "$(cat "$file_name")"

  rm -f out.tmp

  trap 'kill -s SIGINT $!' SIGUSR1
  {
    signal_manager default_interrupt_handler SIGINT SIGTERM
    sleep infinity &
    printf '%s\n' $! > sleep_pid
    kill -s SIGUSR1 $$ # Send SIGUSR1 to parent process
    wait $!            # wait for SIGINT
  } > out.tmp &

  wait $!
  kill "$(cat sleep_pid)"
  assertEquals "($LINENO)" "$expected" "$(cat "$file_name")"
}

function test_non_signal()
{
  local ret

  signal_manager : SIGNONEXISTENT
  ret="$?"
  assertFalse "($LINENO) Should have received an error." "$ret"

  signal_manager : 'HUP SIG'
  ret="$?"
  assertFalse "($LINENO) Should have received an error." "$ret"
}

function test_new_signal()
{
  # Enable job control. This allows us to send a SIGINT signal to this
  # very process without it being interrupted. The special parameter $$,
  # used below, is used to get the current process's PID
  set -m

  signal_manager write_to_file SIGINT
  kill -s SIGINT $$
  assertEquals "($LINENO)" "$test_phrase" "$(cat "$file_name")"

  signal_manager write_to_file SIGTERM
  kill -s SIGTERM $$
  assertEquals "($LINENO)" "$test_phrase" "$(cat "$file_name")"

  set +m
}

function test_signal_reset()
{
  local ret
  local output

  signal_manager write_to_file SIGINT SIGTERM
  signal_manager_reset
  output="$(trap -p)"

  printf '%s\n' "$output" | grep -q "trap -- 'default_interrupt_handler' SIGINT"
  ret="$?"
  assertTrue "($LINENO) Default handler not set." "$ret"

  printf '%s\n' "$output" | grep -q "trap -- 'default_interrupt_handler' SIGTERM"
  ret="$?"
  assertTrue "($LINENO) Default handler not set." "$ret"
}

function test_add_two_signals()
{
  signal_manager write_to_file SIGINT SIGTERM
  local -r output="$(trap)"
  local ret

  printf '%s\n' "$output" | grep -q "trap -- 'write_to_file' SIGINT"
  ret="$?"
  assertTrue "($LINENO) Trap not set" "$ret"

  printf '%s\n' "$output" | grep -q "trap -- 'write_to_file' SIGTERM"
  ret="$?"
  assertTrue "($LINENO) Trap not set" "$ret"
}

function test_compound_signal()
{
  signal_manager 'printf "%s\n" something; ls'
  ret="$?"
  assertFalse "($LINENO) Compound command accepted" "$ret"
}

invoke_shunit
