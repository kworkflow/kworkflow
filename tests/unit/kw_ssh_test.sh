#!/bin/bash

include './src/kw_ssh.sh'
include './tests/unit/utils.sh'

### SSH tests ###
#
# NOTE: We're not testing the ssh command here, just the kw ssh operation
#

function oneTimeSetUp()
{
  export TEST_PATH="$SHUNIT_TMPDIR/test_path"
  export original_dir="$PWD"
}

function setUp()
{
  export INVALID_ARG='Invalid arguments'
  export NO_SUCH_FILE='No such file'
  export SSH_OK='ssh -p 3333 juca@127.0.0.1'

  mkdir -p "$TEST_PATH"
  mkdir -p "${SHUNIT_TMPDIR}/.kw"
  cp "${KW_REMOTE_SAMPLES_DIR}/remote.config" "${SHUNIT_TMPDIR}/.kw"
  cp -f 'tests/unit/samples/dmesg' "$TEST_PATH"

  remote_parameters['REMOTE_USER']=''
  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_FILE']=''
  remote_parameters['REMOTE_FILE_HOST']=''
  options_values['CMD']=''
  options_values['SCRIPT']=''

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  populate_remote_info ''
}

function tearDown()
{
  cd "$original_dir" || {
    fail "($LINENO) It was not possible to back to the kw folder"
    return
  }
}

function test_parser_ssh_options_erros()
{
  local ret
  local substring_output
  local error

  parser_ssh_options --lala
  ret="$?"
  assertTrue "($LINENO): We expected a 22 for --lala parameter" '[[ $ret -eq 22 ]]'

  parser_ssh_options -c
  substring_output="ssh: option requires an argument -- 'c'"
  error="${options_values['ERROR']}"
  assertTrue "($LINENO): We should fail since -c expects a parameter" \
    '[[ $substring_output =~ $error ]]'

  parser_ssh_options -s
  substring_output="ssh: option requires an argument -- 's'"
  error="${options_values['ERROR']}"
  assertTrue "($LINENO): We expected a failure since -s expected a parameter" \
    '[[ $substring_output =~ $error ]]'
}

function test_parser_ssh_options()
{
  parser_ssh_options --script 'something/xpto/la'
  assertEquals "($LINENO)" 'something/xpto/la' "${options_values['SCRIPT']}"

  parser_ssh_options --command 'ls -lah'
  assertEquals "($LINENO)" 'ls -lah' "${options_values['CMD']}"

  parser_ssh_options --verbose
  assertEquals "($LINENO)" '1' "${options_values['VERBOSE']}"

  parser_ssh_options --remote 'jozzi@something:3232'
  assertEquals "($LINENO)" 'something' "${remote_parameters['REMOTE_IP']}"
}

