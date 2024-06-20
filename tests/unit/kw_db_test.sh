#!/usr/bin/env bash

include './tests/unit/utils.sh'
include './src/lib/kw_db.sh'

function oneTimeSetUp()
{
  declare -gr ORIGINAL_DIR="$PWD"
  declare -gr FAKE_DATA="$SHUNIT_TMPDIR/db_testing"

  declare -g DB_FILES

  DB_FILES="$(realpath './tests/unit/samples/db_files')"

  mkdir -p "$FAKE_DATA"

  KW_DATA_DIR="$FAKE_DATA"
  KW_DB_DIR="$(realpath './database')"
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
  assert_equals_helper 'Invalid script, error expected' "$LINENO" 2 "$ret"

  output=$(execute_sql_script "$DB_FILES/init.sql")
  ret="$?"
  expected="Creating database: $KW_DATA_DIR/kw.db"
  assert_equals_helper 'No errors expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'DB file does not exist, should warn' "$LINENO" "$expected" "$output"

  assertTrue "($LINENO) DB file should be created" '[[ -f "$KW_DATA_DIR/kw.db" ]]'

  # Here we make use of SQLite's internal commands to return a list of the
  # tables in the db, the semicolon ensures sqlite3 closes
  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -cmd '.tables' -batch ';')
  expected='^fake_table[[:space:]]+pomodoro[[:space:]]+statistics[[:space:]]+tags[[:space:]]*$'
  assertTrue "($LINENO) Testing tables" '[[ "$output" =~ $expected ]]'

  execute_sql_script "$DB_FILES/insert.sql"
  ret="$?"
  assert_equals_helper 'No errors expected' "$LINENO" 0 "$ret"

  # counting the number rows in each table
  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT count(id) FROM tags;')
  assert_equals_helper 'Expected 4 tags' "$LINENO" 4 "$output"

  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT count(rowid) FROM pomodoro;')
  assert_equals_helper 'Expected 5 pomodoro entries' "$LINENO" 5 "$output"

  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT count(rowid) FROM statistics;')
  assert_equals_helper 'Expected 4 statistic entries' "$LINENO" 4 "$output"
}

function test_format_values_db()
{
  local output
  local expected
  local ret

  output=$(format_values_db 0)
  ret="$?"
  expected='No arguments given'
  assert_equals_helper 'Invalid db, error expected' "$LINENO" 22 "$ret"
  assert_equals_helper 'Expected error msg' "$LINENO" "$expected" "$output"

  output=$(format_values_db 3 'first' 'second' 'third')
  ret="$?"
  expected="('first','second','third')"
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  output=$(format_values_db 2 "some_func('lala xpto')" "somefunc2('lala xpto')")
  ret="$?"
  expected="(some_func('lala xpto'),somefunc2('lala xpto'))"
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  output=$(format_values_db 2 'first 1' 'second 1' 'first 2' 'second 2')
  ret="$?"
  expected="('first 1','second 1'),('first 2','second 2')"
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  output=$(format_values_db 1 "some 'quotes'")
  ret="$?"
  expected="('some ''quotes''')"
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  output=$(format_values_db 2 'first' 'NULL')
  ret="$?"
  expected="('first',NULL)"
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
}

function test_execute_command_db()
{
  local output
  local expected
  local ret
  local entries

  output=$(execute_command_db 'some cmd' 'wrong/path/invalid_db.db')
  ret="$?"
  expected='Database does not exist'
  assert_equals_helper 'Invalid db, error expected.' "$LINENO" 2 "$ret"
  assert_equals_helper 'Expected error msg.' "$LINENO" "$expected" "$output"

  output=$(execute_command_db 'SELECT * FROM tags;')
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT * FROM tags;')
  assert_equals_helper 'No error expected.' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output.' "$LINENO" "$expected" "$output"

  output=$(execute_command_db 'SELECT * FROM not_a_table;' 2>&1)
  ret="$?"
  expected='no such table: not_a_table'
  assert_equals_helper 'Invalid table.' "$LINENO" 1 "$ret"
  assert_substring_match 'Wrong output.' "($LINENO)" "$expected" "$output"

  output=$(execute_command_db 'SELEC * FROM tags;' 2>&1)
  ret="$?"
  expected='near "SELEC": syntax error'
  assert_equals_helper 'Invalid table.' "$LINENO" 1 "$ret"
  assert_substring_match 'Wrong output.' "($LINENO)" "$expected" "$output"

  entries="$(concatenate_with_commas name start_date)"

  output=$(execute_command_db "SELECT $entries FROM statistics;")
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT name,start_date FROM statistics;')
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Testing with concatenate_with_commas' "$LINENO" "$expected" "$output"
}

