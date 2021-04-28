#!/bin/bash

. ./src/mk.sh --source-only
. ./tests/utils --source-only

function suite
{
  suite_addTest "build_info_Test"
  suite_addTest "mk_build_Test"
  suite_addTest "kernel_deploy_Test"
  suite_addTest "modules_install_to_Test"
  suite_addTest "kernel_install_Test"
  suite_addTest "kernel_install_x86_64_Test"
  suite_addTest "kernel_modules_Test"
  suite_addTest "kernel_modules_local_Test"
  suite_addTest "kernel_install_local_Test"
  suite_addTest "mk_list_remote_kernels_Test"
  suite_addTest "mk_kernel_uninstall_Test"
  suite_addTest "cleanup_after_deploy_Test"
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
  echo '5.4.0-rc7-test'
}

function get_kernel_version_mock()
{
  echo '5.4.0-rc7'
}

function root_id_mock()
{
  echo "0"
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
  export KW_PLUGINS_DIR="$test_path"
  export KW_CACHE_DIR="$test_path"
  export KW_ETC_DIR="$PWD/$SAMPLES_DIR/etc"
  export DEPLOY_SCRIPT="$test_path/$kernel_install_path/deploy.sh"
  export KW_PLUGINS_DIR="$PWD/src/plugins/"
  export modules_path="$test_path/$kernel_install_path/lib/modules"
  if [ -x "$(command -v nproc)" ] ; then
    PARALLEL_CORES=$(nproc --all)
  else
    PARALLEL_CORES=$(grep -c ^processor /proc/cpuinfo)
  fi
  export PARALLEL_CORES

  mkdir "$test_path/$LOCAL_TO_DEPLOY_DIR"
  mkdir "$test_path/$LOCAL_REMOTE_DIR"
  if [[ -z "$create_mkinitcpio" ]]; then
    cp -f "$SAMPLES_DIR/$preset_name" "$FAKE_KERNEL/$LOCAL_TO_DEPLOY_DIR/test.preset"
  fi

  parse_configuration "$KW_CONFIG_SAMPLE"

  # Mock functions
  shopt -s expand_aliases
  alias which_distro='which_distro_mock'
  alias detect_distro='which_distro_mock'
  alias get_kernel_release='get_kernel_release_mock'
  alias get_kernel_version='get_kernel_version_mock'
}

function setupRemote()
{
  local -r modules_name="test"
  local -r kernel_install_path="kernel_install"

  export test_path="$FAKE_KERNEL"
  export KW_CACHE_DIR="$test_path"
  export KW_PLUGINS_DIR="$test_path"
  export DEPLOY_SCRIPT="$test_path/$kernel_install_path/deploy.sh"
  export DEPLOY_SCRIPT_SUPPORT="$test_path/$kernel_install_path/utils.sh"
  export modules_path="$test_path/$kernel_install_path/lib/modules"
  rm -rf "$test_path"

  # Kw repositories
  mkdir -p "$test_path/{$LOCAL_TO_DEPLOY_DIR,$LOCAL_REMOTE_DIR,$LOCAL_REMOTE_DIR}"
  mkdir -p "$modules_path/$modules_name"

  touch "$modules_path/$modules_name/file{1,2}"
  touch "$test_path/$kernel_install_path/{debian.sh,deploy.sh,utils.sh}"
}