function test_kw_ssh_main_no_parameter()
{
  local output

  declare -a expected_cmd=(
    "ssh -q -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 -F ${SHUNIT_TMPDIR}/.kw/remote.config origin exit"
    "ssh -F ${SHUNIT_TMPDIR}/.kw/remote.config origin"
  )

  # Remote
  output=$(kw_ssh_main 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_kw_ssh_main_command()
{
  local output

  declare -a expected_cmd=(
    "ssh -q -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 -F ${SHUNIT_TMPDIR}/.kw/remote.config origin exit"
    "ssh -F ${SHUNIT_TMPDIR}/.kw/remote.config origin pwd"
  )

  output=$(kw_ssh_main 'TEST_MODE' -c 'pwd')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  output=$(kw_ssh_main 'TEST_MODE' --command "ls /etc/" 2>&1)
  expected_cmd[1]="ssh -F ${SHUNIT_TMPDIR}/.kw/remote.config origin ls /etc/"
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_kw_ssh_main_script()
{
  local output
  local msg

  ret=$(kw_ssh_main 'TEST_MODE' -s "/not/a/valid/path/xpto" 2>&1)
  msg="$NO_SUCH_FILE: /not/a/valid/path/xpto"
  assertTrue "($LINENO): We expected a substring '$msg', but we got '$ret'" \
    '[[ $ret =~ "$msg" ]]'

  declare -a expected_cmd=(
    "ssh -q -o StrictHostKeyChecking=accept-new -o BatchMode=yes -o ConnectTimeout=5 -F ${SHUNIT_TMPDIR}/.kw/remote.config origin exit"
    "ssh -F ${SHUNIT_TMPDIR}/.kw/remote.config origin \"bash -s\" -- < $TEST_PATH/dmesg"
  )

  output=$(kw_ssh_main 'TEST_MODE' -s "${TEST_PATH}/dmesg" 2>&1)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_handle_ssh_with_config_file()
{
  local output
  local expected_result

  touch 'ssh_config'

  remote_parameters['REMOTE_FILE']="${PWD}/ssh_config"
  remote_parameters['REMOTE_FILE_HOST']='target'
  options_values['VERBOSE']='TEST_MODE'

  output=$(handle_ssh)
  expected_result="ssh -F ${PWD}/ssh_config target"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_handle_ssh_with_config_file_verbose()
{
  local output
  local expected_result

  touch 'ssh_config'

  remote_parameters['REMOTE_FILE']="${PWD}/ssh_config"
  remote_parameters['REMOTE_FILE_HOST']='target'
  options_values['VERBOSE']=''

  output=$(handle_ssh)
  expected_result="ssh -F ${PWD}/ssh_config target"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_handle_ssh_with_port_user_remote()
{
  local output
  local expected_result

  touch 'ssh_config'

  remote_parameters['REMOTE_FILE']=''
  remote_parameters['REMOTE_FILE_HOST']=''
  remote_parameters['REMOTE_USER']='tadeu'
  remote_parameters['REMOTE_IP']='192.168.3.1'
  remote_parameters['REMOTE_PORT']='3244'

  output=$(handle_ssh)
  expected_result="ssh -p 3244 tadeu@192.168.3.1"
  assertEquals "($LINENO)" "$expected_result" "$output"

  output=$(handle_ssh)
  expected_result="ssh -p 3244 tadeu@192.168.3.1"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_run_command_in_the_remote()
{
  local output
  local expected_result

  touch 'ssh_config'
  remote_parameters['REMOTE_FILE']="${PWD}/ssh_config"
  remote_parameters['REMOTE_FILE_HOST']='target'
  options_values['CMD']='do something'

  output=$(run_command_in_the_remote 'TEST_MODE')
  expected_result="ssh -F ${PWD}/ssh_config target do something"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_run_script_in_the_remote()
{
  local output
  local expected_result

  touch 'ssh_config'
  touch 'some_script'

  remote_parameters['REMOTE_FILE']="${PWD}/ssh_config"
  remote_parameters['REMOTE_FILE_HOST']='target'
  options_values['SCRIPT']="${PWD}/some_script"

  output=$(run_script_in_the_remote 'TEST_MODE')
  expected_result="ssh -F ${PWD}/ssh_config target \"bash -s\" -- < ${options_values['SCRIPT']}"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_ssh_remote()
{
  local output
  local expected_result

  touch 'ssh_config'

  remote_parameters['REMOTE_FILE']="${PWD}/ssh_config"
  remote_parameters['REMOTE_FILE_HOST']='target'

  output=$(ssh_remote 'TEST_MODE')
  expected_result="ssh -F ${PWD}/ssh_config target"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_send_to_path_with_port_user_remote()
{
  local output
  local expected_cmd

  local -a inputs=(
    'y' # overwrite it
    'y' # overwrite it
  )

  touch 'some_file'
  mkdir 'some_folder'

  remote_parameters['REMOTE_FILE']=''
  remote_parameters['REMOTE_FILE_HOST']=''
  remote_parameters['REMOTE_USER']='mr_white'
  remote_parameters['REMOTE_IP']='192.168.3.1'
  remote_parameters['REMOTE_PORT']='3244'
  options_values['SEND']="${PWD}/some_file"
  options_values['TO']="$PWD"

  output="$(printf '%s\n' "${inputs[@]}" | ssh_transfer_file 'TEST_MODE' 'send')"

  declare -a expected_cmd=(
    "ssh -p 3244 mr_white@192.168.3.1 '[[ -f ${PWD}/some_file ]]'"
    'The '\''some_file'\'' file already exists on the remote machine.'
    "rsync -avzq ${PWD}/some_file -e 'ssh -p 3244' mr_white@192.168.3.1:${PWD}"
    'File(s) uploaded successfully.'
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  options_values['SEND']="${PWD}/some_folder"
  options_values['TO']="$PWD"

  output="$(printf '%s\n' "${inputs[@]}" | ssh_transfer_file 'TEST_MODE' 'send')"

  declare -a expected_cmd=(
    "ssh -p 3244 mr_white@192.168.3.1 '[[ -f ${PWD}/some_folder ]]'"
    'The '\''some_folder'\'' file already exists on the remote machine.'
    "rsync -avzq ${PWD}/some_folder -e 'ssh -p 3244' mr_white@192.168.3.1:${PWD}"
    'File(s) uploaded successfully.'
  )
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_get_from_path_with_port_user_remote()
{
  local output
  local expected_cmd
  local -a inputs=(
    'y' # overwrite it
    'y' # overwrite it
  )

  touch 'file.data'
  mkdir 'some_dir'
  mkdir 'other_dir'

  remote_parameters['REMOTE_FILE']=''
  remote_parameters['REMOTE_FILE_HOST']=''
  remote_parameters['REMOTE_USER']='pinkman'
  remote_parameters['REMOTE_IP']='192.168.3.1'
  remote_parameters['REMOTE_PORT']='3244'
  options_values['GET']="${PWD}/file.data"
  options_values['TO']="${PWD}/some_dir"

  output="$(printf '%s\n' "${inputs[@]}" | ssh_transfer_file 'TEST_MODE' 'get')"

  declare -a expected_cmd=(
    "ssh -p 3244 pinkman@192.168.3.1 [[ ! -e '${PWD}/file.data' ]]"
    "The file or directory '${PWD}/file.data' does not exist on the remote machine."
    "rsync -e 'ssh -p 3244' -avzq pinkman@192.168.3.1:${PWD}/file.data ${PWD}/some_dir"
    'The file(s) have been successfully received.'
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  options_values['GET']="${PWD}/other_dir"
  options_values['TO']=''

  output="$(printf '%s\n' "${inputs[@]}" | ssh_transfer_file 'TEST_MODE' 'get')"

  declare -a expected_cmd=(
    "ssh -p 3244 pinkman@192.168.3.1 [[ ! -e '${PWD}/other_dir' ]]"
    "The file or directory '${PWD}/other_dir' does not exist on the remote machine."
    "rsync -e 'ssh -p 3244' -avzq pinkman@192.168.3.1:${PWD}/other_dir ."
    'The file(s) have been successfully received.'
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

invoke_shunit
