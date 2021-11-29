#!/bin/bash

include './tests/utils.sh'
include './src/kw_db.sh'

function oneTimeSetUp()
{
  declare -gr ORIGINAL_DIR="$PWD"
  declare -gr FAKE_DATA="$SHUNIT_TMPDIR/db_testing"

  declare -g DB_FILES

  DB_FILES="$(realpath './tests/samples/db_files')"

  mkdir -p "$FAKE_DATA"

  KW_DATA_DIR="$FAKE_DATA"
}

function oneTimeTearDown()
{
  rm -rf "$FAKE_DATA"
}

function test_execute_sql_script()
{
  local output
  local expected
  local ret

  output=$(execute_sql_script 'wrong/path/invalid_script.sql')
  ret="$?"
  assert_equals_helper 'Invalid script, error expected' "$LINENO" "$ret" 2

  output=$(execute_sql_script "$DB_FILES/init.sql")
  ret="$?"
  expected="Creating database: $KW_DATA_DIR/kw.db"
  assert_equals_helper 'No errors expected' "$LINENO" "$ret" 0
  assert_equals_helper 'DB file does not exist, should warn' "$LINENO" "$output" "$expected"

  assertTrue "($LINENO) DB file should be created" '[[ -f "$KW_DATA_DIR/kw.db" ]]'

  # Here we make use of SQLite's internal commands to return a list of the
  # tables in the db, the semicolon ensures sqlite3 closes
  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -cmd '.tables' -batch ';')
  expected='^pomodoro[[:space:]]+statistic[[:space:]]+tags[[:space:]]*$'
  assertTrue "($LINENO) Testing tables" '[[ "$output" =~ $expected ]]'

  execute_sql_script "$DB_FILES/insert.sql"
  ret="$?"
  assert_equals_helper 'No errors expected' "$LINENO" "$ret" 0

  # counting the number rows in each table
  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT count(id) FROM tags;')
  assert_equals_helper 'Expected 4 tags' "$LINENO" "$output" 4

  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT count(rowid) FROM pomodoro;')
  assert_equals_helper 'Expected 5 pomodoro entries' "$LINENO" "$output" 5

  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT count(rowid) FROM statistic;')
  assert_equals_helper 'Expected 4 statistic entries' "$LINENO" "$output" 4
}

invoke_shunit
