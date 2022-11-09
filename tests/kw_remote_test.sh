#!/bin/bash

include './src/kw_remote.sh'
include './tests/utils.sh'

function setUp()
{
  export ORIGINAL_PATH="$PWD"

  export BASE_PATH_KW="${SHUNIT_TMPDIR}/.kw"
  export local_remote_config_file="${BASE_PATH_KW}/remote.config"

  # Create basic env
  mkdir -p "$BASE_PATH_KW"
  touch "${BASE_PATH_KW}/remote"

  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO): setIp(): It was not possible to move into ${SHUNIT_TMPDIR}"
    return
  }
}

function tearDown()
{
  cd "${ORIGINAL_PATH}" || {
    fail "($LINENO): tearDown(): It was not possible to move into ${ORIGINAL_PATH}"
    return
  }

  rm -rf "$BASE_PATH_KW"
}

function test_add_new_remote_wrong_number_of_parameters()
{
  local output

  options_values['PARAMETERS']=''
  output=$(add_new_remote)
  assertEquals "($LINENO)" "$?" 22

  options_values['PARAMETERS']='xpto'
  output=$(add_new_remote)
  assertEquals "($LINENO)" "$?" 22

  options_values['PARAMETERS']='xpto lala uuu'
  output=$(add_new_remote)
  assertEquals "($LINENO)" "$?" 22
}

function test_add_new_remote_no_kw_folder()
{
  local output

  rm -rf ".kw"

  options_values['PARAMETERS']='origin u'
  output=$(add_new_remote)

  assertEquals "($LINENO)" "$?" 22
}

function test_add_new_remote_new_remote_to_empty_file()
{
  local output
  local new_config_file
  local expected_result

  options_values['PARAMETERS']='origin root@test-debian:3333'
  output=$(add_new_remote)
  new_config_file=$(< "${BASE_PATH_KW}/remote.config")
}

function test_add_new_remote_multiple_different_instances()
{
  local output
  local new_config_file
  local final_result_array

  declare -a expected_result=(
    '#kw-default=origin'
    'Host origin'
    '  Hostname test-debian'
    '  Port 3333'
    '  User root'
    'Host debian-machine'
    '  Hostname test-debian'
    '  Port 22'
    '  User root'
    'Host arch-machine'
    '  Hostname la-debian'
    '  Port 22'
    '  User juca'
  )

  options_values['PARAMETERS']='origin root@test-debian:3333'
  output=$(add_new_remote)

  options_values['PARAMETERS']='debian-machine root@test-debian'
  output=$(add_new_remote)

  options_values['PARAMETERS']='arch-machine juca@la-debian'
  output=$(add_new_remote)

  mapfile -t final_result_array < "${BASE_PATH_KW}/remote.config"

  compare_array_values expected_result final_result_array "$LINENO"
}

function test_add_new_remote_multiple_entry_with_duplication()
{
  local output
  local new_config_file
  local final_result_array

  declare -a expected_result=(
    '#kw-default=origin'
    'Host origin'
    '  Hostname test-debian'
    '  Port 3333'
    '  User root'
    'Host debian-machine'
    '  Hostname test-debian'
    '  Port 22'
    '  User root'
    'Host arch-machine'
    '  Hostname la-debian'
    '  Port 22'
    '  User juca'
  )

  options_values['PARAMETERS']='origin root@test-debian:3333'
  output=$(add_new_remote)

  options_values['PARAMETERS']='debian-machine root@test-debian'
  output=$(add_new_remote)

  options_values['PARAMETERS']='debian-machine root@test-debian'
  output=$(add_new_remote)

  options_values['PARAMETERS']='arch-machine juca@la-debian'
  output=$(add_new_remote)

  options_values['PARAMETERS']='arch-machine juca@la-debian'
  output=$(add_new_remote)

  mapfile -t final_result_array < "${BASE_PATH_KW}/remote.config"

  compare_array_values expected_result final_result_array "$LINENO"
}