function test_insert_into()
{
  local output
  local expected
  local ret
  local entries
  local values

  # invalid
  output=$(insert_into table entries values 'wrong/path/invalid_db.db')
  ret="$?"
  expected='Database does not exist'
  assert_equals_helper 'Invalid db, error expected' "$LINENO" 2 "$ret"
  assert_equals_helper 'Expected error msg' "$LINENO" "$expected" "$output"

  output=$(insert_into '' entries values)
  ret="$?"
  expected='Empty table or values.'
  assert_equals_helper 'Empty table, error expected' "$LINENO" 22 "$ret"
  assert_equals_helper 'Expected error msg' "$LINENO" "$expected" "$output"

  output=$(insert_into table entries '')
  ret="$?"
  expected='Empty table or values.'
  assert_equals_helper 'Empty values, error expected' "$LINENO" 22 "$ret"
  assert_equals_helper 'Expected error msg' "$LINENO" "$expected" "$output"

  # valid
  insert_into 'tags' '(tag)' "('new tag')"
  ret="$?"
  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT tag FROM tags WHERE id = 5;')
  expected='new tag'
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  insert_into 'tags' '' "('6','other tag')"
  ret="$?"
  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT tag FROM tags WHERE id = 6;')
  expected='other tag'
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  insert_into 'tags' 'tag' "('yet another tag')"
  ret="$?"
  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT tag FROM tags WHERE id = 7;')
  expected='yet another tag'
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  insert_into 'pomodoro' '("tag_id","start_date","start_time","duration","description")' "(4,date('now'),time('now'),600,'some description')"
  ret="$?"
  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT "description" FROM pomodoro WHERE "tag_id" = 4;')
  expected='some description'
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  entries=$(concatenate_with_commas '"tag_id"' '"start_date"' '"start_time"' '"duration"' '"description"')
  values=$(format_values_db 5 '5' "date('now')" "time('now','+10 minutes')" '650' 'some description 2')
  insert_into pomodoro "$entries" "$values"
  ret="$?"
  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT "description" FROM pomodoro WHERE "tag_id" = 5;')
  expected='some description 2'
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Testing with format functions' "$LINENO" "$expected" "$output"

  entries=$(concatenate_with_commas id tag)
  values=$(format_values_db 2 8 'tag 8' 9 'tag 9')
  insert_into tags "$entries" "$values"
  ret="$?"
  output=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT tag FROM tags WHERE id >= 8;')
  expected=$'tag 8\ntag 9'
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Testing with format functions' "$LINENO" "$expected" "$output"
}

function test_select_from()
{
  local output
  local expected
  local ret
  local entries
  declare -A condition_array

  # invalid
  output=$(select_from table columns '' '' '' '' 'wrong/path/invalid_db.db')
  ret="$?"
  expected='Database does not exist'
  assert_equals_helper 'Invalid db, error expected' "$LINENO" 2 "$ret"
  assert_equals_helper 'Expected error msg' "$LINENO" "$expected" "$output"

  output=$(select_from '' "$entries" '' '')
  ret="$?"
  expected='Empty table.'
  assert_equals_helper 'Empty table, error expected' "$LINENO" 22 "$ret"
  assert_equals_helper 'Expected error msg' "$LINENO" "$expected" "$output"

  # valid
  output=$(select_from 'pomodoro' "$entries" '' '')
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT * FROM "pomodoro" ;')
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  entries=$(concatenate_with_commas '"start_date"' '"start_time"' '"description"')
  condition_array=(['start_time']='2021-11-18')
  output=$(select_from 'pomodoro' "$entries" 'condition_array')
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT "start_date","start_time","description" FROM "pomodoro" WHERE start_time = '2021-11-18' ;')
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  condition_array=(['start_time,=']='2021-11-18')
  output=$(select_from 'pomodoro' "$entries" 'condition_array')
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT "start_date","start_time","description" FROM "pomodoro" WHERE start_time = '2021-11-18' ;')
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  condition_array=(['start_time,<']='2021-11-18')
  output=$(select_from 'pomodoro' "$entries" 'condition_array')
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT "start_date","start_time","description" FROM "pomodoro" WHERE start_time < '2021-11-18' ;')
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  condition_array=(['start_time,<=']='2021-11-18')
  output=$(select_from 'pomodoro' "$entries" 'condition_array')
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT "start_date","start_time","description" FROM "pomodoro" WHERE start_time <= '2021-11-18' ;')
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  condition_array=(['start_time,>']='2021-11-18')
  output=$(select_from 'pomodoro' "$entries" 'condition_array')
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT "start_date","start_time","description" FROM "pomodoro" WHERE start_time > '2021-11-18' ;')
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  condition_array=(['start_time,>=']='2021-11-18')
  output=$(select_from 'pomodoro' "$entries" 'condition_array')
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT "start_date","start_time","description" FROM "pomodoro" WHERE start_time >= '2021-11-18' ;')
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  condition_array=(['start_time,!=']='2021-11-18')
  output=$(select_from 'pomodoro' "$entries" 'condition_array')
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT "start_date","start_time","description" FROM "pomodoro" WHERE start_time != '2021-11-18' ;')
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  condition_array=(['start_time,<>']='2021-11-18')
  output=$(select_from 'pomodoro' "$entries" 'condition_array')
  ret="$?"
  expected=$(sqlite3 "$KW_DATA_DIR/kw.db" -batch 'SELECT "start_date","start_time","description" FROM "pomodoro" WHERE start_time <> '2021-11-18' ;')
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
}

