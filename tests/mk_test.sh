#!/bin/bash

. ./src/mk.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "valid_parser_command_Test"
  suite_addTest "invalid_parser_command_Test"
  suite_addTest "modules_install_to_Test"
  suite_addTest "kernel_install_Test"
  suite_addTest "kernel_modules_Test"
}

FAKE_KERNEL="tests/.tmp"

# Some of the functions invoked by kw need to be mocked; otherwise, we cannot
# test all the elements in the function. The following functions try to mimic
# some of these functions behaviour.
function which_distro_mock()
{
  echo "debian"
}

function get_kernel_release_mock()
{
  echo "5.4.0-rc7-test"
}

function setUp
{
  local create_mkinitcpio="$1"

  rm -rf "$FAKE_KERNEL"

  # This creates tests/.tmp which should mock a kernel tree root. A .git
  # dir is also created inside tests/.tmp so that get_maintainer.pl thinks
  # it is a git repo. This is done in order to avoid some warnings that
  # get_maintainer.pl prints when no .git is found.
  mk_fake_kernel_root "$FAKE_KERNEL"

  cp -f "$MAINTAINERS_SAMPLE" "$FAKE_KERNEL"
  cp -f "$CHECKPATH_EXT" "$FAKE_KERNEL/scripts/"

  export preset_name="template_mkinitcpio.preset"
  export test_path="$PWD/$FAKE_KERNEL"
  export kw_dir="$test_path"
  export etc_files_path="$PWD/$SAMPLES_DIR/etc"

  mkdir "$test_path/$LOCAL_TO_DEPLOY_DIR"
  if [[ -z "$create_mkinitcpio" ]]; then
    cp -f "$SAMPLES_DIR/$preset_name" "$FAKE_KERNEL/$LOCAL_TO_DEPLOY_DIR/test.preset"
  fi

  parse_configuration "$KW_CONFIG_SAMPLE"

  # Mock functions
  shopt -s expand_aliases
  alias which_distro='which_distro_mock'
  alias get_kernel_release='get_kernel_release_mock'
}

function setupRemote()
{
  local -r modules_name="test"
  local -r kernel_install_path="kernel_install"

  export test_path="$FAKE_KERNEL"
  export kw_dir="$test_path"
  export plugins_path="$test_path"
  export DEPLOY_SCRIPT="$test_path/$kernel_install_path/deploy.sh"
  export modules_path="$test_path/$kernel_install_path/lib/modules"
  rm -rf "$test_path"

  # Kw repositories
  mkdir -p "$test_path/{$LOCAL_TO_DEPLOY_DIR,$LOCAL_REMOTE_DIR,$LOCAL_REMOTE_DIR}"
  mkdir -p "$modules_path/$modules_name"

  touch "$modules_path/$modules_name/file{1,2}"
  touch "$test_path/$kernel_install_path/{debian.sh,deploy.sh}"
}

function tearDown()
{
  unset kw_dir
  configurations=()

  rm -rf "$FAKE_KERNEL"
}

function test_expected_string()
{
  local msg="$1"
  local expected="$2"
  local target="$3"

  assertEquals "$msg" "$target" "$expected"
}

function valid_parser_command_Test
{
  local ID

  # Force an unspected error
  tearDown
  ID=0
  output=$(parser_command --remote)
  ret="$?"
  assertEquals "($ID) We did not load kworkflow.config, we expect an error" "22" "$ret"
  setUp

  ID=1
  parser_command --vm
  ret="$?"
  assertEquals "($ID) Expected 1, which means VM" "1" "$ret"

  ID=2
  parser_command --local
  ret="$?"
  assertEquals "($ID) Expected 2, which means local" "2" "$ret"

  ID=3
  output=$(parser_command --remote)
  ret="$?"
  assertEquals "($ID) Expected 3, which means local" "3" "$ret"
  assertEquals "($ID) Expected 127.0.0.1:3333" "127.0.0.1:3333" "$output"

  ID=4
  output=$(parser_command --remote "localhost:6789")
  ret="$?"
  assertEquals "($ID) Expected 3, which means local" "3" "$ret"
  assertEquals "($ID) Expected localhost:6789" "localhost:6789" "$output"

  ID=5
  output=$(parser_command --remote "localhost")
  ret="$?"
  assertEquals "($ID) Expected 3, which means local" "3" "$ret"
  assertEquals "($ID) Expected localhost:22" "localhost:22" "$output"

  ID=6
  output=$(parser_command)
  ret="$?"
  assertEquals "($ID) Expected 1, default is vm" "1" "$ret"
}

function invalid_parser_command_Test
{
  local ID

  ID=1
  output=$(parser_command --vmm)
  ret="$?"
  assertEquals "($ID) Expected 22, invalid argument" "22" "$ret"

  ID=2
  output=$(parser_command -vm)
  ret="$?"
  assertEquals "($ID) Expected 22, invalid argument" "22" "$ret"

  ID=3
  output=$(parser_command -local)
  ret="$?"
  assertEquals "($ID) Expected 22, invalid argument" "22" "$ret"

  ID=4
  output=$(parser_command -remote)
  ret="$?"
  assertEquals "($ID) Expected 22, invalid argument" "22" "$ret"

  ID=5
  output=$(parser_command remote)
  ret="$?"
  assertEquals "($ID) Expected 22, invalid argument" "22" "$ret"
}