function test_remove_remote_wrong_parameters()
{
  local output

  options_values['PARAMETERS']=''

  output=$(remove_remote)
  assertEquals "($LINENO)" "$?" 22

  options_values['PARAMETERS']='one two'
  output=$(remove_remote)
  assertEquals "($LINENO)" "$?" 22
}

function test_remove_remote_only_one_entry()
{
  local output

  # Remove a single remote
  {
    printf 'Host origin\n'
    printf '  Hostname la\n'
    printf '  Port 333\n'
    printf '  User root\n'
  } >> "${local_remote_config_file}"

  options_values['PARAMETERS']='origin'
  output=$(remove_remote)
  mapfile -t final_result < "${BASE_PATH_KW}/remote.config"
  assertEquals "($LINENO)" "${final_result[*]}" ''
}

function test_remove_remote_try_to_remove_something_from_an_empty_file()
{
  local output

  # Remove a single remote
  touch "${local_remote_config_file}"
  options_values['PARAMETERS']='origin'
  output=$(remove_remote)
  mapfile -t final_result < "${BASE_PATH_KW}/remote.config"
  assertEquals "($LINENO)" "${final_result[*]}" ''
}

function test_remove_remote_drop_guard_between_others()
{
  local output

  # Remove a remote option in the middle
  cp "${SAMPLES_DIR}/remote_samples/remote.config" "${BASE_PATH_KW}/remote.config"

  options_values['PARAMETERS']='steamos'
  output=$(remove_remote)
  mapfile -t final_result_array < "${BASE_PATH_KW}/remote.config"
  declare -a expected_result=(
    'Host origin'
    '  Hostname deb-tm'
    '  Port 333'
    '  User root'
    'Host fedora-test'
    '  Hostname fedora-tm'
    '  Port 22'
    '  User abc'
    'Host arch-test'
    '  Hostname arch-tm'
    '  Port 22'
    '  User abc'
  )
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_remove_remote_drop_remote_where_its_name_is_part_of_the_remote()
{
  local output

  # Remove a remote option in the middle
  cp "${SAMPLES_DIR}/remote_samples/remote_2.config" "${BASE_PATH_KW}/remote.config"
  declare -a expected_result=(
    'Host origin'
    '  Hostname deb-tm'
    '  Port 333'
    '  User root'
    'Host fedora-test'
    '  Hostname steamos'
    '  Port 22'
    '  User steamos'
    'Host arch-test'
    '  Hostname arch-tm'
    '  Port 22'
    '  User abc'
  )

  # Remove a remote option in the middle

  options_values['PARAMETERS']='steamos'
  output=$(remove_remote)
  mapfile -t final_result_array < "${BASE_PATH_KW}/remote.config"

  compare_array_values expected_result final_result_array "$LINENO"
}

function test_remove_remote_try_to_drop_something_that_does_not_exists()
{
  local output

  cp "${SAMPLES_DIR}/remote_samples/remote.config" "${BASE_PATH_KW}/remote.config"

  # Remove a remote option in the middle
  options_values['PARAMETERS']='uva'
  output=$(remove_remote)
  assertEquals "($LINENO)" "$?" 22
}

function test_rename_remote_wrong_number_of_parameters()
{
  local output

  options_values['PARAMETERS']=''
  output=$(rename_remote)
  assertEquals "($LINENO)" "$?" 22

  options_values['PARAMETERS']='xpto'
  output=$(rename_remote)
  assertEquals "($LINENO)" "$?" 22

  options_values['PARAMETERS']='xpto la lu'
  output=$(rename_remote)
  assertEquals "($LINENO)" "$?" 22
}

function test_rename_remote_try_to_rename_something_that_does_not_exists()
{
  local output

  cp "${SAMPLES_DIR}/remote_samples/remote.config" "${BASE_PATH_KW}/remote.config"

  options_values['PARAMETERS']='ko uva'
  output=$(rename_remote)
  assertEquals "($LINENO)" "$?" 22
}

function test_rename_remote_rename_to_something_that_already_exists()
{
  local output

  cp "${SAMPLES_DIR}/remote_samples/remote.config" "${BASE_PATH_KW}/remote.config"

  options_values['PARAMETERS']='fedora-test arch-test'
  output=$(rename_remote)
  assertEquals "($LINENO)" "$?" 22
}

function test_rename_remote_change_a_valid_remote()
{
  local output

  cp "${SAMPLES_DIR}/remote_samples/remote.config" "${BASE_PATH_KW}/remote.config"

  declare -a expected_result=(
    'Host origin'
    '  Hostname deb-tm'
    '  Port 333'
    '  User root'
    'Host steamos'
    '  Hostname steamdeck'
    '  Port 8888'
    '  User jozzi'
    'Host fedora-test'
    '  Hostname fedora-tm'
    '  Port 22'
    '  User abc'
    'Host floss'
    '  Hostname arch-tm'
    '  Port 22'
    '  User abc'
  )

  options_values['PARAMETERS']='arch-test floss'
  output=$(rename_remote)
  mapfile -t final_result_array < "${BASE_PATH_KW}/remote.config"
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_set_default_remote_if_not_set_yet()
{
  local output

  cp "${SAMPLES_DIR}/remote_samples/remote.config" "${BASE_PATH_KW}/remote.config"

  declare -a expected_result=(
    '#kw-default=fedora-test'
    'Host origin'
    '  Hostname deb-tm'
    '  Port 333'
    '  User root'
    'Host steamos'
    '  Hostname steamdeck'
    '  Port 8888'
    '  User jozzi'
    'Host fedora-test'
    '  Hostname fedora-tm'
    '  Port 22'
    '  User abc'
    'Host arch-test'
    '  Hostname arch-tm'
    '  Port 22'
    '  User abc'
  )

  options_values['DEFAULT_REMOTE']='fedora-test'
  output=$(set_default_remote)
  mapfile -t final_result_array < "${BASE_PATH_KW}/remote.config"
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_set_default_remote_try_to_set_an_invalid_remote()
{
  local output

  cp "${SAMPLES_DIR}/remote_samples/remote_3.config" "${BASE_PATH_KW}/remote.config"

  options_values['DEFAULT_REMOTE']='palmares'
  output=$(set_default_remote)
  assertEquals "($LINENO)" "$?" 22
}

function test_set_default_remote_we_already_have_the_default_remote()
{
  local output

  cp "${SAMPLES_DIR}/remote_samples/remote_3.config" "${BASE_PATH_KW}/remote.config"

  declare -a expected_result=(
    '#kw-default=fedora-test'
    'Host origin'
    '  Hostname deb-tm'
    '  Port 333'
    '  User root'
    'Host steamos'
    '  Hostname steamdeck'
    '  Port 8888'
    '  User jozzi'
    'Host fedora-test'
    '  Hostname fedora-tm'
    '  Port 22'
    '  User abc'
    'Host arch-test'
    '  Hostname arch-tm'
    '  Port 22'
    '  User abc'
  )

  options_values['DEFAULT_REMOTE']='fedora-test'
  output=$(set_default_remote)
  mapfile -t final_result_array < "${BASE_PATH_KW}/remote.config"
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_parse_remote_options()
{

  # Add option
  parse_remote_options add origin root@la:3333
  assert_equals_helper 'Request add' "($LINENO)" "${options_values['ADD']}" 1
  assert_equals_helper 'Remote options' "($LINENO)" "${options_values['PARAMETERS']}" 'origin root@la:3333 '

  # Remove
  parse_remote_options remove origin
  assert_equals_helper 'Request remove' "($LINENO)" "${options_values['REMOVE']}" 1
  assert_equals_helper 'Remote options' "($LINENO)" "${options_values['PARAMETERS']}" 'origin '

  # Rename
  parse_remote_options rename origin xpto
  assert_equals_helper 'Request rename' "($LINENO)" "${options_values['RENAME']}" 1
  assert_equals_helper 'Remote options' "($LINENO)" "${options_values['PARAMETERS']}" 'origin xpto '
}

invoke_shunit
