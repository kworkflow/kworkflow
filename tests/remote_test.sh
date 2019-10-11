#!/bin/bash

. ./src/remote.sh --source-only
. ./src/kwlib.sh --source-only
. ./src/commons.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "cmd_remote_Test"
  suite_addTest "cp_host2remote_Test"
  suite_addTest "which_distro_Test"
}

FAKE_KW="tests/.tmp"

function oneTimeSetUp
{
  export kw_dir="$FAKE_KW"
  rm -rf "$FAKE_KW"

  mkdir -p "$FAKE_KW/$LOCAL_TO_DEPLOY_DIR"
}

function oneTimeTearDown
{
  unset kw_dir
  rm -rf "$FAKE_KW"
}

function cmd_remote_Test
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

function cp_host2remote_Test
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
  src="$kw_dir/$LOCAL_TO_DEPLOY_DIR/*"
  expected_command="rsync -e 'ssh -p $port' -La $src $user@$remote:$dst"
  output=$(cp_host2remote "" "$dst" "$remote" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=3
  src="$kw_dir/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p $port' -La $src $user@$remote:$dst"
  output=$(cp_host2remote "" "" "$remote" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=4
  src="$kw_dir/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p $port' -La $src $user@localhost:$dst"
  output=$(cp_host2remote "" "" "" "$port" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=5
  src="$kw_dir/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p 22' -La $src $user@localhost:$dst"
  output=$(cp_host2remote "" "" "" "" "$user" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"

  ID=6
  src="$kw_dir/$LOCAL_TO_DEPLOY_DIR/*"
  dst="$REMOTE_KW_DEPLOY"
  expected_command="rsync -e 'ssh -p 22' -La $src root@localhost:$dst"
  output=$(cp_host2remote "" "" "" "" "" "$flag")
  assertEquals "Command did not match ($ID)" "$expected_command" "$output"
}

function which_distro_Test
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

invoke_shunit
