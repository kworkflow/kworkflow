#!/bin/bash

include './src/remote.sh'
include './src/kwlib.sh'
include './src/kw_config_loader.sh'
include './tests/utils.sh'

function which_distro_mock()
{
  printf '%s\n' 'debian'
}

function setupMockFunctions()
{
  shopt -s expand_aliases
  alias which_distro='which_distro_mock'
}

function tearDownMockFunctions()
{
  unalias which_distro
}

function oneTimeSetUp()
{
  local -r current_path="$PWD"
  local -r kernel_install_path='kernel_install'

  FAKE_KW="$SHUNIT_TMPDIR/fake_kw"
  TEST_PATH="$SHUNIT_TMPDIR/test_path"

  mkdir -p "$FAKE_KW"
  mkdir -p "$TEST_PATH/.kw"

  cp -f 'tests/samples/kworkflow.config' "$TEST_PATH/.kw/"
  cp -f 'tests/samples/dmesg' "$TEST_PATH"
  cp -f "${KW_REMOTE_SAMPLES_DIR}/remote.config" "${TEST_PATH}/.kw/"

  export KW_CACHE_DIR="$FAKE_KW"
  export KW_PLUGINS_DIR="$FAKE_KW"
  export DEPLOY_SCRIPT="$FAKE_KW/$kernel_install_path/deploy.sh"
  export KW_ETC_DIR="$TEST_PATH"
  export modules_path="$FAKE_KW/$kernel_install_path/lib/modules"
  export INVALID_ARG='Invalid arguments'
  export NO_SUCH_FILE='No such file'
  export SSH_OK='ssh -p 3333 127.0.0.1'
  rm -rf "$FAKE_KW"

  mk_fake_remote "$FAKE_KW" "$modules_path"
}

function oneTimeTearDown()
{
  unset KW_CACHE_DIR
  rm -rf "$SHUNIT_TMPDIR"
}

function setUp()
{
  local -r current_path="$PWD"

  cd "$TEST_PATH" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_USER']=''
  remote_parameters['REMOTE_FILE']=''
  remote_parameters['REMOTE_FILE_HOST']=''

  cd "$current_path" || {
    fail "($LINENO) It was not possible return to original directory"
    return
  }
}

function tearDown()
{
  remote_parameters=()
  configurations=()
}

function test_populate_remote_info()
{
  local ret
  local output
  local -r current_path="$PWD"

  cd "$TEST_PATH" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # Force an unspected error
  configurations=()

  populate_remote_info 'localhost'
  assertEquals "($LINENO) Expected localhost" 'localhost' "${remote_parameters['REMOTE_IP']}"
  assertEquals "($LINENO) Expected 22" 22 "${remote_parameters['REMOTE_PORT']}"
  assertEquals "($LINENO) Expected root" 'root' "${remote_parameters['REMOTE_USER']}"

  populate_remote_info 'localhost:6789'
  assertEquals "($LINENO) Expected localhost" 'localhost' "${remote_parameters['REMOTE_IP']}"
  assertEquals "($LINENO) Expected 6789" 6789 "${remote_parameters['REMOTE_PORT']}"
  assertEquals "($LINENO) Expected root" 'root' "${remote_parameters['REMOTE_USER']}"

  populate_remote_info 'localhost'
  assertEquals "($LINENO) Expected localhost" 'localhost' "${remote_parameters['REMOTE_IP']}"
  assertEquals "($LINENO) Expected 22" 22 "${remote_parameters['REMOTE_PORT']}"
  assertEquals "($LINENO) Expected root" 'root' "${remote_parameters['REMOTE_USER']}"

  populate_remote_info 'ada@localhost:3773'
  assertEquals "($LINENO) Expected localhost" 'localhost' "${remote_parameters['REMOTE_IP']}"
  assertEquals "($LINENO) Expected 3773" 3773 "${remote_parameters['REMOTE_PORT']}"
  assertEquals "($LINENO) Expected ada" 'ada' "${remote_parameters['REMOTE_USER']}"

  # Let's check with a config file information
  populate_remote_info ''
  assertEquals "($LINENO) Expected origin" 'origin' "${remote_parameters['REMOTE_FILE_HOST']}"
  assertEquals "($LINENO) Expected remote.config path" "${PWD}/.kw/remote.config" "${remote_parameters['REMOTE_FILE']}"

  cd "$current_path" || {
    fail "($LINENO) It was not possible return to original directory"
    return
  }
}

function test_is_ssh_connection_configured()
{
  local remote='test_remote'
  local user='test_user'
  local port='22'
  local flag='TEST_MODE'
  local current_path="$PWD"

  cd "$TEST_PATH" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  remote_parameters['REMOTE_IP']="$remote"
  remote_parameters['REMOTE_USER']="$user"
  remote_parameters['REMOTE_PORT']="$port"

  is_ssh_connection_configured "$flag" > /dev/null

  assertEquals "($LINENO):" 0 "$?"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move to the original path"
    return
  }
}

