#!/usr/bin/env bash

include './src/kw_remote.sh'
include './tests/unit/utils.sh'

function setUp()
{
  export ORIGINAL_PATH="$PWD"

  export BASE_PATH_KW="${SHUNIT_TMPDIR}/.kw"
  export local_remote_config_file="${BASE_PATH_KW}/remote.config"
  export KW_ETC_DIR="${SHUNIT_TMPDIR}/.config/kw"
  export global_remote_config_file="${KW_ETC_DIR}/remote.config"

  # Create basic local env
  mkdir -p "$BASE_PATH_KW"
  touch "${BASE_PATH_KW}/remote.config"

  # Create basic global env
  mkdir -p "$KW_ETC_DIR"
  touch "${KW_ETC_DIR}/remote.config"

  options_values['GLOBAL']=''

  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO): setUp(): It was not possible to move into ${SHUNIT_TMPDIR}"
    return
  }
}

function tearDown()
{
  options_values['DEFAULT_REMOTE']=''

  cd "${ORIGINAL_PATH}" || {
    fail "($LINENO): tearDown(): It was not possible to move into ${ORIGINAL_PATH}"
    return
  }

  rm -rf "$SHUNIT_TMPDIR"
}

function test_add_new_remote_wrong_number_of_parameters()
{
  local output

  options_values['PARAMETERS']=''
  output=$(add_new_remote)
  assertEquals "($LINENO)" 22 "$?"

  options_values['PARAMETERS']='xpto'
  output=$(add_new_remote)
  assertEquals "($LINENO)" 22 "$?"

  options_values['PARAMETERS']='xpto lala uuu'
  output=$(add_new_remote)
  assertEquals "($LINENO)" 22 "$?"
}

function test_add_new_remote_no_kw_folder()
{
  local output

  rm -rf ".kw"
  rm -rf ".config/kw"

  options_values['PARAMETERS']='origin u'
  output=$(add_new_remote)

  assertEquals "($LINENO)" 22 "$?"
}

function test_add_new_remote_with_no_config_file()
{
  local output
  local expected_result

  rm "$local_remote_config_file"

  declare -a expected_result=(
    '#kw-default=origin'
    'Host origin'
    '  Hostname test-debian'
    '  Port 3333'
    '  User root'
  )

  options_values['PARAMETERS']='origin root@test-debian:3333'
  output=$(add_new_remote)

  mapfile -t final_result_array < "${BASE_PATH_KW}/remote.config"

  compare_array_values expected_result final_result_array "$LINENO"
}

