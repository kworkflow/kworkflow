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
  mkdir -p "$TEST_PATH/.kw"

  local -r current_path="$PWD"

  cp -f tests/samples/kworkflow.config "$TEST_PATH/.kw/"
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
  export KW_PLUGINS_DIR=$FAKE_KW
  export DEPLOY_SCRIPT=$FAKE_KW/$kernel_install_path/deploy.sh
  export DEPLOY_SCRIPT_SUPPORT="$FAKE_KW/$kernel_install_path/utils.sh"
  export modules_path="$FAKE_KW/$kernel_install_path/lib/modules"
  rm -rf "$FAKE_KW"

  mk_fake_remote "$FAKE_KW" "$modules_path"
}

function oneTimeTearDown()
{
  unset KW_CACHE_DIR
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
  local command="ls -lah"
  local remote="178.31.38.12"
  local port="2222"
  local user="kw"
  local flag="TEST_MODE"
  local ID
  parse_configuration "$SAMPLES_DIR/kworkflow_template.config"

  ID=1
  expected_command="ssh -p $port $user@$remote sudo \"$command\""
  output=$(cmd_remotely "$command" "$flag" "$remote" "$port" "$user")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=2
  expected_command="ssh -p $port $user@localhost sudo \"$command\""
  output=$(cmd_remotely "$command" "$flag" "" "$port" "$user")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=3
  expected_command="ssh -p 22 $user@localhost sudo \"$command\""
  output=$(cmd_remotely "$command" "$flag" "" "" "$user")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=4
  expected_command="ssh -p 22 root@localhost sudo \"$command\""
  output=$(cmd_remotely "$command" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=5
  expected_command="No command specified"
  output=$(cmd_remotely "" "$flag")
  assertEquals "cmd_remotely should not work ($ID)" "$expected_command" "$output"
}

function test_cp_host2remote()
{
  local src="/any/path"
  local dst="/any/path/2"
  local remote="172.16.224.1"
  local port="2222"
  local user="kw"
  local flag="TEST_MODE"
  local ID

  ID=1
  expected_command="rsync -e 'ssh -p $port' -La $src $user@$remote:$dst --rsync-path='sudo rsync'
ssh -p $port ${user}@${remote} sudo \"chown -R root:root $dst\""
  output=$(cp_host2remote "$src" "$dst" "$remote" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=2
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  expected_command="rsync -e 'ssh -p $port' -La $src $user@$remote:$dst --rsync-path='sudo rsync'
ssh -p $port ${user}@${remote} sudo \"chown -R root:root $dst\""
  output=$(cp_host2remote "" "$dst" "$remote" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=3
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p $port' -La $src $user@$remote:$dst --rsync-path='sudo rsync'
ssh -p $port ${user}@${remote} sudo \"chown -R root:root $dst\""
  output=$(cp_host2remote "" "" "$remote" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=4
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p $port' -La $src $user@localhost:$dst --rsync-path='sudo rsync'
ssh -p $port ${user}@localhost sudo \"chown -R root:root $dst\""
  output=$(cp_host2remote "" "" "" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=5
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p 22' -La $src $user@localhost:$dst --rsync-path='sudo rsync'
ssh -p 22 ${user}@localhost sudo \"chown -R root:root $dst\""
  output=$(cp_host2remote "" "" "" "" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=6
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p 22' -La $src root@localhost:$dst --rsync-path='sudo rsync'
ssh -p 22 root@localhost sudo \"chown -R root:root $dst\""
  output=$(cp_host2remote "" "" "" "" "" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"
}

function test_which_distro()
{
  local cmd="cat /etc/os-release | grep -w ID | cut -d = -f 2"
  local remote="172.16.224.1"
  local user="root"
  local port="2222"
  local flag="TEST_MODE"
  local ID

  ID=1
  output=$(which_distro "$remote" "$port" "$user" "$flag")
  expected_command="ssh -p $port $user@$remote sudo \"$cmd\""
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=2
  output=$(which_distro "$remote" "$port" "" "$flag")
  expected_command="ssh -p $port root@$remote sudo \"$cmd\""
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=3
  output=$(which_distro "$remote" "" "" "$flag")
  expected_command="ssh -p 22 root@$remote sudo \"$cmd\""
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=2
  output=$(which_distro "" "" "" "$flag")
  expected_command="ssh -p 22 root@localhost sudo \"$cmd\""
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"
}

function test_preapre_host_deploy_dir()
{
  local ID

  prepare_host_deploy_dir

  ID=1
  assertTrue "$ID - Check if kw dir was created" '[[ -d $KW_CACHE_DIR ]]'

  ID=2
  assertTrue "$ID - Check if kw dir was created" '[[ -d $KW_CACHE_DIR/$LOCAL_REMOTE_DIR ]]'

  ID=3
  assertTrue "$ID - Check if kw dir was created" '[[ -d $KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR ]]'

  ID=4
  oneTimeTearDown

  output=$(prepare_host_deploy_dir)
  ret=$?
  assertEquals "$ID - Expected an error" "22" "$ret"

  oneTimeSetUp
}

function test_prepare_remote_dir()
{
  local cmd="cat /etc/os-release | grep -w ID | cut -d = -f 2"
  local remote="172.16.224.1"
  local user="root"
  local port="2222"
  local flag="TEST_MODE"
  local count=0
  local ID

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
  while read -r cmd; do
    if [[ ${expected_cmd_sequence[$count]} != "${cmd}" ]]; then
      fail "Expected command \"${cmd}\" to be \"${expected_cmd_sequence[$count]}\""
    fi
    ((count++))
  done <<< "$output"

  tearDownMockFunctions
}

### SSH tests ###
#
# NOTE: We're not testing the ssh command here, just the kw ssh operation
#

INVALID_ARG="Invalid arguments"
NO_SUCH_FILE="No such file"

SSH_OK="ssh -p 3333 127.0.0.1"

function test_kw_ssh_check_fail_cases()
{
  local args="--lala"
  local ret

  ret=$(kw_ssh $args)
  assertTrue "We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-m"
  ret=$(kw_ssh $args)
  assertTrue "We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-d="
  ret=$(kw_ssh $args)
  assertTrue "We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-c"
  ret=$(kw_ssh $args)
  assertTrue "We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-s"
  ret=$(kw_ssh $args)
  assertTrue "We expected a substring \"$INVALID_ARG: $args\", but we got \"$ret\"" '[[ $ret =~ "$INVALID_ARG: $args" ]]'

  args="-s="
  ret=$(kw_ssh $args)
  assertTrue "We expected a substring \"$NO_SUCH_FILE\", but we got \"$ret\"" '[[ $ret =~ "$NO_SUCH_FILE" ]]'

  args="--script="
  ret=$(kw_ssh $args)
  assertTrue "We expected a substring \"$NO_SUCH_FILE\", but we got \"$ret\"" '[[ $ret =~ "$NO_SUCH_FILE" ]]'
}

function test_kw_ssh_basic()
{
  ret=$(kw_ssh 2>&1)

  assertTrue "We expected a substring \"$SSH_OK\", but we got \"$ret\"" '[[ $ret =~ "$SSH_OK" ]]'
}

function test_kw_ssh_command()
{
  ret=$(kw_ssh -c="pwd" 2>&1)
  msg="$SSH_OK pwd"
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'

  ret=$(kw_ssh --command="ls /etc/" 2>&1)
  msg="$SSH_OK ls /etc/"
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'
}

function test_kw_ssh_script()
{
  ret=$(kw_ssh -s="/not/a/valid/path/xpto" 2>&1)
  msg="$NO_SUCH_FILE: \"/not/a/valid/path/xpto\""
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'

  ret=$(kw_ssh -s="$TEST_PATH/dmesg" 2>&1)
  msg="$SSH_OK \"bash -s\" -- < $TEST_PATH/dmesg"
  assertTrue "We expected a substring \"$msg\", but we got \"$ret\"" '[[ $ret =~ "$msg" ]]'
}

invoke_shunit