function test_is_ssh_connection_configured_with_remote_config_file()
{
  local flag='TEST_MODE'
  local current_path="$PWD"

  cd "$TEST_PATH" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_USER']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_FILE']="${TEST_PATH}/.kw/remote.config"
  remote_parameters['REMOTE_FILE_HOST']='origin'

  is_ssh_connection_configured "$flag" > /dev/null

  assertEquals "($LINENO):" 0 "$?"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move to the original path"
    return
  }
}

function test_is_ssh_connection_configured_no_remote_config_file()
{
  local flag='TEST_MODE'
  local current_path="$PWD"

  cd "$TEST_PATH" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_USER']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_FILE']=''
  remote_parameters['REMOTE_FILE_HOST']=''

  is_ssh_connection_configured "$flag"

  assertEquals "($LINENO):" 2 "$?"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move to the original path"
    return
  }
}

function test_ssh_connection_failure_message()
{
  local expected_remote='deb-tm'
  local expected_user='root'
  local expected_port='333'
  local returned_remote
  local returned_user
  local returned_port
  local ret
  local no_config_file_failure_message='Could not find remote config file.'$'\n'
  no_config_file_failure_message+='Suggestion: check if there is a remote.config or try using'$'\n'
  no_config_file_failure_message+='  kw ssh (-r | --remote) <user>@<ip>:<port>'

  cd "$TEST_PATH" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # Case 1: IP, user and port passed as command line arguments (kw ssh -r)
  remote_parameters['REMOTE_IP']='deb-tm'
  remote_parameters['REMOTE_USER']='root'
  remote_parameters['REMOTE_PORT']='333'

  ret=$(ssh_connection_failure_message)
  returned_remote=$(printf '%s' "$ret" | grep 'IP' | sed 's/ IP: //')
  returned_user=$(printf '%s' "$ret" | grep 'User' | sed 's/ User: //')
  returned_port=$(printf '%s' "$ret" | grep 'Port' | sed 's/ Port: //')

  assertEquals "($LINENO):" "$expected_remote" "$returned_remote"
  assertEquals "($LINENO):" "$expected_user" "$returned_user"
  assertEquals "($LINENO):" "$expected_port" "$returned_port"

  # Case 2: Using a remote config file
  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_USER']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_FILE']="${TEST_PATH}/.kw/remote.config"
  remote_parameters['REMOTE_FILE_HOST']='origin'

  ret=$(ssh_connection_failure_message)
  returned_remote=$(printf '%s' "$ret" | grep 'IP' | sed 's/ IP: //')
  returned_user=$(printf '%s' "$ret" | grep 'User' | sed 's/ User: //')
  returned_port=$(printf '%s' "$ret" | grep 'Port' | sed 's/ Port: //')

  assertEquals "($LINENO):" "$expected_remote" "$returned_remote"
  assertEquals "($LINENO):" "$expected_user" "$returned_user"
  assertEquals "($LINENO):" "$expected_port" "$returned_port"

  # Case 3: No remote config file found
  remote_parameters['REMOTE_FILE']=''
  remote_parameters['REMOTE_FILE_HOST']=''

  ret=$(ssh_connection_failure_message)
  assertEquals "($LINENO):" "$no_config_file_failure_message" "$ret"
}

function test_cmd_remote()
{
  local log_path="${SHUNIT_TMPDIR}/cmd_remote_test.log"
  local command='ls -lah'
  local remote='178.31.38.12'
  local port='2222'
  local user='kw'
  local flag='TEST_MODE'
  local output
  local expected_command
  local ret

  remote_parameters['REMOTE_FILE']="${SHUNIT_TMPDIR}/remote.config"
  remote_parameters['REMOTE_FILE_HOST']='origin'

  expected_command="ssh -F ${SHUNIT_TMPDIR}/remote.config origin sudo \"$command\""
  output=$(cmd_remotely "$command" "$flag")
  assertEquals "($LINENO): Command did not match" "$expected_command" "$output"

  configurations=()
  parse_configuration "$SAMPLES_DIR/kworkflow_template.config"

  # Remote
  remote_parameters['REMOTE_IP']='localhost'
  remote_parameters['REMOTE_PORT']='22'
  remote_parameters['REMOTE_USER']='root'

  expected_command="ssh -p $port $user@$remote sudo \"$command\""
  output=$(cmd_remotely "$command" "$flag" "$remote" "$port" "$user")
  assertEquals "($LINENO):" "$expected_command" "$output"

  expected_command="ssh -p $port $user@localhost sudo \"$command\""
  output=$(cmd_remotely "$command" "$flag" '' "$port" "$user")
  assertEquals "($LINENO):" "$expected_command" "$output"

  expected_command="ssh -p 22 $user@localhost sudo \"$command\""
  output=$(cmd_remotely "$command" "$flag" '' '' "$user")
  assertEquals "($LINENO):" "$expected_command" "$output"

  expected_command="ssh -p 22 root@localhost sudo \"$command\""
  output=$(cmd_remotely "$command" "$flag")
  assertEquals "($LINENO):" "$expected_command" "$output"

  expected_command="No command specified"
  output=$(cmd_remotely '' "$flag")
  assertEquals "($LINENO):" "$expected_command" "$output"
}