function test_add_new_remote_multiple_different_instances()
{
  local output
  local final_result_array

  declare -a expected_result=(
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
  local final_result_array

  declare -a expected_result=(
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

function test_add_new_multiple_remotes_and_use_set_default_option()
{
  local output
  local final_result_array

  declare -a expected_result=(
    '#kw-default=debian-machine'
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

  options_values['DEFAULT_REMOTE_USED']=1
  options_values['DEFAULT_REMOTE']='debian-machine'
  options_values['PARAMETERS']='debian-machine root@test-debian'
  output=$(add_new_remote)
  options_values['DEFAULT_REMOTE']=''
  options_values['DEFAULT_REMOTE_USED']=''

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
  assertEquals "($LINENO)" 22 "$?"

  options_values['PARAMETERS']='one two'
  output=$(remove_remote)
  assertEquals "($LINENO)" 22 "$?"
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
  assertEquals "($LINENO)" '' "${final_result[*]}"
}

function test_remove_remote_try_to_remove_something_from_an_empty_file()
{
  local output

  # Remove a single remote
  touch "${local_remote_config_file}"
  options_values['PARAMETERS']='origin'
  output=$(remove_remote)
  mapfile -t final_result < "${BASE_PATH_KW}/remote.config"
  assertEquals "($LINENO)" '' "${final_result[*]}"
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
  assertEquals "($LINENO)" 22 "$?"
}

function test_rename_remote_wrong_number_of_parameters()
{
  local output

  options_values['PARAMETERS']=''
  output=$(rename_remote)
  assertEquals "($LINENO)" 22 "$?"

  options_values['PARAMETERS']='xpto'
  output=$(rename_remote)
  assertEquals "($LINENO)" 22 "$?"

  options_values['PARAMETERS']='xpto la lu'
  output=$(rename_remote)
  assertEquals "($LINENO)" 22 "$?"
}

function test_rename_remote_try_to_rename_something_that_does_not_exists()
{
  local output

  cp "${SAMPLES_DIR}/remote_samples/remote.config" "${BASE_PATH_KW}/remote.config"

  options_values['PARAMETERS']='ko uva'
  output=$(rename_remote)
  assertEquals "($LINENO)" 22 "$?"
}

function test_rename_remote_rename_to_something_that_already_exists()
{
  local output

  cp "${SAMPLES_DIR}/remote_samples/remote.config" "${BASE_PATH_KW}/remote.config"

  options_values['PARAMETERS']='fedora-test arch-test'
  output=$(rename_remote)
  assertEquals "($LINENO)" 22 "$?"
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
  assertEquals "($LINENO)" 22 "$?"
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
  parse_remote_options --add origin 'root@la:3333'
  assert_equals_helper 'Request add' "($LINENO)" 1 "${options_values['ADD']}"
  assert_equals_helper 'Remote options' "($LINENO)" 'origin root@la:3333 ' "${options_values['PARAMETERS']}"

  # Remove
  parse_remote_options --remove origin
  assert_equals_helper 'Request remove' "($LINENO)" 1 "${options_values['REMOVE']}"
  assert_equals_helper 'Remote options' "($LINENO)" 'origin ' "${options_values['PARAMETERS']}"

  # Rename
  parse_remote_options --rename origin xpto
  assert_equals_helper 'Request rename' "($LINENO)" 1 "${options_values['RENAME']}"
  assert_equals_helper 'Remote options' "($LINENO)" 'origin xpto ' "${options_values['PARAMETERS']}"
}

function test_list_remotes()
{
  local output

  declare -a expected_result=(
    'Default Remote: arch-test'
    'steamos'
    '- Hostname steamdeck'
    '- Port 8888'
    '- User jozzi'
    'arch-test'
    '- Hostname arch-tm'
    '- Port 22'
    '- User abc'
  )

  cp "${SAMPLES_DIR}/remote_samples/remote_simple.config" "${BASE_PATH_KW}/remote.config"

  output=$(list_remotes)
  compare_command_sequence '' "$LINENO" 'expected_result' "$output"
}

function test_list_remotes_invalid()
{
  rm "${local_remote_config_file}"
  output=$(list_remotes)
  assertEquals "($LINENO)" 22 "$?"

  rm -rf "${BASE_PATH_KW}"
  rm "${global_remote_config_file}"
  output=$(list_remotes)
  assertEquals "($LINENO)" 22 "$?"
}

function test_kw_remote_without_valid_option()
{
  # kw remote (no option nor parameter)
  parse_remote_options
  assertEquals "($LINENO)" 22 "$?"

  # kw remote <params>[...] (no options)
  parse_remote_options
  assertEquals "($LINENO)" 22 "$?"
}

function test_remove_remote_that_is_prefix_of_other_remote()
{
  local output

  declare -a expected_result=(
    'kworkflow'
    '- Hostname kworkflow-tm'
    '- Port 4321'
    '- User kworkflow'
  )

  cp "${SAMPLES_DIR}/remote_samples/remote_prefix.config" "${BASE_PATH_KW}/remote.config"

  options_values['PARAMETERS']='kw'
  remove_remote
  output=$(list_remotes)
  compare_command_sequence 'Should only remove the prefix remote' "$LINENO" 'expected_result' "$output"
}

function test_add_new_global_remote()
{
  local final_result_array
  local output

  declare -a expected_result=(
    '#kw-default=global'
    'Host galactical'
    '  Hostname milky-way'
    '  Port 1234'
    '  User hubble'
    'Host global'
    '  Hostname planet-earth'
    '  Port 5678'
    '  User newton'
    'Host universal'
    '  Hostname universe'
    '  Port 9999'
    '  User einstein'
  )

  cp "${SAMPLES_DIR}/remote_samples/remote_global.config" "${global_remote_config_file}"

  rm -rf "$BASE_PATH_KW"

  options_values['PARAMETERS']='universal einstein@universe:9999'
  output=$(add_new_remote)
  mapfile -t final_result_array < "${global_remote_config_file}"
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_remove_global_remote()
{
  local final_result_array
  local output

  declare -a expected_result=(
    'Host galactical'
    '  Hostname milky-way'
    '  Port 1234'
    '  User hubble'
  )

  cp "${SAMPLES_DIR}/remote_samples/remote_global.config" "${global_remote_config_file}"

  rm -rf "$BASE_PATH_KW"

  options_values['PARAMETERS']='global'
  output=$(remove_remote)
  mapfile -t final_result_array < "${global_remote_config_file}"
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_rename_global_remote()
{
  local final_result_array
  local output

  declare -a expected_result=(
    '#kw-default=existential'
    'Host galactical'
    '  Hostname milky-way'
    '  Port 1234'
    '  User hubble'
    'Host existential'
    '  Hostname planet-earth'
    '  Port 5678'
    '  User newton'
  )

  cp "${SAMPLES_DIR}/remote_samples/remote_global.config" "${global_remote_config_file}"

  rm -rf "$BASE_PATH_KW"

  options_values['PARAMETERS']='global existential'
  output=$(rename_remote)
  mapfile -t final_result_array < "${global_remote_config_file}"
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_set_default_global_remote()
{
  local final_result_array
  local output

  declare -a expected_result=(
    '#kw-default=galactical'
    'Host galactical'
    '  Hostname milky-way'
    '  Port 1234'
    '  User hubble'
    'Host global'
    '  Hostname planet-earth'
    '  Port 5678'
    '  User newton'
  )

  cp "${SAMPLES_DIR}/remote_samples/remote_global.config" "${global_remote_config_file}"

  rm -rf "$BASE_PATH_KW"

  options_values['DEFAULT_REMOTE']='galactical'
  output=$(set_default_remote)
  mapfile -t final_result_array < "${global_remote_config_file}"
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_list_global_remotes()
{
  local output

  declare -a expected_result=(
    'Default Remote: global'
    'galactical'
    '- Hostname milky-way'
    '- Port 1234'
    '- User hubble'
    'global'
    '- Hostname planet-earth'
    '- Port 5678'
    '- User newton'
  )

  cp "${SAMPLES_DIR}/remote_samples/remote_global.config" "${global_remote_config_file}"

  rm -rf "$BASE_PATH_KW"

  output=$(list_remotes)
  compare_command_sequence 'Should list the global remote.config if there is no local one' "$LINENO" 'expected_result' "$output"
}

function test_global_option_rename_remote()
{
  local final_result_array
  local output

  declare -a expected_result=(
    '#kw-default=existential'
    'Host galactical'
    '  Hostname milky-way'
    '  Port 1234'
    '  User hubble'
    'Host existential'
    '  Hostname planet-earth'
    '  Port 5678'
    '  User newton'
  )

  cp "${SAMPLES_DIR}/remote_samples/remote_global.config" "${global_remote_config_file}"

  options_values['PARAMETERS']='global existential'
  options_values['GLOBAL']='1'
  output=$(rename_remote)
  mapfile -t final_result_array < "${global_remote_config_file}"
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_global_options_set_default_remote()
{
  local final_result_array
  local output

  declare -a expected_result=(
    '#kw-default=galactical'
    'Host galactical'
    '  Hostname milky-way'
    '  Port 1234'
    '  User hubble'
    'Host global'
    '  Hostname planet-earth'
    '  Port 5678'
    '  User newton'
  )

  cp "${SAMPLES_DIR}/remote_samples/remote_global.config" "${global_remote_config_file}"

  options_values['DEFAULT_REMOTE']='galactical'
  options_values['GLOBAL']='1'
  output=$(set_default_remote)
  mapfile -t final_result_array < "${global_remote_config_file}"
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_global_option_list_remotes()
{
  local final_result_array
  local output

  declare -a expected_result=(
    '#kw-default=galactical'
    'Host galactical'
    '  Hostname milky-way'
    '  Port 1234'
    '  User hubble'
    'Host global'
    '  Hostname planet-earth'
    '  Port 5678'
    '  User newton'
  )

  cp "${SAMPLES_DIR}/remote_samples/remote_global.config" "${global_remote_config_file}"

  options_values['DEFAULT_REMOTE']='galactical'
  options_values['GLOBAL']='1'
  output=$(set_default_remote)
  mapfile -t final_result_array < "${global_remote_config_file}"
  compare_array_values expected_result final_result_array "$LINENO"
}

function test_global_option_list_remote_invalid()
{
  rm "${global_remote_config_file}"
  options_values['GLOBAL']='1'
  output=$(list_remotes)
  assertEquals "($LINENO)" 22 "$?"
}

function setup_for_symbolic_link_test()
{
  local symlink="${BASE_PATH_KW}/remote.config"
  local output
  local base_value

  # Specific test setup
  read -r -d '' base_value << 'EOF'
#kw-default=origin
Host origin
  Hostname test-debian
  Port 3333
  User root
Host galactical
  Hostname milky-way
  Port 1234
  User hubble
Host global
  Hostname planet-earth
  Port 5678
  User newton
EOF
  printf '%s\n' "$base_value" > "${BASE_PATH_KW}/remote.config"

  # Remove global remote
  mv "${SHUNIT_TMPDIR}/.config" "${SHUNIT_TMPDIR}/CONFIG"

  # Convert .kw to KW for create a symbolic link
  mv "$BASE_PATH_KW" "${SHUNIT_TMPDIR}/KW"

  # Create new .kw folder
  mkdir -p "$BASE_PATH_KW"
  ln --symbolic "${SHUNIT_TMPDIR}/KW/remote.config" "${symlink}"
}

function test_ensure_add_remote_does_not_destroy_symbolic_link()
{
  local symlink="${BASE_PATH_KW}/remote.config"
  local output

  setup_for_symbolic_link_test

  [[ -L "$symlink" ]]
  assert_equals_helper 'Symbolic link was not created' "$LINENO" 0 "$?"

  options_values['PARAMETERS']='origin root@test-deb:4444'
  output=$(add_new_remote)

  [[ -L "$symlink" ]]
  assert_equals_helper 'After add a new remote, link was destroyed' "$LINENO" 0 "$?"
}

function test_ensure_set_default_remote_does_not_destroy_the_symbolic_link()
{
  local symlink="${BASE_PATH_KW}/remote.config"
  local output

  setup_for_symbolic_link_test

  [[ -L "$symlink" ]]
  assert_equals_helper 'Symbolic link was not created' "$LINENO" 0 "$?"

  options_values['DEFAULT_REMOTE']='galactical'
  output=$(set_default_remote)

  [[ -L "$symlink" ]]
  assert_equals_helper 'After set default, link was destroyed' "$LINENO" 0 "$?"
}

function test_ensure_remove_remote_does_not_destroy_the_symbolic_link()
{
  local symlink="${BASE_PATH_KW}/remote.config"
  local output

  setup_for_symbolic_link_test

  [[ -L "$symlink" ]]
  assert_equals_helper 'Symbolic link was not created' "$LINENO" 0 "$?"

  options_values['PARAMETERS']='origin'
  output=$(remove_remote)

  [[ -L "$symlink" ]]
  assert_equals_helper 'After remove remote, link was destroyed' "$LINENO" 0 "$?"
}

function test_ensure_rename_remote_does_not_destroy_the_symbolic_link()
{
  local symlink="${BASE_PATH_KW}/remote.config"
  local output

  setup_for_symbolic_link_test

  [[ -L "$symlink" ]]
  assert_equals_helper 'Symbolic link was not created' "$LINENO" 0 "$?"

  options_values['PARAMETERS']='origin end'
  output=$(rename_remote)

  [[ -L "$symlink" ]]
  assert_equals_helper 'After rename remote, link was destroyed' "$LINENO" 0 "$?"
}

invoke_shunit
