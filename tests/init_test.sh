#!/bin/bash

include './src/init.sh'
include './tests/utils.sh'

function setUp()
{
  export KW_ETC_DIR="$PWD/tests/samples"
  export KW_SOUND_DIR="$PWD/tests/samples/share/sound/kw"
  export HOME="$SHUNIT_TMPDIR"
  export USER="kw_test"
  export KWORKFLOW="kw_dir_test"
  export PWD="$SHUNIT_TMPDIR/$KWORKFLOW"
  mkdir -p "$SHUNIT_TMPDIR/$KWORKFLOW"
}

function test_init_kw()
{
  local kworkflow_content
  local path="$SHUNIT_TMPDIR/$KWORKFLOW/$KW_DIR"
  local path_config="$path/kworkflow.config"
  local output

  declare -a expected_content=(
    'This arch was not found in the arch directory'
    'You can use --force next time if you want to proceed anyway'
    'Available architectures:'
    'arm64'
    'x86_64'
    "Initialized kworkflow directory in $SHUNIT_TMPDIR/$KWORKFLOW/$KW_DIR based on $USER data"
  )

  output=$(printf 'n' | init_kw)
  assertEquals "($LINENO):" 'This command should be run in a kernel tree.' "$output"

  mk_fake_kernel_root "$SHUNIT_TMPDIR/$KWORKFLOW/"
  cd "$SHUNIT_TMPDIR/$KWORKFLOW/" || {
    fail "($LINENO): It was not possible to move to temporary directory"
    return
  }

  output=$(init_kw)
  kworkflow_content=$(grep "$USER" -o "$path_config" | head -n 1)
  assertEquals "($LINENO): USERKW wasn't updated to $USER" "$USER" "$kworkflow_content"

  kworkflow_content=$(grep "$KW_SOUND_DIR" -o "$path_config" | head -n 1)
  assertEquals "($LINENO): SOUNDPATH wasn't updated to $KW_SOUND_DIR" "$KW_SOUND_DIR" "$kworkflow_content"

  output=$(init_kw --force)
  if [[ ! -f "$path_config.old" ]]; then
    fail "($LINENO) We expected to find a 'kworkflow.config.old' file."
  fi

  expect='Initialization aborted!'
  output=$(printf '%s\n' 'n' | init_kw)
  assertEquals "($LINENO): The init proccess didn't abort correctly" "$expect" "$output"

  rm -rf "${path:?}"/*
  output=$(init_kw --arch arm64)
  kworkflow_content=$(grep arch= "$path_config")
  assertEquals "($LINENO):" 'arch=arm64' "$kworkflow_content"

  rm -rf "${path:?}"/*
  output=$(init_kw --arch baroque)
  kworkflow_content=$(grep arch= "$path_config")
  compare_command_sequence 'expected_content' "$output" "($LINENO)"

  output=$(init_kw --arch baroque --force)
  kworkflow_content=$(grep arch= "$path_config")
  assertEquals "($LINENO):" 'arch=baroque' "$kworkflow_content"

  rm -rf "${path:?}"/*
  output=$(init_kw --remote juca@123.456.789.123:2222)
  kworkflow_content=$(grep ssh_user= "$path_config")
  assertEquals "($LINENO)" 'ssh_user=juca' "$kworkflow_content"

  kworkflow_content=$(grep ssh_ip= "$path_config")
  assertEquals "($LINENO)" 'ssh_ip=123.456.789.123' "$kworkflow_content"

  kworkflow_content=$(grep ssh_port= "$path_config")
  assertEquals "($LINENO)" 'ssh_port=2222' "$kworkflow_content"

  rm -rf "${path:?}"/*
  expected_content=('Something went wrong with the remote option'
    'Invalid remote: :8888')
  output=$(init_kw --remote ':8888')
  assertEquals "($LINENO)" '22' "$?"
  compare_command_sequence 'expected_content' "$output" "($LINENO)"

  rm -rf "${path:?}"/*
  output=$(init_kw --target local)
  kworkflow_content=$(grep default_deploy_target= "$path_config")
  assertEquals "($LINENO)" 'default_deploy_target=local' "$kworkflow_content"

  rm -rf "${path:?}"/*
  output=$(init_kw --target dartboard | tail -n +1 | head -n 1)
  kworkflow_content=$(grep default_deploy_target= "$path_config")
  assertEquals "($LINENO)" 'Target can only be vm, local or remote.' "$output"

  export KW_ETC_DIR="break/on/purpose"
  output=$(init_kw -f) # avoids the overwrite prompt
  ret="$?"
  assertEquals "($LINENO): We forced an error and expected to catch it" "2" "$ret"
}

function test_parse_init_options()
{
  unset options_values
  declare -gA options_values
  parse_init_options --force
  assertEquals "($LINENO):" '1' "${options_values['FORCE']}"

  unset options_values
  declare -gA options_values
  parse_init_options --arch arm
  assertEquals "($LINENO):" 'arm' "${options_values['ARCH']}"

  unset options_values
  declare -gA options_values
  parse_init_options --not-valid
  assertEquals "($LINENO)" '22' "$?"

  unset options_values
  unset remote_parameters
  declare -gA options_values
  declare -gA remote_parameters
  parse_init_options --remote 'user@127.0.2.1:8888'
  assertEquals "($LINENO):" 'user@127.0.2.1:8888' "${options_values['REMOTE']}"

  unset options_values
  declare -gA options_values
  parse_init_options --target remote
  assertEquals "($LINENO):" 'remote' "${options_values['TARGET']}"
}

function test_get_git_config()
{
  local -A output
  local -A expected_configuration

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Unable to move to temp directory"
    return "$ret"
  }

  mk_fake_git

  # None of them are empty
  expected_configuration['name']=$(git config user.name)
  expected_configuration['email']=$(git config user.email)
  expected_configuration['editor']=$(git config core.editor)
  expected_configuration['branch']=$(git config init.defaultBranch)
  expected_configuration['configured']=0

  get_git_config output
  compare_array_values expected_configuration output "$LINENO"

  # One of them is empty
  expected_configuration['configured']=1

  # user.name
  git config --local user.name ''
  expected_configuration['name']=''

  get_git_config output
  compare_array_values expected_configuration output "$LINENO"

  git config --local user.name 'Xpto Lala'
  expected_configuration['name']='Xpto Lala'

  # user.email
  git config --local user.email ''
  expected_configuration['email']=''

  get_git_config output
  compare_array_values expected_configuration output "$LINENO"

  git config --local user.email 'test@email.com'
  expected_configuration['email']='test@email.com'

  # core.editor
  git config --local core.editor ''
  expected_configuration['editor']=''

  get_git_config output
  compare_array_values expected_configuration output "$LINENO"

  git config --local core.editor 'test_editor'
  expected_configuration['editor']='test_editor'

  # init.defaultBranch
  git config --local init.defaultBranch ''
  expected_configuration['branch']=''

  get_git_config output
  compare_array_values expected_configuration output "$LINENO"

  git config --local init.defaultBranch 'test_branch'
  expected_configuration['branch']='test_branch'

  # All configurations are empty
  git config --local user.name ''
  git config --local user.email ''
  git config --local core.editor ''
  git config --local init.defaultBranch ''

  expected_configuration['name']=''
  expected_configuration['email']=''
  expected_configuration['editor']=''
  expected_configuration['branch']=''

  get_git_config output
  compare_array_values expected_configuration output "$LINENO"

  rm -rf .git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Unable to move back from temp directory"
    return "$ret"
  }
}

function test_set_git_config_scope()
{
  local expected
  local output

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Unable to move to temp directory"
    return "$ret"
  }

  # User has no option of scope (is outside of work tree)
  expected='git config --global'
  output=$(printf 'Yes\n' | set_git_config_scope 2> /dev/null)
  assert_equals_helper 'User is outside of work tree' "$LINENO" "$expected" "$output"

  expected=''
  output=$(printf 'No\n' | set_git_config_scope 2> /dev/null)
  assert_equals_helper 'User is outside of work tree' "$LINENO" "$expected" "$output"

  mk_fake_git

  # User select local scope
  expected=$'git config --local'
  output=$(printf '1\n' | set_git_config_scope 2> /dev/null)
  assert_equals_helper 'User selected local scope' "$LINENO" "$expected" "$output"

  # User select global scope
  expected=$'git config --global'
  output=$(printf '2\n' | set_git_config_scope 2> /dev/null)
  assert_equals_helper 'User selected global scope' "$LINENO" "$expected" "$output"

  # User select a wrong scope first
  expected=$'git config --local'
  output=$(printf '42\n1\n' | set_git_config_scope 2> /dev/null)
  assert_equals_helper 'User selected wrong option, then local scope' "$LINENO" "$expected" "$output"

  expected=$'git config --global'
  output=$(printf '42\n2\n' | set_git_config_scope 2> /dev/null)
  assert_equals_helper 'User selected wronge option, then global scope' "$LINENO" "$expected" "$output"

  rm -rf .git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Unable to move back from temp directory"
    return "$ret"
  }
}

function test_interactive_set_user_git_info()
{
  local -A git_configurations
  local expected
  local output

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Unable to move to temp directory"
    return "$ret"
  }

  mk_fake_git

  # In a proper function, this array is builded by get_git_config
  git_configurations['name']='Xpto Lala'
  git_configurations['email']='test@email.com'
  git_configurations['editor']='test_editor'
  git_configurations['branch']='test_branch'
  git_configurations['configured']=0

  # Git is already fully configured
  expected=''
  output=$(interactive_set_user_git_info git_configurations 'TEST_MODE')
  assert_equals_helper 'git fully configured' "$LINENO" "$expected" "$output"

  # Individually configurations are empty
  git_configurations['configured']=1

  # user.name
  git_configurations['name']=''

  expected='git config --local user.name "Lala Xpto"'
  output=$(printf '1\nLala Xpto\n' | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 1)
  assert_equals_helper ' local name should be configured' "$LINENO" "$expected" "$output"

  expected='git config --global user.name "Xpto Lala"'
  output=$(printf '2\nXpto Lala\n' | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 1)
  assert_equals_helper 'global name should be configured' "$LINENO" "$expected" "$output"

  git_configurations['name']='Xpto Lala'

  # user.email
  git_configurations['email']=''

  expected='git config --local user.email "email@test.com"'
  output=$(printf '1\nemail@test.com\n' | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 1)
  assert_equals_helper 'local email should be configured' "$LINENO" "$expected" "$output"

  expected='git config --global user.email "test@email.com"'
  output=$(printf '2\ntest@email.com\n' | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 1)
  assert_equals_helper 'global email should be configured' "$LINENO" "$expected" "$output"

  expected='git config --global user.email "test@email.com"'
  output=$(printf '2\ntest&email.com\ntest@email.com\n' | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 1)
  assert_equals_helper 'global email should be configured' "$LINENO" "$expected" "$output"

  git_configurations['email']='test@email.com'

  # core.editor
  git_configurations['editor']=''
  expected='git config --local core.editor "editor_test"'
  output=$(printf '1\nYes\neditor_test\n' | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 1)
  assert_equals_helper 'local editor should be configured' "$LINENO" "$expected" "$output"

  expected='git config --global core.editor "test_editor"'
  output=$(printf '2\nYes\ntest_editor\n' | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 1)
  assert_equals_helper 'global editor should be configured' "$LINENO" "$expected" "$output"

  git_configurations['editor']='test_editor'

  # init.defaultBranch
  git_configurations['branch']=''

  expected='git config --local init.defaultBranch "branch_test"'
  output=$(printf '1\nYes\nbranch_test\n' | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 1)
  assert_equals_helper 'local branch should be configured' "$LINENO" "$expected" "$output"

  expected='git config --global init.defaultBranch "test_branch"'
  output=$(printf '2\nYes\ntest_branch\n' | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 1)
  assert_equals_helper 'global branch should be configured' "$LINENO" "$expected" "$output"

  git_configurations['branch']='test_branch'

  # Git is completely unconfigured
  git_configurations['name']=''
  git_configurations['email']=''
  git_configurations['editor']=''
  git_configurations['branch']=''

  expected=$'git config --local user.name "Lala Xpto"\n'
  expected+=$'git config --local user.email "email@test.com"\n'
  expected+=$'git config --local core.editor "editor_test"\n'
  expected+=$'git config --local init.defaultBranch "branch_test"'
  user_response=$'1\nLala Xpto\nemail@test.com\nYes\neditor_test\nYes\nbranch_test\n'
  output=$(printf '%s\n' "$user_response" | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 4)
  assert_equals_helper 'local git should be desconfigured' "$LINENO" "$expected" "$output"

  expected=$'git config --global user.name "Lala Xpto"\n'
  expected+=$'git config --global user.email "email@test.com"\n'
  expected+=$'git config --global core.editor "editor_test"\n'
  expected+=$'git config --global init.defaultBranch "branch_test"'
  user_response=$'2\nLala Xpto\nemail@test.com\nYes\neditor_test\nYes\nbranch_test\n'
  output=$(printf '%s\n' "$user_response" | interactive_set_user_git_info git_configurations 'TEST_MODE' 2> /dev/null | tail -n 4)
  assert_equals_helper 'global git should be desconfigured' "$LINENO" "$expected" "$output"

  rm -rf .git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Unable to move back from temp directory"
    return "$ret"
  }
}

invoke_shunit
