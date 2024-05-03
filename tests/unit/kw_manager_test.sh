#!/bin/bash

include './src/kw_manage_contacts.sh'
include './tests/unit/utils.sh'

function oneTimeSetUp()
{
  declare -g DB_FILES

  export KW_ETC_DIR="${SHUNIT_TMPDIR}/etc/"
  export KW_CACHE_DIR="${SHUNIT_TMPDIR}/cache/"
  export KW_DATA_DIR="${SHUNIT_TMPDIR}"

  DB_FILES="$(realpath './tests/unit/samples/db_files')"
  KW_DB_DIR="$(realpath './database')"
}

function setUp()
{
  declare -gA options_values
  declare -gA set_confs

  setupDatabase
}

function tearDown()
{
  unset options_values
  unset set_confs

  tearDownDatabase
}

function setupDatabase()
{
  declare -g TEST_GROUP_NAME='TEST_GROUP'
  declare -g TEST_GROUP_ID

  execute_sql_script "${KW_DB_DIR}/kwdb.sql" > /dev/null 2>&1
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO \"${DATABASE_TABLE_GROUP}\" (name) VALUES (\"${TEST_GROUP_NAME}\");"
  TEST_GROUP_ID="$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT id FROM \"${DATABASE_TABLE_GROUP}\" WHERE name='${TEST_GROUP_NAME}';")"
}

function tearDownDatabase()
{
  is_safe_path_to_remove "${KW_DATA_DIR}/kw.db"
  if [[ "$?" == 0 ]]; then
    rm "${KW_DATA_DIR}/kw.db"
  fi
}

function test_validate_group_name()
{
  local expected
  local output
  local ret

  # invalid values
  output=$(validate_group_name '')
  ret="$?"
  expected='The group name is empty'
  assert_equals_helper 'Empty group should not be valid' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 61

  output=$(validate_group_name '012345678901234567890123456789012345678901234567890')
  ret="$?"
  expected='The group name must be less than 50 characters'
  assert_equals_helper 'Group name length should not be valid' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 75

  output=$(validate_group_name ',@#$!')
  ret="$?"
  expected='The group name must not contain special characters'
  assert_equals_helper 'Special character in group name should not be valid' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  output=$(validate_group_name 'validName')
  ret="$?"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_check_existent_group()
{
  local expected
  local output
  local ret

  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO \"${DATABASE_TABLE_GROUP}\" (name) VALUES ('existent_group');"

  # invalid values
  output=$(check_existent_group "$TEST_GROUP_NAME")
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" "$TEST_GROUP_ID"

  # valid values
  output=$(check_existent_group 'unexistent_name')
  ret="$?"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_create_email_group()
{
  local expected
  local output
  local ret

  # invalid cases
  output=$(create_email_group "$TEST_GROUP_NAME")
  ret="$?"
  expected='This group already exists'
  assert_equals_helper 'The group should not have been created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  output=$(create_email_group '')
  ret="$?"
  expected='The group name is empty'
  assert_equals_helper 'The group should not have been created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  output=$(create_email_group '012345678901234567890123456789012345678901234567890')
  ret="$?"
  expected='The group name must be less than 50 characters'
  assert_equals_helper 'The group should not have been created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  output=$(create_email_group ',@#$!')
  ret="$?"
  expected='The group name must not contain special characters'
  assert_equals_helper 'The group should not have been created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  # valid values
  create_email_group 'create_unexistent_email_group_name'
  ret="$?"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name FROM \"${DATABASE_TABLE_GROUP}\" WHERE name='create_unexistent_email_group_name';")
  expected='create_unexistent_email_group_name'
  assert_equals_helper 'The group should have been created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_create_group()
{
  local expected
  local output
  local ret

  # invalid cases
  output=$(create_group "$TEST_GROUP_NAME")
  ret="$?"
  expected='This group already exists'
  expected=$'Error while inserting group into the database with command:\nsqlite3 -init '
  expected+="${KW_DB_DIR}/kw.db ${KW_DATA_DIR}/kw.db"
  expected+='-batch "INSERT INTO email_group (name) VALUES ('TEST_GROUP');"'
  assertContains 'The group should not have been created' "$output" "$expected"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  # valid values
  create_group 'create_unexistent_group'
  ret="$?"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name FROM \"${DATABASE_TABLE_GROUP}\" WHERE name='create_unexistent_group';")
  expected='create_unexistent_group'
  assert_equals_helper 'The group should have been created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_remove_email_group()
{
  local expected
  local output
  local ret

  # invalid cases
  output=$(remove_email_group 'nonexistent_group')
  ret="$?"
  expected='Error, this group does not exist'
  assert_equals_helper 'Group should not have been removed' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected error' "$LINENO" "$ret" 22

  # valid values
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO \"${DATABASE_TABLE_GROUP}\" ('name') VALUES ('test_group4') ;"

  remove_email_group 'test_group4'
  ret="$?"
  expected=''
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT * FROM \"${DATABASE_TABLE_GROUP}\" WHERE name='test_group4' ;")
  assert_equals_helper 'Group should have been removed' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_remove_group()
{
  local expected
  local output
  local ret

  # invalid cases
  output=$(remove_group "nonexistent_group'")
  ret="$?"
  expected=$'Error while removing group from the database with command:\nsqlite3 -init '
  expected+="${KW_DB_DIR}/pre_cmd.sql \"${KW_DATA_DIR}/kw.db\" "
  expected+="-batch \"DELETE FROM email_group WHERE name='nonexistent_group'' ;\""

  assert_equals_helper 'Group should not have been removed' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected error' "$LINENO" "$ret" 22

  # valid values
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO \"${DATABASE_TABLE_GROUP}\" ('name') VALUES ('test_group4') ;"

  remove_group 'test_group4'
  ret="$?"
  expected=''
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT * FROM \"${DATABASE_TABLE_GROUP}\" WHERE name='test_group4' ;")
  assert_equals_helper 'Group should have been removed' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_manage_contacts_parser()
{
  local expected
  local output
  local ret

  parse_manage_contacts_options '--group-create' 'fake_group'
  expected='1'
  assert_equals_helper 'Set group-create' "$LINENO" "${options_values['GROUP_CREATE']}" "$expected"
  expected='fake_group'
  assert_equals_helper 'Set group-create' "$LINENO" "${options_values['GROUP']}" "$expected"

  parse_manage_contacts_options '-c' 'fake_group'
  expected='1'
  assert_equals_helper 'Set group-create' "$LINENO" "${options_values['GROUP_CREATE']}" "$expected"
  expected='fake_group'
  assert_equals_helper 'Set group-create' "$LINENO" "${options_values['GROUP']}" "$expected"

  parse_manage_contacts_options '--group-remove' 'fake_group'
  expected='fake_group'
  assert_equals_helper 'Set group-remove' "$LINENO" "${options_values['GROUP_REMOVE']}" "$expected"

  parse_manage_contacts_options '-r' 'fake_group'
  expected='fake_group'
  assert_equals_helper 'Set group-remove' "$LINENO" "${options_values['GROUP_REMOVE']}" "$expected"
}

invoke_shunit
