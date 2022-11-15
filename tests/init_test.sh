#!/bin/bash

include './src/init.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  original_path="$PWD"

  export KW_SOUND_DIR="$PWD/tests/samples/share/sound/kw"
  export HOME="$SHUNIT_TMPDIR"
  export USER="kw_test"
  export KWORKFLOW="kw_dir_test"
  export PWD="$SHUNIT_TMPDIR/$KWORKFLOW"

  export PATH_TO_KW_DIR="$SHUNIT_TMPDIR/$KWORKFLOW/$KW_DIR"
  export PATH_TO_KW_CONFIG="${PATH_TO_KW_DIR}/kworkflow.config"
  export PATH_TO_KW_BUILD_CONFIG="${PATH_TO_KW_DIR}/build.config"
  export PATH_TO_KW_DEPLOY_CONFIG="${PATH_TO_KW_DIR}/deploy.config"
  export PATH_TO_KW_VM_CONFIG="${PATH_TO_KW_DIR}/vm.config"
  export PATH_TO_KW_NOTIFICATON_CONFIG="${PATH_TO_KW_DIR}/notification.config"
}

function setUp()
{
  export KW_ETC_DIR="$PWD/etc"

  mkdir -p "${SHUNIT_TMPDIR}/${KWORKFLOW}"
  options_values=()

  mk_fake_kernel_root "${SHUNIT_TMPDIR}/${KWORKFLOW}/"
  cd "${SHUNIT_TMPDIR}/${KWORKFLOW}/" || {
    fail "($LINENO): It was not possible to move to temporary directory"
    return
  }
}

function tearDown()
{
  [[ -d "$SHUNIT_TMPDIR" ]] && rm -rf "$SHUNIT_TMPDIR"

  cd "$original_path" || {
    fail "($LINENO): It was not possible to move to temporary directory"
    return
  }
}

function test_show_kernel_tree_message()
{
  local output

  # Remove kernel tree
  if [[ -d "${SHUNIT_TMPDIR}/${KWORKFLOW}/" ]]; then
    rm -rf "${SHUNIT_TMPDIR:?}/${KWORKFLOW}/"
  fi

  output=$(printf 'n' | init_kw)
  assertEquals "($LINENO):" 'This command should be run in a kernel tree.' "$output"
}

function test_standard_init_check_variable_replacements()
{
  local output
  local kworkflow_content

  output=$(init_kw)
  kworkflow_content=$(grep "$KW_SOUND_DIR" -o "$PATH_TO_KW_NOTIFICATON_CONFIG" | head -n 1)
  assertEquals "($LINENO): SOUNDPATH wasn't updated to $KW_SOUND_DIR" "$KW_SOUND_DIR" "$kworkflow_content"
}

function test_abort_init_update()
{
  local output
  local expected

  # First, create a config file
  output=$(init_kw)

  expect='Initialization aborted!'
  output=$(printf '%s\n' 'n' | init_kw)
  assertEquals "($LINENO): The init proccess didn't abort correctly" "$expect" "$output"
}

function test_use_arch_parameter()
{
  local output
  local kworkflow_content

  output=$(init_kw --arch arm64)
  kworkflow_content=$(grep arch= "$PATH_TO_KW_BUILD_CONFIG")
  assertEquals "($LINENO):" 'arch=arm64' "$kworkflow_content"
}

function test_try_to_set_an_invalid_arch()
{
  local output
  local kworkflow_content

  declare -a expected_content=(
    'This arch was not found in the arch directory'
    'You can use --force next time if you want to proceed anyway'
    'Available architectures:'
    'arm64'
    'x86_64'
    "Initialized kworkflow directory in $SHUNIT_TMPDIR/$KWORKFLOW/$KW_DIR based on $USER data"
  )

  output=$(init_kw --arch baroque)
  kworkflow_content=$(grep arch= "$PATH_TO_KW_BUILD_CONFIG")
  compare_command_sequence '' "$LINENO" 'expected_content' "$output"
}

function test_force_unsupported_arch()
{
  local output
  local kworkflow_content

  output=$(init_kw --arch baroque --force)
  kworkflow_content=$(grep arch= "$PATH_TO_KW_BUILD_CONFIG")
  assertEquals "($LINENO):" 'arch=baroque' "$kworkflow_content"
}

