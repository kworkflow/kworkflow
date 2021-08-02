#!/bin/bash

include './src/remote.sh'
include './src/kwlib.sh'
include './src/kw_config_loader.sh'
include './tests/utils.sh'

function which_distro_mock()
{
  echo "debian"
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
  FAKE_KW="$SHUNIT_TMPDIR/fake_kw"
  TEST_PATH="$SHUNIT_TMPDIR/test_path"

  mkdir -p "$FAKE_KW"
  mkdir -p "$TEST_PATH"

  local -r current_path="$PWD"

  cp -f tests/samples/kworkflow.config "$TEST_PATH"
  cp -f tests/samples/dmesg "$TEST_PATH"

  cd "$TEST_PATH" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  load_configuration
  cd "$current_path" || {
    fail "($LINENO) It was not possible return to original directory"
    return
  }

  local -r kernel_install_path="kernel_install"

  export KW_CACHE_DIR="$FAKE_KW"
  export KW_PLUGINS_DIR="$FAKE_KW"
  export DEPLOY_SCRIPT="$FAKE_KW/$kernel_install_path/deploy.sh"
  export DEPLOY_SCRIPT_SUPPORT="$FAKE_KW/$kernel_install_path/utils.sh"
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

  load_configuration
  remote_parameters['REMOTE_IP']=${configurations[ssh_ip]}
  remote_parameters['REMOTE_PORT']=${configurations[ssh_port]}
  remote_parameters['REMOTE_USER']=${configurations[ssh_user]}
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
  parse_configuration "$KW_CONFIG_SAMPLE"

  populate_remote_info ''
  assertEquals "($LINENO) Expected 127.0.0.1" '127.0.0.1' "${remote_parameters['REMOTE_IP']}"
  assertEquals "($LINENO) Expected 3333" 3333 "${remote_parameters['REMOTE_PORT']}"
  assertEquals "($LINENO) Expected juca" 'juca' "${remote_parameters['REMOTE_USER']}"

  # Let's check a failure case
  remote_parameters=()
  configurations=()
  populate_remote_info > /dev/null
  ret="$?"
  assertEquals "($LINENO) We did not load kworkflow.config, we expect an error" 22 "$ret"
}