function tearDown()
{
  unset KW_CACHE_DIR
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

function mk_build_Test()
{
  local ID
  local expected_result
  local original="$PWD"

  ID=1
  output=$(mk_build 'TEST_MODE')
  ret="$?"
  assertEquals "($ID) We expected an error" "125" "$ret"

  cd "$FAKE_KERNEL"
  ID=2
  output=$(mk_build 'TEST_MODE' '--menu')
  expected_result="make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- nconfig"
  assertEquals "($ID)" "$expected_result" "$output"

  ID=3
  output=$(mk_build 'TEST_MODE' '--notvalid')
  ret="$?"
  assertEquals "($ID)" "$ret" "22"

  ID=4
  output=$(mk_build 'TEST_MODE' | head -1) # Remove statistics output
  expected_result="make -j$PARALLEL_CORES ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-"
  assertEquals "($ID)" "$expected_result" "${output}"

  ID=5
  cd "$original"
  configurations=()
  cp "$KW_CONFIG_SAMPLE_X86" "$FAKE_KERNEL/kworkflow.config"
  parse_configuration "$FAKE_KERNEL/kworkflow.config"
  cd "$FAKE_KERNEL"

  output=$(mk_build 'TEST_MODE' | head -1) # Remove statistics output
  expected_result="make -j$PARALLEL_CORES ARCH=x86_64 "
  assertEquals "($ID)" "$expected_result" "${output}"

  cd "$original"
}

# This test relies on kworkflow.config loaded during the setUp
#
# Output sequence of kernel_deploy in the TEST_MODE:
#   $reboot $modules $target $remote $single_line $list"
function kernel_deploy_Test
{
  local ID
  local original="$PWD"

  cd "$FAKE_KERNEL"

  # From kworkflow.config file we expect 0 0 1 127.0.0.1:3333 0 0
  ID=1
  output=$(kernel_deploy test_mode)
  expected_result="0 0 1 127.0.0.1:3333 0 0"
  assertEquals "($ID) Pure config:" "$expected_result" "$output"

  ID=2
  output=$(kernel_deploy test_mode --modules)
  expected_result="0 1 1 127.0.0.1:3333 0 0"
  assertEquals "($ID) Modules:" "$expected_result" "$output"

  ID=3
  output=$(kernel_deploy test_mode --reboot)
  expected_result="1 0 1 127.0.0.1:3333 0 0"
  assertEquals "($ID) Reboot: " "$expected_result" "$output"

  ID=4
  output=$(kernel_deploy test_mode --reboot --modules)
  expected_result="1 1 1 127.0.0.1:3333 0 0"
  assertEquals "($ID) Reboot, Modules:" "$expected_result" "$output"

  ID=5
  output=$(kernel_deploy test_mode --local --reboot --modules)
  expected_result="1 1 2 127.0.0.1:3333 0 0"
  assertEquals "($ID) Local, Reboot, Modules" "$expected_result" "$output"

  ID=6
  output=$(kernel_deploy test_mode --remote --reboot)
  expected_result="1 0 3 127.0.0.1:3333 0 0"
  assertEquals "($ID) Remote, Reboot" "$expected_result" "$output"

  ID=7
  output=$(kernel_deploy test_mode --remote 192.168.0.10 --reboot)
  expected_result="1 0 3 192.168.0.10:22 0 0"
  assertEquals "($ID) Remote: 192.168.0.10, Reboot" "$expected_result" "$output"

  ID=8
  output=$(kernel_deploy test_mode --remote 192.168.0.10:1287)
  expected_result="0 0 3 192.168.0.10:1287 0 0"
  assertEquals "($ID) Remote: 192.168.0.10:1287" "$expected_result" "$output"

  # Test some invalid parameters
  ID=9
  output=$(kernel_deploy test_mode --rem 192.168.0.10:1287)
  ret="$?"
  expected_return="22"
  assertEquals "($ID) Invalid parameter: --rem" "$expected_return" "$ret"

  ID=10
  output=$(kernel_deploy test_mode --lalala)
  ret="$?"
  expected_return="22"
  assertEquals "($ID) Invalid parameter: --lalala" "$expected_return" "$ret"

  ID=11
  output=$(kernel_deploy test_mode --uninstall)
  ret="$?"
  expected_return="22"
  assertEquals "($ID) Uninstall without parameter should fail" "$expected_return" "$ret"

  ID=12
  output=$(kernel_deploy test_mode --uninstall --remote lala)
  ret="$?"
  expected_return="22"
  assertEquals "($ID) Uninstall requires parameter" "$expected_return" "$ret"

  ID=13
  output=$(kernel_deploy test_mode --remote --uninstall)
  ret="$?"
  expected_return="22"
  assertEquals "($ID) Uninstall requires parameter without --" "$expected_return" "$ret"

  ID=14
  output=$(kernel_deploy test_mode --remote lala --uninstall)
  ret="$?"
  expected_return="22"
  assertEquals "($ID) Uninstall requires parameter" "$expected_return" "$ret"

  # Test some invalid case
  tearDown
  ID=14
  output=$(kernel_deploy test_mode)
  expected_result="$?"
  assertEquals "($ID) No config:" "$expected_result" "22"

  cd "$original"
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
  local name="test"
  local original="$PWD"
  local reboot="1"
  local remote="root@127.0.0.1"
  local remote_path="/root/kw_deploy"
  local preset_path="$test_path/$LOCAL_TO_DEPLOY_DIR/test.preset"
  local kernel_image_path="arch/arm64/boot/Image"
  local kernel_image_remote_path="$REMOTE_KW_DEPLOY/vmlinuz-$name"
  local ssh_cmd="ssh -p 3333"
  local rsync_cmd="rsync -e '$ssh_cmd' -La"
  local deploy_params="$name debian Image $reboot arm64 'remote' TEST_MODE"
  local deploy_cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --kernel_update $deploy_params"

  # For this test we expected three steps:
  # 1. Copy preset file (cmd_preset_remote)
  # 2. Copy kernel image (cmd_image_remote)
  # 3. Execute deploy command (cmd_deploy_image)
  # The following commands represets those steps
  local cmd_preset_remote="$rsync_cmd $preset_path $remote:$remote_path"
  local cmd_image_remote="$rsync_cmd $kernel_image_path $remote:$kernel_image_remote_path"
  local cmd_deploy_image="$ssh_cmd $remote \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_preset_remote"
    "$cmd_image_remote"
    "$cmd_deploy_image"
  )

  cd "$FAKE_KERNEL"

  output=$(kernel_install "1" "test" "TEST_MODE" "3" "127.0.0.1:3333")
  compare_command_sequence expected_cmd[@] "$output" "$LINENO"

  # Update values
  # NOTICE: I added one extra space in the below line for match what we
  # expect since I believe it is not worth to change the kernel_install
  # function just for it.
  deploy_params="$name debian Image 0 arm64 'remote' TEST_MODE"
  deploy_cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --kernel_update $deploy_params"
  cmd_deploy_image="$ssh_cmd $remote \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_preset_remote"
    "$cmd_image_remote"
    "$cmd_deploy_image"
  )

  output=$(kernel_install "0" "test" "TEST_MODE" "3" "127.0.0.1:3333")
  compare_command_sequence expected_cmd[@] "$output" "$LINENO"

  # We want to test an corner case described by the absence of mkinitcpio
  cd "$original"
  tearDown
  setUp "no_mkinitcpio"
  cd "$FAKE_KERNEL"
  output=$(kernel_install "0" "test" "TEST_MODE" "3" "127.0.0.1:3333")
  cd "$original"

  local preset_file="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/$name.preset"
  assertTrue "The mkinit file was not created" '[[ -f "$preset_file" ]]'

  tearDown
}