test_replace_into()
{
  local output
  local expected
  local ret

  # invalid operations
  output=$(replace_into table columns rows 'wrong/path/invalid_db.db')
  ret="$?"
  expected='Database does not exist'
  assert_equals_helper 'Invalid db, error expected' "$LINENO" 2 "$ret"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "$output"

  output=$(replace_into '' columns rows)
  ret="$?"
  expected='Empty table or rows.'
  assert_equals_helper 'Empty table, error expected' "$LINENO" 22 "$ret"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "$output"

  output=$(replace_into table columns '')
  ret="$?"
  expected='Empty table or rows.'
  assert_equals_helper 'Empty rows, error expected' "$LINENO" 22 "$ret"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "$output"

  # valid operation with non-existent row
  replace_into 'fake_table' '("name","attribute1","attribute2","rank")' "('someName','someAtt1','someAtt2','2')"
  ret="$?"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT 'f'.'name' FROM 'fake_table' AS 'f' WHERE 'f'.'name'='someName' ;")
  expected='someName'
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  # valid operation with existent row
  replace_into 'fake_table' '("name","attribute1","attribute2","rank")' "('someName','anotherAtt1','anotherAtt2','2')"
  ret="$?"
  assert_equals_helper 'No error expected' "$LINENO" 0 "$ret"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT count(*) FROM 'fake_table' AS 'f' WHERE 'f'.'name'='someName' ;")
  assert_equals_helper 'Wrong number of rows' "$LINENO" 1 "$output"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT 'f'.'attribute1' FROM 'fake_table' AS 'f' WHERE 'f'.'name'='someName' ;")
  expected='anotherAtt1'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
}