function test_cp2remote()
{
  local src='/any/path'
  local dst='/any/path/2'
  local remote='172.16.224.1'
  local port='2222'
  local user='kw'
  local flag='TEST_MODE'
  local rsync_params='--include="*/" --exclude="*"'
  local RSYNC_PREFIX='rsync --info=progress2 -e'
  local RSYNC_FLAGS="-LrlptD --rsync-path='sudo rsync'"
  local expected_cmd_str="$RSYNC_PREFIX 'ssh -p $port' $src $user@$remote:$dst $RSYNC_FLAGS $rsync_params"

  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='3333'
  remote_parameters['REMOTE_USER']='juca'

  # Load default configureation, because we want to test default values
  output=$(cp2remote "$flag" "$src" "$dst" "$rsync_params" "$remote" "$port" "$user")
  assert_equals_helper 'Standard Rsync' "$LINENO" "$expected_cmd_str" "$output"

  # Default src
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  expected_cmd_str="$RSYNC_PREFIX 'ssh -p $port' $src $user@$remote:$dst $RSYNC_FLAGS"
  output=$(cp2remote "$flag" '' "$dst" '' "$remote" "$port" "$user")
  assert_equals_helper 'Default src' "$LINENO" "$expected_cmd_str" "$output"

  # Default src and dst
  dst="$REMOTE_KW_DEPLOY"
  expected_cmd_str="$RSYNC_PREFIX 'ssh -p $port' $src $user@$remote:$dst $RSYNC_FLAGS"

  output=$(cp2remote "$flag" '' '' '' "$remote" "$port" "$user")
  assert_equals_helper 'Default src and dst' "$LINENO" "$expected_cmd_str" "$output"

  # Default src, dst, and remote
  remote='127.0.0.1'
  expected_cmd_str="$RSYNC_PREFIX 'ssh -p $port' $src $user@$remote:$dst $RSYNC_FLAGS"

  output=$(cp2remote "$flag" '' '' '' '' "$port" "$user")
  assert_equals_helper 'Default src, dst, and remote' "$LINENO" "$expected_cmd_str" "$output"

  # Default port
  port='3333'
  expected_cmd_str="$RSYNC_PREFIX 'ssh -p $port' $src $user@$remote:$dst $RSYNC_FLAGS"
  output=$(cp2remote "$flag" '' '' '' '' '' "$user")
  assert_equals_helper 'Default src, dst, remote, and port' "$LINENO" "$expected_cmd_str" "$output"

  # Default user
  user='juca'
  expected_cmd_str="$RSYNC_PREFIX 'ssh -p $port' $src $user@$remote:$dst $RSYNC_FLAGS"
  output=$(cp2remote "$flag" '' '' '' '' '' '')
  assert_equals_helper 'Default src, dst, remote, port, and user' "$LINENO" "$expected_cmd_str" "$output"
}

function test_which_distro()
{
  local cmd='cat /etc/os-release'
  local remote='172.16.224.1'
  local user='xpto'
  local port='2222'
  local flag='TEST_MODE'
  local expected_str

  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='3333'
  remote_parameters['REMOTE_USER']='juca'

  output=$(which_distro "$remote" "$port" "$user" "$flag")
  expected_str="ssh -p $port $user@$remote sudo \"$cmd\""
  assertEquals "($LINENO):" "$expected_str" "$output"

  user='juca'
  output=$(which_distro "$remote" "$port" '' "$flag")
  expected_str="ssh -p $port $user@$remote sudo \"$cmd\""
  assertEquals "($LINENO)" "$expected_str" "$output"

  port=3333
  output=$(which_distro "$remote" '' '' "$flag")
  expected_str="ssh -p $port $user@$remote sudo \"$cmd\""
  assertEquals "($LINENO)" "$expected_str" "$output"

  remote='127.0.0.1'
  output=$(which_distro '' '' '' "$flag")
  expected_str="ssh -p $port $user@$remote sudo \"$cmd\""
  assert_equals_helper 'Command did not match' "$LINENO" "$expected_str" "$output"
}

invoke_shunit