function kernel_install_x86_64_Test
{
  local name="test"
  local original="$PWD"
  local reboot="1"
  local remote="root@127.0.0.1"
  local remote_path="/root/kw_deploy"
  local preset_path="$test_path/$LOCAL_TO_DEPLOY_DIR/test.preset"
  local kernel_image_path="arch/x86_64/boot/bzImage"
  local kernel_image_remote_path="$REMOTE_KW_DEPLOY/vmlinuz-$name"
  local ssh_cmd="ssh -p 3333"
  local rsync_cmd="rsync -e '$ssh_cmd' -La"
  local deploy_params="$name debian bzImage $reboot x86_64 'remote' TEST_MODE"
  local deploy_cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --kernel_update $deploy_params"

  cd "$original"
  configurations=()
  cp "$KW_CONFIG_SAMPLE_X86" "$FAKE_KERNEL/kworkflow.config"
  parse_configuration "$FAKE_KERNEL/kworkflow.config"
  cd "$FAKE_KERNEL"

  # For this test we expected three steps:
  # 1. Copy preset file (cmd_preset_remote)
  # 2. Copy kernel image (cmd_image_remote)
  # 3. Execute deploy command (cmd_deploy_image)
  # The following commands represets those steps
  local cmd_preset_remote="$rsync_cmd $preset_path $remote:$remote_path"
  local cmd_image_remote="$rsync_cmd $kernel_image_path $remote:$kernel_image_remote_path"
  local cmd_deploy_image="$ssh_cmd $remote \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_preset_remote"
    "$cmd_image_remote"
    "$cmd_deploy_image"
  )

  output=$(kernel_install "1" "test" "TEST_MODE" "3" "127.0.0.1:3333")
  compare_command_sequence expected_cmd[@] "$output" "$LINENO"

  # Test kernel image infer
  configurations['kernel_img_name']=''
  output=$(kernel_install "1" "test" "TEST_MODE" "3" "127.0.0.1:3333" | head -1)
  expected_msg='kw inferred arch/x86_64/boot/arch/x86_64/boot/bzImage as a kernel image'
  assert_equals_helper "Infer kernel image" "$LINENO" "$expected_msg" "$output"

  # Test failures
  rm -rf arch/x86_64/
  output=$(kernel_install "1" "test" "TEST_MODE" "3" "127.0.0.1:3333" | head -1)
  expected_msg='We could not find a valid kernel image at arch/x86_64/boot'
  assertEquals "($LINENO): " "$output" "$expected_msg"
  assert_equals_helper "Could not find a valid image" "$LINENO" "$expected_msg" "$output"

  cd "$original"
}

