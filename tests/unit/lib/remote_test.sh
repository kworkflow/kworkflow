#!/usr/bin/env bash

include './src/lib/remote.sh'
include './src/lib/kwlib.sh'
include './src/lib/kw_config_loader.sh'
include './tests/unit/utils.sh'

function which_distro_mock() {
  printf '%s\n' 'debian'
}

function setupMockFunctions() {
  shopt -s expand_aliases
  alias which_distro='which_distro_mock'
}

function tearDownMockFunctions() {
  unalias which_distro
}

function oneTimeSetUp() {
  local -r current_path="$PWD"
  local -r kernel_install_path='kernel_install'

  FAKE_KW="$SHUNIT_TMPDIR/fake_kw"
  TEST_PATH="$SHUNIT_TMPDIR/test_path"
  RSYNC_PREFIX='rsync --info=progress2 -e'
  RSYNC_FLAGS="-LrlptD --rsync-path='sudo rsync'"

  mkdir -p "$FAKE_KW"
  mkdir -p "$TEST_PATH/.kw"

  cp -f 'tests/unit/samples/kworkflow.config' "$TEST_PATH/.kw/"
  cp -f 'tests/unit/samples/dmesg' "$TEST_PATH"
  cp -f "${KW_REMOTE_SAMPLES_DIR}/remote.config" "${TEST_PATH}/.kw/"
  cp -f "${KW_REMOTE_SAMPLES_DIR}/remote_4.config" "${TEST_PATH}/.kw/"

  export KW_CACHE_DIR="$FAKE_KW"
  export KW_PLUGINS_DIR="$FAKE_KW"
  export DEPLOY_SCRIPT="$FAKE_KW/$kernel_install_path/deploy.sh"
  export KW_ETC_DIR="$TEST_PATH"
  export modules_path="$FAKE_KW/$kernel_install_path/lib/modules"
  export INVALID_ARG='Invalid arguments'
  export NO_SUCH_FILE='No such file'
  export SSH_OK='ssh -p 3333 127.0.0.1'
  export HOME='/home/SOMETHING'
  rm -rf "$FAKE_KW"

  mk_fake_remote "$FAKE_KW" "$modules_path"
}

function oneTimeTearDown() {
  unset KW_CACHE_DIR
  rm -rf "$SHUNIT_TMPDIR"
}