function modules_install_to_Test
{
  local ID
  local original="$PWD"

  # Copy test.preset to remote
  local make_install_cmd="make INSTALL_MOD_PATH=$test_path modules_install"

  cd "$test_path"

  ID=1
  output=$(modules_install_to "$test_path" "TEST_MODE")

  if [[ "$output" != "$make_install_cmd" ]]; then
    fail "$ID - Expected \"$output\" to be \"$make_install_cmd\""
  fi

  cd "$original"
}

function kernel_install_Test
{
  local ID
  local count=0
  local name="test"
  local original="$PWD"
  local reboot="--reboot"
  local remote_access="root@127.0.0.1"
  local remote_path="/root/kw_deploy"
  local preset_path="$test_path/$LOCAL_TO_DEPLOY_DIR/test.preset"
  local bzImage_path="arch/x86_64/boot/bzImage"
  local bzImage_remote_path="$REMOTE_KW_DEPLOY/vmlinuz-$name"

  local ssh_cmd="ssh -p 3333"
  local rsync_cmd="rsync -e '$ssh_cmd' -La"
  local deploy_cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --kernel_update $name $reboot"

  # For this test we expected three steps:
  # 1. Copy preset file
  # 2. Copy kernel image
  # 3. Execute deploy command
  # The following commands represets those steps

  # Copy test.preset to remote
  local cmd_preset_remote="$rsync_cmd $preset_path $remote_access:$remote_path"

  # Copy bzImage to remote
  local cmd_image_remote="$rsync_cmd $bzImage_path $remote_access:$bzImage_remote_path"

  # Execute deploy command
  local cmd_deploy_image="$ssh_cmd $remote_access \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_preset_remote"
    "$cmd_image_remote"
    "$cmd_deploy_image"
  )

  cd "$FAKE_KERNEL"

  ID=1
  output=$(kernel_install "--reboot" "test" "TEST_MODE" "--remote")
  while read f; do
    if [[ ${expected_cmd[$count]} != ${f} ]]; then
      fail "$ID - Expected cmd \"${expected_cmd[$count]}\" to be \"${f}\""
    fi
    ((count++))
  done <<< "$output"

  ID=2
  # Update values
  count=0
  # NOTICE: I added one extra space in the below line for match what we
  # expect since I believe it is not worth to change the kernel_install
  # function just for it.
  deploy_cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --kernel_update $name "
  cmd_deploy_image="$ssh_cmd $remote_access \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_preset_remote"
    "$cmd_image_remote"
    "$cmd_deploy_image"
  )

  output=$(kernel_install "" "test" "TEST_MODE" "--remote")
  while read f; do
    if [[ ${expected_cmd[$count]} != ${f} ]]; then
      fail "$ID - Expected cmd \"${expected_cmd[$count]}\" to be \"${f}\""
    fi
    ((count++))
  done <<< "$output"

  cd "$original"
  tearDown

  # We want to test an corner case described by the absence of mkinitcpio
  setUp "no_mkinitcpio"
  ID=3
  cd "$FAKE_KERNEL"
  output=$(kernel_install "" "test" "TEST_MODE" "--remote")
  cd "$original"

  local preset_file="$kw_dir/$LOCAL_TO_DEPLOY_DIR/$name.preset"
  assertTrue "The mkinit file was not created" '[[ -f "$preset_file" ]]'

  tearDown
}

function kernel_modules_Test
{
  local ID
  local count=0
  local original="$PWD"
  local remote_access="root@127.0.0.1"
  local remote_path="/root/kw_deploy"
  local ssh_cmd="ssh -p 3333"
  local rsync_cmd="rsync -e '$ssh_cmd' -La"

  local kernel_install_path="tests/.tmp/kernel_install"
  local to_deploy_path="tests/.tmp/to_deploy"
  local local_remote_path="tests/.tmp/remote"

  local version="5.4.0-rc7-test"

  # Create remote directory
  local dir_kw_deploy="$ssh_cmd $remote_access \"mkdir -p $remote_path\""

  # Rsync script command
  local rsync_debian="$rsync_cmd $kernel_install_path/debian.sh $remote_access:$remote_path/distro_deploy.sh"
  local rsync_deploy="$rsync_cmd $kernel_install_path/deploy.sh $remote_access:$remote_path/"

  # Install modules
  local make_install_cmd="make INSTALL_MOD_PATH=$local_remote_path/ modules_install"

  # Kernel release
  local expected_output="Kernel: $version"

  # Compress modules for sending
  local compress_cmd="tar -C $local_remote_path/lib/modules/ -cf $to_deploy_path/$version.tar $version"

  # Rsync modules
  local rsync_tarball="$rsync_cmd $to_deploy_path/$version.tar $remote_access:$remote_path"

  # Install module inside remote
  local exec_module_install="$ssh_cmd $remote_access \"bash $remote_path/deploy.sh --modules $version.tar\""

  declare -a expected_cmd=(
    "$dir_kw_deploy"
    "$rsync_debian"
    "$rsync_deploy"
    "$make_install_cmd"
    "$expected_output"
    "$compress_cmd"
    "$rsync_tarball"
    "$exec_module_install"
  )

  cd "$FAKE_KERNEL"

  setupRemote

  ID=1
  output=$(modules_install "TEST_MODE" "--remote")
  while read f; do
    if [[ ${expected_cmd[$count]} != ${f} ]]; then
      fail "$ID - Expected cmd \"${expected_cmd[$count]}\" to be \"${f}\""
    fi
    ((count++))
  done <<< "$output"

  cd "$original"
}

invoke_shunit