function test_set_remote()
{
  local output
  local kworkflow_content

  output=$(init_kw --remote juca@123.456.789.123:2222)
  kworkflow_content=$(grep ssh_user= "$PATH_TO_KW_CONFIG")
  assertEquals "($LINENO)" 'ssh_user=juca' "$kworkflow_content"

  kworkflow_content=$(grep ssh_ip= "$PATH_TO_KW_CONFIG")
  assertEquals "($LINENO)" 'ssh_ip=123.456.789.123' "$kworkflow_content"

  kworkflow_content=$(grep ssh_port= "$PATH_TO_KW_CONFIG")
  assertEquals "($LINENO)" 'ssh_port=2222' "$kworkflow_content"
}

function test_try_to_set_wrong_arch()
{
  local output
  local expected_content

  output=$(init_kw --remote ':8888')

  assertEquals "($LINENO)" 22 "$?"
}

function test_set_default_target()
{
  local output
  local kworkflow_content

  output=$(init_kw --target local)
  kworkflow_content=$(grep default_deploy_target= "$PATH_TO_KW_DEPLOY_CONFIG")
  assertEquals "($LINENO)" 'default_deploy_target=local' "$kworkflow_content"
}

function test_set_an_invalid_target()
{
  local output
  local kworkflow_content

  output=$(init_kw --target dartboard | tail -n +1 | head -n 1)
  kworkflow_content=$(grep default_deploy_target= "$PATH_TO_KW_CONFIG")
  assertEquals "($LINENO)" 'Target can only be local or remote.' "$output"
}

function test_force_wrong_etc_path()
{
  local kworkflow_content
  local output

  KW_ETC_DIR='break/on/purpose'

  output=$(init_kw -f) # avoids the overwrite prompt
  ret="$?"
  assertEquals "($LINENO): We forced an error and expected to catch it" 2 "$ret"
}

function test_get_template_name_noniteractive()
{
  options_values['TEMPLATE']=':x86-64'
  get_template_name
  assertEquals "($LINENO)" 'x86-64' "${options_values['TEMPLATE']}"

  options_values['TEMPLATE']=':rpi4-raspbian-64-cross-x86-arm'
  get_template_name

  assertEquals "($LINENO)" 'rpi4-raspbian-64-cross-x86-arm' "${options_values['TEMPLATE']}"
}

function test_get_an_invalid_template_name()
{
  local ret

  options_values['TEMPLATE']=':brasilia-sao-sebastiao'
  get_template_name
  ret="$?"

  assertEquals "($LINENO) We expected an invalid template" 2 "$ret"
}

function test_get_template_interactive()
{
  local output

  options_values['TEMPLATE']=''

  # Only get the final line
  output=$(printf '1\n' | get_template_name 'TEST_MODE' 2>&1 | tail -n 1)
  assertEquals "($LINENO)" 'x86-64' "$output"

  output=$(printf '2\n' | get_template_name 'TEST_MODE' 2>&1 | tail -n 1)
  assertEquals "($LINENO)" 'rpi4-raspbian-64-cross-x86-arm' "$output"
}

function test_config_file_already_exist_question()
{
  mkdir -p "${PWD}/${KW_DIR}"
  touch "${PWD}/${KW_DIR}/kworkflow.config"

  printf 'y\n' | config_file_already_exist_question
  assertFalse "($LINENO): We should not have config file" "[[ -f ${PWD}/${KW_DIR}/kworkflow.config ]]"
}

function test_config_file_already_exist_question_force()
{
  mkdir -p "$PWD/$KW_DIR"
  touch "$PWD/$KW_DIR/kworkflow.config"

  options_values['FORCE']=1

  config_file_already_exist_question
  assertFalse "($LINENO): We should not have config file" "[[ -f $PWD/$KW_DIR/kworkflow.config ]]"
}

function test_parse_init_options()
{
  unset options_values
  declare -gA options_values
  parse_init_options --force
  assertEquals "($LINENO):" 1 "${options_values['FORCE']}"

  unset options_values
  declare -gA options_values
  parse_init_options --arch arm
  assertEquals "($LINENO):" 'arm' "${options_values['ARCH']}"

  unset options_values
  declare -gA options_values
  parse_init_options --not-valid
  assertEquals "($LINENO)" 22 "$?"

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

  unset options_values
  declare -gA options_values
  parse_init_options --template='rpi4-raspbian-64-cross-x86-arm'
  assertEquals "($LINENO):" ':rpi4-raspbian-64-cross-x86-arm' "${options_values['TEMPLATE']}"

  unset options_values
  declare -gA options_values
  parse_init_options --template
  assertEquals "($LINENO):" ':' "${options_values['TEMPLATE']}"
}

invoke_shunit