function setUp() {
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

function tearDown() {
  remote_parameters=()
  configurations=()
}

function test_populate_remote_info() {
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

function test_is_ssh_connection_configured() {
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

function test_is_ssh_connection_configured_with_remote_config_file() {
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

function test_is_ssh_connection_configured_no_remote_config_file() {
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

function test_ssh_connection_failure_message() {
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

function test_ssh_connection_failure_message_with_bad_formatted_remote_config() {
  local displayed_ip
  local displayed_user
  local displayed_port
  local output

  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_USER']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_FILE']="${TEST_PATH}/.kw/remote_4.config"
  remote_parameters['REMOTE_FILE_HOST']='origin'

  output=$(ssh_connection_failure_message)
  displayed_ip=$(printf '%s' "$output" | grep 'IP' | sed 's/ IP: //')
  displayed_user=$(printf '%s' "$output" | grep 'User' | sed 's/ User: //')
  displayed_port=$(printf '%s' "$output" | grep 'Port' | sed 's/ Port: //')

  assert_equals_helper 'Wrong IP displayed' "$LINENO" 'deb-tm' "$displayed_ip"
  assert_equals_helper 'Wrong User displayed' "$LINENO" 'root' "$displayed_user"
  assert_equals_helper 'Wrong Port displayed' "$LINENO" 123 "$displayed_port"
}

function test_ssh_connection_failure_message_with_invalid_host_in_remote_config() {
  local displayed_ip
  local displayed_user
  local displayed_port
  local output

  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_USER']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_FILE']="${TEST_PATH}/.kw/remote_4.config"
  remote_parameters['REMOTE_FILE_HOST']='fedora-test'

  output=$(ssh_connection_failure_message)
  displayed_ip=$(printf '%s' "$output" | grep 'IP' | sed 's/ IP: //')
  displayed_user=$(printf '%s' "$output" | grep 'User' | sed 's/ User: //')
  displayed_port=$(printf '%s' "$output" | grep 'Port' | sed 's/ Port: //')

  assert_equals_helper 'Wrong IP displayed' "$LINENO" 'fedora-tm' "$displayed_ip"
  assert_equals_helper 'Wrong User displayed' "$LINENO" '' "$displayed_user"
  assert_equals_helper 'Wrong Port displayed' "$LINENO" '' "$displayed_port"
}

function test_cmd_remote() {
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
  output=$(cmd_remotely "$flag" "$command")
  assertEquals "($LINENO): Command did not match" "$expected_command" "$output"

  configurations=()
  parse_configuration "$SAMPLES_DIR/kworkflow_template.config"

  # Remote
  remote_parameters['REMOTE_IP']='localhost'
  remote_parameters['REMOTE_PORT']='22'
  remote_parameters['REMOTE_USER']='root'

  expected_command="ssh -p $port $user@$remote sudo \"$command\""
  output=$(cmd_remotely "$flag" "$command" "$remote" "$port" "$user")
  assertEquals "($LINENO):" "$expected_command" "$output"

  expected_command="ssh -p $port $user@localhost sudo \"$command\""
  output=$(cmd_remotely "$flag" "$command" '' "$port" "$user")
  assertEquals "($LINENO):" "$expected_command" "$output"

  expected_command="ssh -p 22 $user@localhost sudo \"$command\""
  output=$(cmd_remotely "$flag" "$command" '' '' "$user")
  assertEquals "($LINENO):" "$expected_command" "$output"

  expected_command="ssh -p 22 root@localhost sudo \"$command\""
  output=$(cmd_remotely "$flag" "$command")
  assertEquals "($LINENO):" "$expected_command" "$output"

  expected_command="No command specified"
  output=$(cmd_remotely "$flag" '')
  assertEquals "($LINENO):" "$expected_command" "$output"
}

function test_cp2remote() {
  local src='/any/path'
  local dst='/any/path/2'
  local remote='172.16.224.1'
  local port='2222'
  local user='kw'
  local flag='TEST_MODE'
  local rsync_params='--include="*/" --exclude="*"'
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

function test_remote2host() {
  local flag='TEST_MODE'
  local src='/some/path'
  local dst='/another/path'
  local remote_host='origin'
  local port='2223'
  local user='root'
  local remote='192.168.122.116'
  local output
  local expected_cmd_str

  # Use remote configuration file
  remote_parameters['REMOTE_FILE']="${TEST_PATH}/.kw/remote.config"
  remote_parameters['REMOTE_FILE_HOST']="$remote_host"
  expected_cmd_str="$RSYNC_PREFIX 'ssh -F ${TEST_PATH}/.kw/remote.config' $remote_host:$src $dst $RSYNC_FLAGS"
  output=$(remote2host "$flag" "$src" "$dst" '' '' '' '' '')
  assert_equals_helper 'Remote configuration file' "$LINENO" "$expected_cmd_str" "$output"

  remote_parameters['REMOTE_IP']='192.168.122.197'
  remote_parameters['REMOTE_PORT']='2225'
  remote_parameters['REMOTE_USER']='juca'

  # No use of remote_parameters by remote2host
  expected_cmd_str="$RSYNC_PREFIX 'ssh -p $port' $user@$remote:$src $dst $RSYNC_FLAGS"
  output=$(remote2host "$flag" "$src" "$dst" "$remote" "$port" "$user")
  assert_equals_helper 'Pass ip, port and user to remote2host' "$LINENO" "$expected_cmd_str" "$output"

  # Default remote
  remote='192.168.122.197'
  expected_cmd_str="$RSYNC_PREFIX 'ssh -p $port' $user@$remote:$src $dst $RSYNC_FLAGS"
  output=$(remote2host "$flag" "$src" "$dst" '' "$port" "$user")
  assert_equals_helper 'Default remote' "$LINENO" "$expected_cmd_str" "$output"

  # Default port
  port='2225'
  expected_cmd_str="$RSYNC_PREFIX 'ssh -p $port' $user@$remote:$src $dst $RSYNC_FLAGS"
  output=$(remote2host "$flag" "$src" "$dst" "$remote" '' "$user")
  assert_equals_helper 'Default port' "$LINENO" "$expected_cmd_str" "$output"

  # Default user
  user='juca'
  expected_cmd_str="$RSYNC_PREFIX 'ssh -p $port' $user@$remote:$src $dst $RSYNC_FLAGS"
  output=$(remote2host "$flag" "$src" "$dst" "$remote" "$port")
  assert_equals_helper 'Default user' "$LINENO" "$expected_cmd_str" "$output"
}

function test_extract_remote_info_from_config_file() {
  remote_parameters['REMOTE_FILE']="${TEST_PATH}/.kw/remote.config"
  remote_parameters['REMOTE_FILE_HOST']='steamos'

  extract_remote_info_from_config_file
  assert_equals_helper 'Remote did not match' "$LINENO" 'steamdeck' "${remote_parameters['REMOTE_IP']}"
  assert_equals_helper 'Port did not match' "$LINENO" 8888 "${remote_parameters['REMOTE_PORT']}"
  assert_equals_helper 'User did not match' "$LINENO" 'jozzi' "${remote_parameters['REMOTE_USER']}"
}

function test_remove_key_from_kwown_hosts_by_user_request() {
  local expected_cmd="ssh-keygen -q -f '${HOME}/.ssh/known_hosts' -R '[steamdeck]:8888'"

  remote_parameters['REMOTE_FILE']="${TEST_PATH}/.kw/remote.config"
  remote_parameters['REMOTE_FILE_HOST']='steamos'

  output=$(remove_key_from_kwown_hosts 'TEST_MODE' 'something' <<< 'Y' | tail -1)
  assert_equals_helper 'Remove identification command is wrong' "$LINENO" "$expected_cmd" "$output"
}

function test_remove_key_from_kwown_hosts_by_user_request_cancel_operation() {
  local output

  remote_parameters['REMOTE_FILE']="${TEST_PATH}/.kw/remote.config"
  remote_parameters['REMOTE_FILE_HOST']='steamos'

  output=$(remove_key_from_kwown_hosts 'TEST_MODE' 'something' <<< 'N')
  assert_equals_helper 'User canceled the operation' "$LINENO" 125 "$?"
}

function test_ssh_error_handling() {
  ssh_error_handling 'This is not a valid error'
  assert_equals_helper 'This is not a valid error' "$LINENO" 0 "$?"

  ssh_error_handling 'WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED'
  assert_equals_helper 'Remote host change' "$LINENO" 111 "$?"
}

function test_which_distro() {
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