function test_cmd_remote()
{
  local command='ls -lah'
  local remote='178.31.38.12'
  local port='2222'
  local user='kw'
  local flag='TEST_MODE'

  parse_configuration "$SAMPLES_DIR/kworkflow_template.config"

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

function test_cp_host2remote()
{
  local src='/any/path'
  local dst='/any/path/2'
  local remote='172.16.224.1'
  local port='2222'
  local user='kw'
  local flag='TEST_MODE'
  declare -a expected_cmd=()

  # Load default configureation, because we want to test default values
  output=$(cp_host2remote "$src" "$dst" "$remote" "$port" "$user" "$flag")
  expected_command=(
    "rsync -e 'ssh -p $port' -La $src $user@$remote:$dst --rsync-path='sudo rsync'"
    "ssh -p $port ${user}@${remote} sudo \"chown -R root:root $dst\""
  )

  compare_command_sequence 'expected_command' "$output" "$LINENO"

  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  expected_command=(
    "rsync -e 'ssh -p $port' -La $src $user@$remote:$dst --rsync-path='sudo rsync'"
    "ssh -p $port ${user}@${remote} sudo \"chown -R root:root $dst\""
  )

  output=$(cp_host2remote '' "$dst" "$remote" "$port" "$user" "$flag")
  compare_command_sequence 'expected_command' "$output" "$LINENO"

  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command=(
    "rsync -e 'ssh -p $port' -La $src $user@$remote:$dst --rsync-path='sudo rsync'"
    "ssh -p $port ${user}@${remote} sudo \"chown -R root:root $dst\""
  )

  output=$(cp_host2remote '' '' "$remote" "$port" "$user" "$flag")
  compare_command_sequence 'expected_command' "$output" "$LINENO"

  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  remote='127.0.0.1'
  expected_command=(
    "rsync -e 'ssh -p $port' -La $src $user@$remote:$dst --rsync-path='sudo rsync'"
    "ssh -p $port ${user}@${remote} sudo \"chown -R root:root $dst\""
  )

  output=$(cp_host2remote '' '' '' "$port" "$user" "$flag")
  compare_command_sequence 'expected_command' "$output" "$LINENO"

  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  remote='127.0.0.1'
  port='3333'
  expected_command=(
    "rsync -e 'ssh -p $port' -La $src $user@$remote:$dst --rsync-path='sudo rsync'"
    "ssh -p $port ${user}@$remote sudo \"chown -R root:root $dst\""
  )

  output=$(cp_host2remote '' '' '' '' "$user" "$flag")
  compare_command_sequence 'expected_command' "$output" "$LINENO"

  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  remote='127.0.0.1'
  port='3333'
  user='juca'
  expected_command=(
    "rsync -e 'ssh -p $port' -La $src $user@$remote:$dst --rsync-path='sudo rsync'"
    "ssh -p $port ${user}@$remote sudo \"chown -R root:root $dst\""
  )

  output=$(cp_host2remote '' '' '' '' '' "$flag")
  compare_command_sequence 'expected_command' "$output" "$LINENO"
}

function test_which_distro()
{
  local cmd='cat /etc/os-release | grep -w ID | cut -d = -f 2'
  local remote='172.16.224.1'
  local user='xpto'
  local port='2222'
  local flag='TEST_MODE'
  local expected_str

  output=$(which_distro "$remote" "$port" "$user" "$flag")
  expected_str="ssh -p $port $user@$remote sudo \"$cmd\""
  assertEquals "($LINENO):" "$expected_str" "$output"

  user='juca'
  output=$(which_distro "$remote" "$port" '' "$flag")
  expected_str="ssh -p $port $user@$remote sudo \"$cmd\""
  assertEquals "($LINENO)" "$expected_str" "$output"

  user='juca'
  port=3333
  output=$(which_distro "$remote" '' '' "$flag")
  expected_str="ssh -p $port $user@$remote sudo \"$cmd\""
  assertEquals "($LINENO)" "$expected_str" "$output"

  user='juca'
  port=3333
  remote='127.0.0.1'
  output=$(which_distro '' '' '' "$flag")
  expected_str="ssh -p $port $user@$remote sudo \"$cmd\""
  assertEquals "Command did not match ($ID)" "$expected_str" "$output"
}

function test_preapre_host_deploy_dir()
{
  local output
  local ret

  prepare_host_deploy_dir

  assertTrue "($LINENO): Check if kw dir was created" '[[ -d $KW_CACHE_DIR ]]'
  assertTrue "($LINENO): Check if kw dir was created" '[[ -d $KW_CACHE_DIR/$LOCAL_REMOTE_DIR ]]'
  assertTrue "($LINENO): Check if kw dir was created" '[[ -d $KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR ]]'

  oneTimeTearDown

  output=$(prepare_host_deploy_dir)
  ret="$?"
  assertEquals "($LINENO): Expected an error" 22 "$ret"

  oneTimeSetUp
}

function test_prepare_remote_dir()
{
  local cmd='cat /etc/os-release | grep -w ID | cut -d = -f 2'
  local remote='172.16.224.1'
  local user='root'
  local port='2222'
  local flag='TEST_MODE'
  local count=0

  declare -a expected_cmd_sequence=(
    "ssh -p 2222 root@172.16.224.1 sudo \"mkdir -p /root/kw_deploy\""
    "rsync -e 'ssh -p 2222' -La $FAKE_KW/kernel_install/debian.sh root@172.16.224.1:/root/kw_deploy/distro_deploy.sh --rsync-path='sudo rsync'"
    "ssh -p $port ${user}@${remote} sudo \"chown -R root:root /root/kw_deploy/distro_deploy.sh\""
    "rsync -e 'ssh -p 2222' -La $FAKE_KW/kernel_install/deploy.sh root@172.16.224.1:/root/kw_deploy/ --rsync-path='sudo rsync'"
    "ssh -p $port ${user}@${remote} sudo \"chown -R root:root /root/kw_deploy/\""
    "rsync -e 'ssh -p 2222' -La $FAKE_KW/kernel_install/utils.sh root@172.16.224.1:/root/kw_deploy/ --rsync-path='sudo rsync'"
    "ssh -p $port ${user}@${remote} sudo \"chown -R root:root /root/kw_deploy/\""
  )

  setupMockFunctions

  output=$(prepare_remote_dir "$remote" "$port" "$user" "$flag")
  compare_command_sequence 'expected_cmd_sequence' "$output" "$LINENO"

  tearDownMockFunctions
}

invoke_shunit
