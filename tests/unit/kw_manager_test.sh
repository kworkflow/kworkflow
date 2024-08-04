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

function test_rename_existent_group()
{
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO \"${DATABASE_TABLE_GROUP}\" (name) VALUES ('old_group_name');"

  # invalid values
  output=$(rename_email_group 'unexistent_group' 'new_group_name')
  ret="$?"
  expected='This group does not exist so it can not be renamed'
  assert_equals_helper 'Expected no error' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  output=$(rename_email_group 'old_group_name' '')
  ret="$?"
  expected='The group name is empty'
  assert_equals_helper 'Expected no error' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  output=$(rename_email_group 'old_group_name' '012345678901234567890123456789012345678901234567890')
  ret="$?"
  expected='The group name must be less than 50 characters'
  assert_equals_helper 'Expected no error' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  output=$(rename_email_group 'old_group_name' '!@#$%^&,+')
  ret="$?"
  expected='The group name must not contain special characters'
  assert_equals_helper 'Expected no error' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  output=$(rename_email_group 'old_group_name' "nonexistent_group''")
  ret="$?"
  expected='The group name must not contain special characters'
  assert_equals_helper 'Expected no error' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  # valid values
  expected=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT id FROM \"${DATABASE_TABLE_GROUP}\" WHERE name='old_group_name';")
  rename_email_group 'old_group_name' 'new_group_name'
  ret="$?"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT id FROM \"${DATABASE_TABLE_GROUP}\" WHERE name='new_group_name';")
  assert_equals_helper 'Expected no error' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_rename_group()
{
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO \"${DATABASE_TABLE_GROUP}\" (name) VALUES ('old_group_name');"

  # invalid values
  output=$(rename_group 'old_group_name' "nonexistent_group'")
  ret="$?"
  expected=$'Error while removing group from the database with command:\nsqlite3 -init '
  expected+="${KW_DB_DIR}/pre_cmd.sql -cmd \"\" \"${KW_DATA_DIR}/kw.db\" "
  expected+="-batch \"UPDATE email_group SET name = 'nonexistent_group'' WHERE name='old_group_name' ;\""
  assertContains 'Expected no error' "$output" "$expected"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  # valid values
  expected=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT id FROM \"${DATABASE_TABLE_GROUP}\" WHERE name='old_group_name';")
  rename_group 'old_group_name' 'new_group_name'
  ret="$?"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT id FROM \"${DATABASE_TABLE_GROUP}\" WHERE name='new_group_name';")
  assert_equals_helper 'Expected no error' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_add_email_contacts()
{
  local expected
  local output
  local ret

  # invalid values
  output="$(add_email_contacts 'add_emmail_ctt <add_email_ctt@email.com>' 'unexistent_group')"
  ret="$?"
  expected='Error, ubable to add contacts to unexistent group'
  assert_equals_helper 'Expected no error' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  output="$(add_email_contacts '' "$TEST_GROUP_NAME")"
  ret="$?"
  expected='The contacts list is empty'
  assert_equals_helper 'Expected no error' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 61

  output="$(add_email_contacts 'add_emmail_ctt <add_ema il_ctt@email.com>' "$TEST_GROUP_NAME")"
  ret="$?"
  expected='Invalid email: add_ema il_ctt@email.com'
  assert_equals_helper 'Expected no error' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  # valid values
  output="$(add_email_contacts 'add_emmail_ctt <add_email_ctt@email.com>' "$TEST_GROUP_NAME")"
  ret="$?"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_split_contact_infos()
{
  local expected
  local output
  local ret
  local contacts_list
  declare -A output_arr

  # invalid values
  contacts_list="Test Contact 1 <test1@email.com>, Test Contact 1 <test1@email.com>"
  output="$(split_contact_infos "$contacts_list" 'output_arr')"
  ret="$?"
  expected='Error, Some of the contacts must have a repeated email'
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22
  assert_equals_helper 'Contact infos should not have been splitted' "$LINENO" "$expected" "$output"

  contacts_list="Test Contact 1 <>, Test Contact 1 <test1@email.com>"
  output="$(split_contact_infos "$contacts_list" 'output_arr')"
  ret="$?"
  expected='Error, Some of the contact names or emails must be empty'
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22
  assert_equals_helper 'Contact infos should not have been splitted' "$LINENO" "$expected" "$output"

  contacts_list="Test Contact 1 <test1@email.com>, <test2@email.com>"
  output="$(split_contact_infos "$contacts_list" 'output_arr')"
  ret="$?"
  expected='Error, Some of the contact names or emails must be empty'
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22
  assert_equals_helper 'Contact infos should not have been splitted' "$LINENO" "$expected" "$output"

  # valid values
  contacts_list="Test Contact 2 <test2@email.com>, Test Contact 3 <test3@email.com>"
  declare -A expected_arr=(
    ["test2@email.com"]="Test Contact 2"
    ["test3@email.com"]="Test Contact 3"
  )

  split_contact_infos "$contacts_list" 'output_arr'
  ret="$?"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0

  # compare array values
  compare_array_values 'expected_arr' 'output_arr' "$LINENO"

  #compare array keys
  expected="(${!expected_arr[*]})"
  output="(${!output_arr[*]})"
  assert_equals_helper 'Contact keys splitted incorrectly' "$LINENO" "$expected" "$output"
}

function test_check_infos_sintaxe()
{
  local expected
  local output
  local ret

  # invalid values
  output="$(check_infos_sintaxe 'Test Contact >test@email.com>')"
  ret="$?"
  expected='Syntax error in the contacts list, there is a missing "<" in some of the contacts <email>'
  assert_equals_helper 'Contact infos should be wrong' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  output="$(check_infos_sintaxe 'Test Contact <test@email.com<')"
  ret="$?"
  expected='Syntax error in the contacts list, there is a missing ">" in some of the contacts <email>'
  assert_equals_helper 'Contact infos should be wrong' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  output="$(check_infos_sintaxe 'Test Contact >test@email.com<')"
  ret="$?"
  expected='Syntax error in the contacts list, the contact info should be like: name <email>'
  assert_equals_helper 'Contact infos should be wrong' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  output="$(check_infos_sintaxe 'Test Contact <<test@email.com>')"
  ret="$?"
  expected='Syntax error in the contacts list, there is a remaining "<" in some of the contacts <email>'
  assert_equals_helper 'Contact infos should be wrong' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  output="$(check_infos_sintaxe 'Test Contact <test@email.com>>')"
  ret="$?"
  expected='Syntax error in the contacts list, there is a remaining ">" in some of the contacts <email>'
  assert_equals_helper 'Contact infos should be wrong' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  #valid values
  output="$(check_infos_sintaxe 'Test Contact <test@email.com>')"
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 0
}

function test_validate_contact_infos()
{
  local expected
  local output
  local ret

  # invalid values
  output="$(validate_contact_infos 'email@mail.com' '')"
  ret="$?"
  expected='Error, Some of the contact names or emails must be empty'
  assert_equals_helper 'Contact infos should be wrong' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 61

  output="$(validate_contact_infos '' 'Name')"
  ret="$?"
  expected='Error, Some of the contact names or emails must be empty'
  assert_equals_helper 'Contact infos should be wrong' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 61

  output="$(validate_contact_infos 'email' 'Name')"
  ret="$?"
  expected='Invalid email: email'
  assert_equals_helper 'Contact infos should be wrong' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  # valid values
  validate_contact_infos 'email@mail.com' 'Name'
  ret="$?"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_add_contacts()
{
  local expected
  local output
  local ret

  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO \"${DATABASE_TABLE_CONTACT}\" (name,email) VALUES ('','testaddctt0@email.com');"

  # invalid values
  declare -A _contacts_arr=(
    ['testaddctt0@email.com']='Test Add Contact 0'
  )
  output=$(add_contacts '_contacts_arr')
  ret="$?"
  expected=$'Error while trying to insert contact into the database with the command:\nsqlite3 -init '
  expected+="${KW_DB_DIR}/pre_cmd.sql \"${KW_DATA_DIR}/kw.db\" "
  expected+="-batch \"INSERT INTO email_contact (name, email) VALUES ('Test Add Contact 0','testaddctt0@email.com');\""
  assertContains 'Contact should not have been created' "$output" "$expected"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 22

  # valid values
  _contacts_arr=(
    ['testaddctt1@email.com']='Test Add Contact 1'
  )

  add_contacts '_contacts_arr'
  ret="$?"
  output="$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name, email FROM \"${DATABASE_TABLE_CONTACT}\" WHERE email LIKE 'testaddctt%';")"
  expected='|testaddctt0@email.com
Test Add Contact 1|testaddctt1@email.com'
  assert_equals_helper 'Contact was not created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0

  _contacts_arr=(
    ['testaddctt2@email.com']='Test Add Contact 2'
    ['testaddctt3@email.com']='Test Add Contact 3'
  )

  add_contacts '_contacts_arr'
  ret="$?"
  output="$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name, email FROM \"${DATABASE_TABLE_CONTACT}\" WHERE email LIKE 'testaddctt%';")"
  expected='|testaddctt0@email.com
Test Add Contact 1|testaddctt1@email.com
Test Add Contact 2|testaddctt2@email.com
Test Add Contact 3|testaddctt3@email.com'
  assert_equals_helper 'Contacts were not created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0

  _contacts_arr=(
    ['testaddctt4@email.com']='Test Add Contact 4'
    ['testaddctt4@email.com']='Test Add Contact 4'
  )
  add_contacts '_contacts_arr'
  ret="$?"
  output="$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name, email FROM \"${DATABASE_TABLE_CONTACT}\" WHERE email='testaddctt4@email.com';")"
  expected='Test Add Contact 4|testaddctt4@email.com'
  assert_equals_helper 'Contacts were not created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0

  _contacts_arr=(
    ['testaddctt4@email.com']='Test Add Contact 4.1'
  )

  (printf 'y\n' | add_contacts '_contacts_arr')

  ret="$?"
  output="$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name, email FROM \"${DATABASE_TABLE_CONTACT}\" WHERE email='testaddctt4@email.com';")"
  expected='Test Add Contact 4|testaddctt4@email.com'
  assert_equals_helper 'Contacts were not created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0

  _contacts_arr=(
    ['testaddctt4@email.com']='Test Add Contact 4.2'
  )

  (printf 'n\n' | add_contacts '_contacts_arr')
  ret="$?"
  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT name FROM \"${DATABASE_TABLE_CONTACT}\" WHERE email='testaddctt4@email.com';")
  expected='Test Add Contact 4.2'
  assert_equals_helper 'Contacts were not created' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0
}

