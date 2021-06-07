#!/bin/bash

include './src/remote.sh'
include './src/kwlib.sh'
include './src/kw_config_loader.sh'
include './tests/utils'

function suite()
{
  suite_addTest "get_remote_info_Test"
  suite_addTest "cmd_remote_Test"
  suite_addTest "cp_host2remote_Test"
  suite_addTest "which_distro_Test"
  suite_addTest "preapre_host_deploy_dir_Test"
  suite_addTest "prepare_remote_dir_Test"
  suite_addTest "generate_tarball_Test"
}

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

FAKE_KW="tests/.tmp"

function oneTimeSetUp()
{
  local -r modules_name="test"
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
  rm -rf "$FAKE_KW"
}

function get_remote_info_Test()
{
  local ID

  # Force an unspected error
  configurations=()

  ID=0
  output=$(get_remote_info)
  ret="$?"
  assertEquals "($ID) We did not load kworkflow.config, we expect an error" "22" "$ret"
  setUp

  ID=1
  output=$(get_remote_info "localhost:6789")
  ret="$?"
  assertEquals "($ID) Expected 0" "0" "$ret"
  assertEquals "($ID) Expected localhost:6789" "localhost:6789" "$output"

  ID=2
  output=$(get_remote_info "localhost")
  ret="$?"
  assertEquals "($ID) Expected 0" "0" "$ret"
  assertEquals "($ID) Expected localhost:22" "localhost:22" "$output"

  parse_configuration "$KW_CONFIG_SAMPLE"

  ID=3
  output=$(get_remote_info)
  ret="$?"
  assertEquals "($ID) Expected 0" "0" "$ret"
  assertEquals "($ID) Expected 127.0.0.1:3333" "127.0.0.1:3333" "$output"
}

function cmd_remote_Test()
{
  local command="ls -lah"
  local remote="178.31.38.12"
  local port="2222"
  local user="kw"
  local flag="TEST_MODE"
  local ID

  ID=1
  expected_command="ssh -p $port $user@$remote \"$command\""
  output=$(cmd_remotely "$command" "$flag" "$remote" "$port" "$user")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=2
  expected_command="ssh -p $port $user@localhost \"$command\""
  output=$(cmd_remotely "$command" "$flag" "" "$port" "$user")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=3
  expected_command="ssh -p 22 $user@localhost \"$command\""
  output=$(cmd_remotely "$command" "$flag" "" "" "$user")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=4
  expected_command="ssh -p 22 root@localhost \"$command\""
  output=$(cmd_remotely "$command" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=5
  expected_command="No command specified"
  output=$(cmd_remotely "" "$flag")
  assertEquals "cmd_remotely should not work ($ID)" "$expected_command" "$output"
}

function cp_host2remote_Test()
{
  local src="/any/path"
  local dst="/any/path/2"
  local remote="172.16.224.1"
  local port="2222"
  local user="kw"
  local flag="TEST_MODE"
  local ID

  ID=1
  expected_command="rsync -e 'ssh -p $port' -La $src $user@$remote:$dst"
  output=$(cp_host2remote "$src" "$dst" "$remote" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=2
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  expected_command="rsync -e 'ssh -p $port' -La $src $user@$remote:$dst"
  output=$(cp_host2remote "" "$dst" "$remote" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=3
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p $port' -La $src $user@$remote:$dst"
  output=$(cp_host2remote "" "" "$remote" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=4
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p $port' -La $src $user@localhost:$dst"
  output=$(cp_host2remote "" "" "" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=5
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p 22' -La $src $user@localhost:$dst"
  output=$(cp_host2remote "" "" "" "" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=6
  src="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p 22' -La $src root@localhost:$dst"
  output=$(cp_host2remote "" "" "" "" "" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"
}

function which_distro_Test()
{
  local cmd="cat /etc/os-release | grep -w ID | cut -d = -f 2"
  local remote="172.16.224.1"
  local user="root"
  local port="2222"
  local flag="TEST_MODE"
  local ID

  ID=1
  output=$(which_distro "$remote" "$port" "$user" "$flag")
  expected_command="ssh -p $port $user@$remote \"$cmd\""
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=2
  output=$(which_distro "$remote" "$port" "" "$flag")
  expected_command="ssh -p $port root@$remote \"$cmd\""
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=3
  output=$(which_distro "$remote" "" "" "$flag")
  expected_command="ssh -p 22 root@$remote \"$cmd\""
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=2
  output=$(which_distro "" "" "" "$flag")
  expected_command="ssh -p 22 root@localhost \"$cmd\""
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"
}

function preapre_host_deploy_dir_Test()
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

function prepare_remote_dir_Test()
{
  local cmd="cat /etc/os-release | grep -w ID | cut -d = -f 2"
  local remote="172.16.224.1"
  local user="root"
  local port="2222"
  local flag="TEST_MODE"
  local count=0
  local ID

  declare -a expected_cmd_sequence=(
    "ssh -p 2222 root@172.16.224.1 \"mkdir -p /root/kw_deploy\""
    "rsync -e 'ssh -p 2222' -La tests/.tmp/kernel_install/debian.sh root@172.16.224.1:/root/kw_deploy/distro_deploy.sh"
    "rsync -e 'ssh -p 2222' -La tests/.tmp/kernel_install/deploy.sh root@172.16.224.1:/root/kw_deploy/"
    "rsync -e 'ssh -p 2222' -La tests/.tmp/kernel_install/utils.sh root@172.16.224.1:/root/kw_deploy/"
  )

  setupMockFunctions
  output=$(prepare_remote_dir "$remote" "$port" "$user" "$flag")
  while read cmd; do
    if [[ ${expected_cmd_sequence[$count]} != ${cmd} ]]; then
      fail "Expected command \"${expected_cmd_sequence[$count]}\" to be \"${cmd}\")"
    fi
    ((count++))
  done <<< "$output"

  tearDownMockFunctions
}

function generate_tarball_Test()
{
  local kernel_release="test"
  local tarball_name="$kernel_release.tar"
  local count=0
  local ID

  declare -a expected_files=(
    "test/"
    "test/file1"
    "test/file2"
  )

  expected_cmd="tar -C $FAKE_KW/kernel_install/lib/modules -cf $FAKE_KW/$LOCAL_TO_DEPLOY_DIR/$tarball_name $kernel_release"
  ID=1
  output=$(generate_tarball "$kernel_release" "$modules_path")

  assertTrue "$ID - We expected a tarball" '[[ -f $KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/$tarball_name ]]'

  ID=2
  output=$(tar -taf "$FAKE_KW/$LOCAL_TO_DEPLOY_DIR/$tarball_name" | sort -d)
  while read f; do
    if [[ ${expected_files[$count]} != ${f} ]]; then
      fail "$ID - Expected file \"${expected_files[$count]}\" to be \"${f}\""
    fi
    ((count++))
  done <<< "$output"

  ID=3
  output=$(generate_tarball "$kernel_release" "$modules_path" "TEST_MODE")
  assertEquals "Command did not match ($ID)" "$expected_cmd" "$output"
}

invoke_shunit