function kernel_modules_Test
{
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
  local rsync_utils="$rsync_cmd $kernel_install_path/utils.sh $remote_access:$remote_path/"

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
    "$rsync_utils"
    "$make_install_cmd"
    "$expected_output"
    "$compress_cmd"
    "$rsync_tarball"
    "$exec_module_install"
  )

  cd "$FAKE_KERNEL"

  setupRemote

  ID=1
  output=$(modules_install "TEST_MODE" "3" "127.0.0.1:3333")
  while read f; do
    if [[ ${expected_cmd[$count]} != ${f} ]]; then
      fail "$count - Expected cmd \"${expected_cmd[$count]}\" to be \"${f}\""
    fi
    ((count++))
  done <<< "$output"

  ID=2
  output=$(modules_install "TEST_MODE" "1" "")
  expected_output="make INSTALL_MOD_PATH=/home/lala modules_install"
  assertEquals "$ID: " "$output" "$expected_output"

  ID=3
  output=$(modules_install "TEST_MODE" "2" "")
  expected_output="sudo -E make modules_install"
  assertEquals "$ID: " "$output" "$expected_output"


  cd "$original"
}

function kernel_modules_local_Test
{
  local ID
  local original="$PWD"
  local cmd="sudo -E make modules_install"

  cd "$FAKE_KERNEL"
  ID=1
  output=$(modules_install "TEST_MODE" "2")
  assertFalse "$ID - Expected $output to be $cmd" '[[ "$cmd" != "$output" ]]'
  cd "$original"
}

function kernel_install_local_Test
{
  local count=0
  local original="$PWD"
  # We force Debian files in the setup; for this reason, we are using the
  # commands used to deploy a new kernel image on debian.
  local cmd_cp_kernel_img="sudo -E cp -v arch/arm64/boot/Image /boot/vmlinuz-test"
  local cmd_update_initramfs="sudo -E update-initramfs -c -k test"
  local cmd_update_grub="sudo -E grub-mkconfig -o /boot/grub/grub.cfg"
  local cmd_reboot="sudo -E reboot"
  local msg=""

  declare -a expected_cmd=(
    "$cmd_cp_kernel_img"
    "$cmd_update_initramfs"
    "$cmd_update_grub"
    "$cmd_reboot"
  )

  # ATTENTION: $FAKE_KERNEL got two levels deep (tests/.tmp); for this reason,
  # we have to update KW_PLUGINS_DIR for this test for making sure that we use a
  # real plugin.
  export KW_PLUGINS_DIR="../../src/plugins"
  cd "$FAKE_KERNEL"

  output=$(kernel_install "1" "test" "TEST_MODE" "2")
  compare_command_sequence expected_cmd[@] "$output" "$LINENO"

  ID=2
  alias "id"="root_id_mock;true"
  output=$(kernel_install "1" "test" "TEST_MODE" "2")
  ret="$?"
  assertEquals "1" "$ret"

  cd "$original"
}

# This test validates the correct behavior of list kernel on a remote machine
# by checking the expected command sequence; It is important to highlight that
# we are not testing the actual kernel list code, this part is validated on
# another test file.
function mk_list_remote_kernels_Test
{
  local count=0
  local original="$PWD"
  local remote_access="root@127.0.0.1"
  local remote_path="/root/kw_deploy"
  local ssh_cmd="ssh -p 3333"
  local rsync_cmd="rsync -e '$ssh_cmd' -La"

  local kernel_install_path="tests/.tmp/kernel_install"

  # Create remote directory
  local dir_kw_deploy="$ssh_cmd $remote_access \"mkdir -p $remote_path\""

  # Rsync script command
  local rsync_debian="$rsync_cmd $kernel_install_path/debian.sh $remote_access:$remote_path/distro_deploy.sh"
  local rsync_deploy="$rsync_cmd $kernel_install_path/deploy.sh $remote_access:$remote_path/"
  local rsync_utils="$rsync_cmd $kernel_install_path/utils.sh $remote_access:$remote_path/"
  local remote_list_cmd="ssh -p 3333 root@127.0.0.1 \"bash /root/kw_deploy/deploy.sh --list_kernels 0\""

  declare -a expected_cmd=(
    "$dir_kw_deploy"
    "$rsync_debian"
    "$rsync_deploy"
    "$rsync_utils"
    "$remote_list_cmd"
  )

  cd "$FAKE_KERNEL"

  setupRemote

  output=$(mk_list_installed_kernels "TEST_MODE" "0" "3" "127.0.0.1:3333")
  while read f; do
    if [[ ${expected_cmd[$count]} != ${f} ]]; then
      fail "$count - Expected cmd \"${expected_cmd[$count]}\" to be \"${f}\""
    fi
    ((count++))
  done <<< "$output"

  cd "$original"
}