function test_add_contact_group()
{
  declare -A _contacts_arr
  local group_id
  local expected
  local output
  local ret

  # valid cases
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO \"${DATABASE_TABLE_GROUP}\" ('name') VALUES ('add_contact_group');"
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO \"${DATABASE_TABLE_CONTACT}\" (name, email) VALUES ('test contact group', 'testaddcttgp1@email.com');"
  sqlite3 "${KW_DATA_DIR}/kw.db" -batch "INSERT INTO \"${DATABASE_TABLE_CONTACT}\" (name, email) VALUES ('test contact group', 'testaddcttgp2@email.com');"

  group_id=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT id FROM \"${DATABASE_TABLE_GROUP}\" WHERE name='add_contact_group';")
  expected=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT id FROM \"${DATABASE_TABLE_CONTACT}\" WHERE name='test contact group' ;")

  _contacts_arr=(
    ['testaddcttgp1@email.com']='test contact group 1'
    ['testaddcttgp2@email.com']='test contact group 2'
  )

  add_contact_group _contacts_arr "$group_id"
  ret="$?"

  output=$(sqlite3 "${KW_DATA_DIR}/kw.db" -batch "SELECT contact_id FROM \"${DATABASE_TABLE_CONTACT_GROUP}\" WHERE group_id=\"${group_id}\";")
  assert_equals_helper 'Expected successful addition of contacts to group' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0

  # invalid cases
  output=$(add_contact_group _contacts_arr "$group_id")
  ret="$?"
  expected=""
  assert_equals_helper 'Expected no addition as contacts are already in the group' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected no error' "$LINENO" "$ret" 0

  _contacts_arr=(['nonexistent@example.com']='')
  output=$(add_contact_group _contacts_arr "$group_id")
  ret="$?"
  expected=$'Error while trying to insert contact group into the database with the command:\nsqlite3 -init '
  expected+="${KW_DB_DIR}/pre_cmd.sql \"${KW_DATA_DIR}/kw.db\" "
  expected+="-batch \"INSERT INTO email_contact_group (contact_id, group_id) VALUES ('','2');\""
  assertContains 'Expected sql error - Foreign key contraint failed' "$output" "$expected"
  assert_equals_helper 'Expected error' "$LINENO" "$ret" 22
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

  parse_manage_contacts_options '--group-rename' 'fake_group:new_group'
  expected='fake_group:new_group'
  assert_equals_helper 'Set group-rename' "$LINENO" "${options_values['GROUP_RENAME']}" "$expected"

  parse_manage_contacts_options '--group-add' 'group:ctt1 <email1>, ctt2 <email2>'
  expected='group:ctt1 <email1>, ctt2 <email2>'
  assert_equals_helper 'Set group add' "$LINENO" "${options_values['GROUP_ADD']}" "$expected"
}

invoke_shunit