function test_remove_from()
{
  local columnns
  local values
  declare -A condition_array
  local output
  local expected
  local ret

  # invalid operations
  output=$(remove_from 'table' '' 'wrong/path/invalid_db.db')
  ret="$?"
  expected='Database does not exist'
  assert_equals_helper 'Invalid db, error expected' "$LINENO" 2 "$ret"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "$output"

  output=$(remove_from '' '')
  ret="$?"
  expected='Empty table or condition array.'
  assert_equals_helper 'Empty table, error expected' "$LINENO" 22 "$ret"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "$output"

  output=$(remove_from table '')
  ret="$?"
  expected='Empty table or condition array.'
  assert_equals_helper 'Empty condition array expected' "$LINENO" 22 "$ret"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "$output"

  # remove one row using one unique attribute
  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')
  values=$(format_values_db 4 'name1' 'att1' 'att2' '0')
  insert_into 'fake_table' "$columns" "$values"
  condition_array=(['name']='name1')
  remove_from 'fake_table' 'condition_array'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT * FROM 'fake_table' WHERE name='name1' ;")
  expected=''
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  # remove one row using one unique attribute and some non-unique
  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')
  values=$(format_values_db 4 'name1' 'att1' 'att2' '0')
  insert_into 'fake_table' "$columns" "$values"
  condition_array=(['name']='name1' ['attribute1']='att1' ['attribute2']='att2')
  remove_from 'fake_table' 'condition_array'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT * FROM 'fake_table' WHERE name='name1' ;")
  expected=''
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  # remove one row using non-unique attributes
  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')
  values=$(format_values_db 4 'name1' 'att1' 'att2' '0' 'name2' 'att1' 'ATT2' '0')
  insert_into 'fake_table' "$columns" "$values"
  condition_array=(['attribute1']='att1' ['attribute2']='att2')
  remove_from 'fake_table' 'condition_array'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT * FROM 'fake_table' WHERE name='name1' ;")
  expected=''
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name,attribute1,attribute2 FROM 'fake_table' WHERE name='name2' ;")
  expected='name2|att1|ATT2'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  # remove two rows using non-unique attribute
  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')
  values=$(format_values_db 4 'name1' 'att1' 'att2' '0')
  insert_into 'fake_table' "$columns" "$values"
  condition_array=(['attribute1']='att1')
  remove_from 'fake_table' 'condition_array'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name,attribute1,attribute2,rank FROM 'fake_table' WHERE attribute1='att1' ;")
  expected=''
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name,attribute1,attribute2,rank FROM 'fake_table' ;")

  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')
  values=$(format_values_db 4 \
    'name1' 'att1.3' 'att2.3' '0' \
    'name2' 'att1.3' 'att2.3' '1' \
    'name3' 'att1.3' 'att2.3' '2')
  insert_into 'fake_table' "$columns" "$values"
  condition_array=(['rank,<']='1')
  remove_from 'fake_table' 'condition_array'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name,attribute1,attribute2,rank FROM 'fake_table' WHERE attribute1='att1.3' ;")
  expected=$'name2|att1.3|att2.3|1\n'
  expected+='name3|att1.3|att2.3|2'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')
  values=$(format_values_db 4 \
    'name4' 'att1.4' 'att2.4' '0' \
    'name5' 'att1.4' 'att2.4' '1' \
    'name6' 'att1.4' 'att2.4' '2')
  insert_into 'fake_table' "$columns" "$values"
  condition_array=(['rank,>']='1')
  remove_from 'fake_table' 'condition_array'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name,attribute1,attribute2,rank FROM 'fake_table' WHERE attribute1='att1.4' ;")
  expected=$'name4|att1.4|att2.4|0\n'
  expected+='name5|att1.4|att2.4|1'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')
  values=$(format_values_db 4 \
    'name7' 'att1.5' 'att2.5' '0' \
    'name8' 'att1.5' 'att2.5' '1' \
    'name9' 'att1.5' 'att2.5' '2')
  insert_into 'fake_table' "$columns" "$values"
  condition_array=(['rank,<=']='1')
  remove_from 'fake_table' 'condition_array'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name,attribute1,attribute2,rank FROM 'fake_table' WHERE attribute1='att1.5' ;")
  expected='name9|att1.5|att2.5|2'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')
  values=$(format_values_db 4 \
    'name10' 'att1.6' 'att2.6' '0' \
    'name11' 'att1.6' 'att2.6' '1' \
    'name12' 'att1.6' 'att2.6' '2')
  insert_into 'fake_table' "$columns" "$values"
  condition_array=(['rank,>=']='1')
  remove_from 'fake_table' 'condition_array'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name,attribute1,attribute2,rank FROM 'fake_table' WHERE attribute1='att1.6' ;")
  expected='name10|att1.6|att2.6|0'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')
  values=$(format_values_db 4 \
    'name13' 'att7.1' 'att7.2' '0' \
    'name14' 'att7.1' 'att7.2' '1' \
    'name15' 'att7.1' 'att7.2' '2')
  insert_into 'fake_table' "$columns" "$values"
  condition_array=(['rank,!=']='1')
  remove_from 'fake_table' 'condition_array'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name,attribute1,attribute2,rank FROM 'fake_table' WHERE attribute1='att7.1' ;")
  expected='name14|att7.1|att7.2|1'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')
  values=$(format_values_db 4 \
    'name16' 'att8.1' 'att8.2' '0' \
    'name17' 'att8.1' 'att8.2' '1' \
    'name18' 'att8.1' 'att8.2' '2')
  insert_into 'fake_table' "$columns" "$values"
  condition_array=(['rank,<>']='1')
  remove_from 'fake_table' 'condition_array'
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name,attribute1,attribute2,rank FROM 'fake_table' WHERE attribute1='att8.1' ;")
  expected='name17|att8.1|att8.2|1'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
}