function mk_kernel_uninstall_Test
{
  local count=0
  local original="$PWD"
  local remote_access="root@127.0.0.1"
  local remote_path="/root/kw_deploy"
  local ssh_cmd="ssh -p 3333"
  local rsync_cmd="rsync -e '$ssh_cmd' -La"
  local kernel_install_path="tests/.tmp/kernel_install"
  local kernel_list="5.5.0-rc7,5.6.0-rc8,5.7.0-rc2"
  local single_kernel="5.7.0-rc2"
  # Create remote directory
  local dir_kw_deploy="$ssh_cmd $remote_access \"mkdir -p $remote_path\""

  # Rsync script command
  local cmd="bash $remote_path/deploy.sh --uninstall_kernel 0 remote $kernel_list TEST_MODE"
  local rsync_debian="$rsync_cmd $kernel_install_path/debian.sh $remote_access:$remote_path/distro_deploy.sh"
  local rsync_deploy="$rsync_cmd $kernel_install_path/deploy.sh $remote_access:$remote_path/"
  local rsync_utils="$rsync_cmd $kernel_install_path/utils.sh $remote_access:$remote_path/"
  local kernel_uninstall_cmd="ssh -p 3333 root@127.0.0.1 \"$cmd\""

  declare -a expected_cmd=(
    "$dir_kw_deploy"
    "$rsync_debian"
    "$rsync_deploy"
    "$rsync_utils"
    "$kernel_uninstall_cmd"
  )

  cd "$FAKE_KERNEL"

  setupRemote

  # List of kernels
  ID=1
  output=$(mk_kernel_uninstall "3" "0" "127.0.0.1:3333" "$kernel_list" "TEST_MODE")
  compare_command_sequence expected_cmd[@] "$output" "$ID"

  # Reboot
  ID=2
  output=$(mk_kernel_uninstall "3" "1" "127.0.0.1:3333" "$kernel_list" "TEST_MODE")
  cmd="bash $remote_path/deploy.sh --uninstall_kernel 1 remote $kernel_list TEST_MODE"
  kernel_uninstall_cmd="ssh -p 3333 root@127.0.0.1 \"$cmd\""
  expected_cmd[4]="$kernel_uninstall_cmd"

  compare_command_sequence expected_cmd[@] "$output" "$ID"

  # Single kernel
  ID=3
  output=$(mk_kernel_uninstall "3" "1" "127.0.0.1:3333" "$single_kernel" "TEST_MODE")
  cmd="bash $remote_path/deploy.sh --uninstall_kernel 1 remote $single_kernel TEST_MODE"
  kernel_uninstall_cmd="ssh -p 3333 root@127.0.0.1 \"$cmd\""
  expected_cmd[4]="$kernel_uninstall_cmd"

  compare_command_sequence expected_cmd[@] "$output" "$ID"

  cd "$original"
}

function cleanup_after_deploy_Test
{
  local output=""
  local cmd_remote="rm -rf $test_path/$LOCAL_TO_DEPLOY_DIR/*"
  local cmd_to_deploy="rm -rf $test_path/$LOCAL_REMOTE_DIR/*"

  declare -a expected_cmd=(
    "$cmd_to_deploy"
    "$cmd_remote"
  )

  output=$(cleanup_after_deploy "TEST_MODE")
  while read f; do
    assertFalse "$ID (cmd: $count) - Expected \"${expected_cmd[$count]}\" to be \"${f}\"" \
                '[[ ${expected_cmd[$count]} != ${f} ]]'
    ((count++))
  done <<< "$output"
}

function build_info_Test
{
  local original="$PWD"
  local release='5.4.0-rc7-test'
  local version='5.4.0-rc7'
  local release_output="Name: $release"
  local version_output="Version: $version"
  local modules='Total modules to be compiled: 5'

  declare -a expected_cmd=(
    'Kernel source information'
    "$release_output"
    "$version_output"
  )

  cd "$FAKE_KERNEL"
  output=$(mk_build 'TEST_MODE' '--info')
  compare_command_sequence expected_cmd[@] "$output" "($LINENO)"

  cp "$original/tests/samples/.config" .config
  expected_cmd[3]="$modules"
  output=$(mk_build 'TEST_MODE' '--info')
  compare_command_sequence expected_cmd[@] "$output" "($LINENO)"
  rm .config

  cd "$original"
}

invoke_shunit