function test_update_into()
{
  local columnns
  local values
  declare -A condition_array
  declare -A updates_array
  local output
  local expected
  local ret

  # invalid operations
  output=$(update_into 'table' 'updates_array' '' 'wrong/path/invalid_db.db')
  ret="$?"
  expected='Database does not exist'
  assert_equals_helper 'Invalid db, error expected' "$LINENO" 2 "$ret"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "$output"

  output=$(update_into '' 'updates_array' '' '')
  ret="$?"
  expected='Empty table.'
  assert_equals_helper 'Empty table, error expected' "$LINENO" 22 "$ret"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "$output"

  output=$(update_into table 'update_array' '' '')
  ret="$?"
  expected='Empty condition or updates array.'
  assert_equals_helper 'Empty condition array expected' "$LINENO" 22 "$ret"
  assert_equals_helper 'Wrong error message' "$LINENO" "$expected" "$output"

  columns=$(concatenate_with_commas 'name' 'attribute1' 'attribute2' 'rank')

  values=$(format_values_db 4 \
    'name19' 'att1' 'att2' '10' \
    'name20' 'att1' 'att2' '11' \
    'name21' 'att1' 'att2' '2' \
    'name22' 'att1' 'att2' '2')
  insert_into 'fake_table' "$columns" "$values"

  # update one row using one unique attribute
  condition_array=(['name']='name19')
  updates_array=(['attribute1']='att1.1')
  update_into 'fake_table' 'updates_array' 'condition_array'
  ret="$?"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT attribute1 FROM 'fake_table' WHERE name='name19' ;")
  expected='att1.1'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" 0 "$ret"

  # update multiple rows using one unique attribute
  condition_array=(['name']='name19')
  updates_array=(['attribute1']='att1.2' ['attribute2']='att2.2' ['rank']='10')
  update_into 'fake_table' 'updates_array' 'condition_array'
  ret="$?"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT attribute1, attribute2, rank FROM 'fake_table' WHERE name='name19' ;")
  expected='att1.2|att2.2|10'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" 0 "$ret"

  # update one row using non unique attribute
  condition_array=(['rank']='2')
  updates_array=(['attribute1']='att1.3')
  update_into 'fake_table' 'updates_array' 'condition_array'
  ret="$?"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT attribute1 FROM 'fake_table' WHERE rank='2' ;")
  expected=$'att1.3\natt1.3'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" 0 "$ret"

  # update multiple rows using non unique attribute
  condition_array=(['rank,>=']='10')
  updates_array=(['attribute1']='att1.4' ['attribute2']='att2.4' ['rank']='3')
  update_into 'fake_table' 'updates_array' 'condition_array'
  ret="$?"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name,attribute1,attribute2,rank FROM 'fake_table' WHERE rank='3' ;")
  expected=$'name19|att1.4|att2.4|3\nname20|att1.4|att2.4|3'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" 0 "$ret"
}

function test_generate_where_clause()
{
  declare -A condition_array
  local output
  local expected
  local ret

  condition_array=(['attribute']='value')
  expected="WHERE attribute='value'"
  output="$(generate_where_clause 'condition_array')"
  ret="$?"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" 0 "$ret"

  condition_array=(['attribute,<']='value')
  expected="WHERE attribute<'value'"
  output="$(generate_where_clause 'condition_array')"
  ret="$?"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" 0 "$ret"

  condition_array=(['attribute,<=']='value')
  expected="WHERE attribute<='value'"
  output="$(generate_where_clause 'condition_array')"
  ret="$?"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" 0 "$ret"
}

function test_generate_set_clause()
{
  declare -A condition_array
  local output
  local expected
  local ret

  condition_array=(['attribute']='value')
  expected="attribute = 'value'"
  output="$(generate_set_clause 'condition_array')"
  ret="$?"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" 0 "$ret"

  condition_array=(['attribute1']='value1' ['attribute2']='value2' ['attribute3']='value3')
  expected="attribute1 = 'value1', attribute3 = 'value3', attribute2 = 'value2'"
  output="$(generate_set_clause 'condition_array')"
  ret="$?"
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" 0 "$ret"
}

invoke_shunit
