#!/bin/bash

include './src/deploy.sh'
include './tests/utils.sh'

FAKE_KERNEL='tests/.tmp'

# Some of the functions invoked by kw need to be mocked; otherwise, we cannot
# test all the elements in the function. The following functions try to mimic
# some of these functions behaviour.
function which_distro_mock()
{
  printf '%s\n' 'debian'
}

function get_kernel_release_mock()
{
  printf '%s\n' '5.4.0-rc7-test'
}

function get_kernel_version_mock()
{
  printf '%s\n' '5.4.0-rc7'
}

function root_id_mock()
{
  printf '%s\n' '0'
}

function setUp()
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
  export KW_CACHE_DIR="$test_path"
  export KW_ETC_DIR="$PWD/$SAMPLES_DIR/etc"
  export DEPLOY_SCRIPT="$test_path/$kernel_install_path/deploy.sh"
  export KW_PLUGINS_DIR="$PWD/src/plugins/"
  export modules_path="$test_path/$kernel_install_path/lib/modules"

  mkdir "$test_path/$LOCAL_TO_DEPLOY_DIR"
  mkdir "$test_path/$LOCAL_REMOTE_DIR"
  if [[ -z "$create_mkinitcpio" ]]; then
    cp -f "$SAMPLES_DIR/$preset_name" "$FAKE_KERNEL/$LOCAL_TO_DEPLOY_DIR/test.preset"
  fi

  parse_configuration "$KW_CONFIG_SAMPLE"
  remote_parameters['REMOTE_IP']=${configurations[ssh_ip]}
  remote_parameters['REMOTE_PORT']=${configurations[ssh_port]}
  remote_parameters['REMOTE_USER']=${configurations[ssh_user]}

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

function test_modules_install_to()
{
  local ID
  local original="$PWD"

  # Copy test.preset to remote
  local make_install_cmd="make INSTALL_MOD_PATH=$test_path modules_install"

  cd "$test_path" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  ID=1
  output=$(modules_install_to "$test_path" "TEST_MODE")

  if [[ "$output" != "$make_install_cmd" ]]; then
    fail "$ID - Expected \"$output\" to be \"$make_install_cmd\""
  fi

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_install()
{
  local name='test'
  local original="$PWD"
  local reboot=1
  local remote='juca@127.0.0.1'
  local remote_path='/root/kw_deploy'
  local preset_path="$test_path/$LOCAL_TO_DEPLOY_DIR/test.preset"
  local kernel_image_path='arch/arm64/boot/Image'
  local kernel_image_remote_path="$REMOTE_KW_DEPLOY/vmlinuz-$name"
  local ssh_cmd='ssh -p 3333'
  local rsync_cmd="rsync -e '$ssh_cmd' -La"
  local deploy_params="$name debian Image $reboot arm64 'remote' TEST_MODE"
  local deploy_cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --kernel_update $deploy_params"

  # For this test we expected three steps:
  # 1. Copy preset file (cmd_preset_remote)
  # 2. Copy kernel image (cmd_image_remote)
  # 3. Execute deploy command (cmd_deploy_image)
  # The following commands represets those steps
  local cmd_preset_remote="$rsync_cmd $preset_path $remote:$remote_path --rsync-path='sudo rsync'"
  local cmd_chown_preset="$ssh_cmd $remote sudo \"chown -R root:root $remote_path\""
  local cmd_image_remote="$rsync_cmd $kernel_image_path $remote:$kernel_image_remote_path --rsync-path='sudo rsync'"
  local cmd_chown_image="$ssh_cmd $remote sudo \"chown -R root:root $kernel_image_remote_path\""
  local cmd_deploy_image="$ssh_cmd $remote sudo \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_preset_remote"
    "$cmd_chown_preset"
    "$cmd_image_remote"
    "$cmd_chown_image"
    "$cmd_deploy_image"
  )

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']=3333
  remote_parameters['REMOTE_USER']='juca'

  output=$(kernel_install 1 'test' 'TEST_MODE' 3) # 3: REMOTE_TARGET
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # Update values
  # NOTICE: I added one extra space in the below line for match what we
  # expect since I believe it is not worth to change the kernel_install
  # function just for it.
  deploy_params="$name debian Image 0 arm64 'remote' TEST_MODE"
  deploy_cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --kernel_update $deploy_params"
  cmd_deploy_image="$ssh_cmd $remote sudo \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_preset_remote"
    "$cmd_chown_preset"
    "$cmd_image_remote"
    "$cmd_chown_image"
    "$cmd_deploy_image"
  )

  output=$(kernel_install "0" "test" "TEST_MODE" "3" "127.0.0.1:3333")
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # We want to test an corner case described by the absence of mkinitcpio
  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
  tearDown
  setUp "no_mkinitcpio"
  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  output=$(kernel_install "0" "test" "TEST_MODE" "3" "127.0.0.1:3333")
  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  local preset_file="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/$name.preset"
  assertTrue "The mkinit file was not created" '[[ -f "$preset_file" ]]'

  tearDown
}

function test_kernel_install_x86_64()
{
  local name='test'
  local original="$PWD"
  local reboot=1
  local remote='root@localhost'
  local remote_path='/root/kw_deploy'
  local preset_path="$test_path/$LOCAL_TO_DEPLOY_DIR/test.preset"
  local kernel_image_path='arch/x86_64/boot/bzImage'
  local kernel_image_remote_path="$REMOTE_KW_DEPLOY/vmlinuz-$name"
  local ssh_cmd='ssh -p 22'
  local rsync_cmd="rsync -e '$ssh_cmd' -La"
  local deploy_params="$name debian bzImage $reboot x86_64 'remote' TEST_MODE"
  local deploy_cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --kernel_update $deploy_params"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  configurations=()
  remote_parameters=()
  cp "$KW_CONFIG_SAMPLE_X86" "$FAKE_KERNEL/kworkflow.config"
  parse_configuration "$FAKE_KERNEL/kworkflow.config"

  remote_parameters['REMOTE_IP']=${configurations[ssh_ip]}
  remote_parameters['REMOTE_PORT']=${configurations[ssh_port]}
  remote_parameters['REMOTE_USER']=${configurations[ssh_user]}

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # For this test we expected three steps:
  # 1. Copy preset file (cmd_preset_remote)
  # 2. Copy kernel image (cmd_image_remote)
  # 3. Execute deploy command (cmd_deploy_image)
  # The following commands represets those steps
  local cmd_preset_remote="$rsync_cmd $preset_path $remote:$remote_path --rsync-path='sudo rsync'"
  local cmd_chown_preset="$ssh_cmd $remote sudo \"chown -R root:root $remote_path\""
  local cmd_image_remote="$rsync_cmd $kernel_image_path $remote:$kernel_image_remote_path --rsync-path='sudo rsync'"
  local cmd_chown_image="$ssh_cmd $remote sudo \"chown -R root:root $kernel_image_remote_path\""
  local cmd_deploy_image="$ssh_cmd $remote sudo \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_preset_remote"
    "$cmd_chown_preset"
    "$cmd_image_remote"
    "$cmd_chown_image"
    "$cmd_deploy_image"
  )

  output=$(kernel_install 1 'test' 'TEST_MODE' 3 '127.0.0.1:3333')
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

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

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_modules()
{
  local count=0
  local original="$PWD"
  local remote_access='juca@127.0.0.1'
  local remote_path='/root/kw_deploy'
  local ssh_cmd='ssh -p 3333'
  local rsync_cmd="rsync -e '$ssh_cmd' -La"
  local kernel_install_path='tests/.tmp/kernel_install'
  local to_deploy_path='tests/.tmp/to_deploy'
  local local_remote_path='tests/.tmp/remote'
  local version='5.4.0-rc7-test'

  # Create remote directory
  local dir_kw_deploy="$ssh_cmd $remote_access sudo \"mkdir -p $remote_path\""

  # Rsync script command
  local rsync_debian="$rsync_cmd $kernel_install_path/debian.sh $remote_access:$remote_path/distro_deploy.sh --rsync-path='sudo rsync'"
  local cmd_chown_debian="$ssh_cmd $remote_access sudo \"chown -R root:root $remote_path/distro_deploy.sh\""

  local rsync_deploy="$rsync_cmd $kernel_install_path/deploy.sh $remote_access:$remote_path/ --rsync-path='sudo rsync'"
  local cmd_chown_deploy="$ssh_cmd $remote_access sudo \"chown -R root:root $remote_path/\""

  local rsync_utils="$rsync_cmd $kernel_install_path/utils.sh $remote_access:$remote_path/ --rsync-path='sudo rsync'"
  local cmd_chown_utils="$ssh_cmd $remote_access sudo \"chown -R root:root $remote_path/\""

  # Install modules
  local make_install_cmd="make INSTALL_MOD_PATH=$local_remote_path/ modules_install"

  # Kernel release
  local expected_output="Kernel: $version"

  # Compress modules for sending
  local compress_cmd="tar -C $local_remote_path/lib/modules/ --auto-compress -cf $to_deploy_path/$version.tar $version"

  # Rsync modules
  local rsync_tarball="$rsync_cmd $to_deploy_path/$version.tar $remote_access:$remote_path --rsync-path='sudo rsync'"
  local cmd_chown_tarball="$ssh_cmd $remote_access sudo \"chown -R root:root $remote_path\""

  # Install module inside remote
  local exec_module_install="$ssh_cmd $remote_access sudo \"bash $remote_path/deploy.sh --modules $version.tar\""

  declare -a expected_cmd=(
    "$dir_kw_deploy"
    "$rsync_debian"
    "$cmd_chown_debian"
    "$rsync_deploy"
    "$cmd_chown_deploy"
    "$rsync_utils"
    "$cmd_chown_utils"
    "$make_install_cmd"
    "$expected_output"
    "$compress_cmd"
    "$rsync_tarball"
    "$cmd_chown_tarball"
    "$exec_module_install"
  )

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  setupRemote

  # Create folder so generate_tarball won't complain
  mkdir -p "$local_remote_path/lib/modules/$version"

  output=$(modules_install 'TEST_MODE' 3)
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  output=$(modules_install 'TEST_MODE' 1)
  expected_output='make INSTALL_MOD_PATH=/home/lala modules_install'
  assertEquals "($LINENO):" "$output" "$expected_output"

  output=$(modules_install 'TEST_MODE' 2)
  expected_output="sudo -E make modules_install"
  assertEquals "($LINENO): " "$output" "$expected_output"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_modules_local()
{
  local original="$PWD"
  local cmd='sudo -E make modules_install'

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(modules_install 'TEST_MODE' 2)
  assertFalse "($LINENO):" '[[ "$cmd" != "$output" ]]'

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_install_local()
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
  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(kernel_install "1" "test" "TEST_MODE" "2")
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # Make sure that we are not running as a root user
  alias id='root_id_mock;true'
  output=$(kernel_install '1' 'test' 'TEST_MODE' '2')
  ret="$?"
  assertEquals "($LINENO)" '1' "$ret"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

# This test validates the correct behavior of list kernel on a remote machine
# by checking the expected command sequence; It is important to highlight that
# we are not testing the actual kernel list code, this part is validated on
# another test file.
function test_list_remote_kernels()
{
  local count=0
  local original="$PWD"
  local remote_access="juca@127.0.0.1"
  local remote_path="/root/kw_deploy"
  local ssh_cmd="ssh -p 3333"
  local rsync_cmd="rsync -e '$ssh_cmd' -La"

  local kernel_install_path="tests/.tmp/kernel_install"

  # Create remote directory
  local dir_kw_deploy="$ssh_cmd $remote_access sudo \"mkdir -p $remote_path\""

  # Rsync script command
  local rsync_debian="$rsync_cmd $kernel_install_path/debian.sh $remote_access:$remote_path/distro_deploy.sh --rsync-path='sudo rsync'"
  local cmd_chown_debian="$ssh_cmd $remote_access sudo \"chown -R root:root $remote_path/distro_deploy.sh\""

  local rsync_deploy="$rsync_cmd $kernel_install_path/deploy.sh $remote_access:$remote_path/ --rsync-path='sudo rsync'"
  local cmd_chown_deploy="$ssh_cmd $remote_access sudo \"chown -R root:root $remote_path/\""

  local rsync_utils="$rsync_cmd $kernel_install_path/utils.sh $remote_access:$remote_path/ --rsync-path='sudo rsync'"
  local cmd_chown_utils="$ssh_cmd $remote_access sudo \"chown -R root:root $remote_path/\""

  local remote_list_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"bash /root/kw_deploy/deploy.sh --list_kernels 0\""

  declare -a expected_cmd=(
    "$dir_kw_deploy"
    "$rsync_debian"
    "$cmd_chown_debian"
    "$rsync_deploy"
    "$cmd_chown_deploy"
    "$rsync_utils"
    "$cmd_chown_utils"
    "$remote_list_cmd"
  )

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  setupRemote

  output=$(list_installed_kernels "TEST_MODE" 0 3)
  while read -r f; do
    if [[ ${expected_cmd[$count]} != "${f}" ]]; then
      fail "$count - Expected cmd \"${f}\" to be \"${expected_cmd[$count]}\""
    fi
    ((count++))
  done <<< "$output"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_uninstall()
{
  local count=0
  local original="$PWD"
  local remote_access="juca@127.0.0.1"
  local remote_path="/root/kw_deploy"
  local ssh_cmd="ssh -p 3333"
  local rsync_cmd="rsync -e '$ssh_cmd' -La"
  local kernel_install_path="tests/.tmp/kernel_install"
  local kernel_list="5.5.0-rc7,5.6.0-rc8,5.7.0-rc2"
  local single_kernel="5.7.0-rc2"
  # Create remote directory
  local dir_kw_deploy="$ssh_cmd $remote_access sudo \"mkdir -p $remote_path\""

  # Rsync script command
  local cmd="bash $remote_path/deploy.sh --uninstall_kernel 0 remote $kernel_list TEST_MODE"

  local rsync_debian="$rsync_cmd $kernel_install_path/debian.sh $remote_access:$remote_path/distro_deploy.sh --rsync-path='sudo rsync'"
  local cmd_chown_debian="$ssh_cmd $remote_access sudo \"chown -R root:root $remote_path/distro_deploy.sh\""

  local rsync_deploy="$rsync_cmd $kernel_install_path/deploy.sh $remote_access:$remote_path/ --rsync-path='sudo rsync'"
  local cmd_chown_deploy="$ssh_cmd $remote_access sudo \"chown -R root:root $remote_path/\""

  local rsync_utils="$rsync_cmd $kernel_install_path/utils.sh $remote_access:$remote_path/ --rsync-path='sudo rsync'"
  local cmd_chown_utils="$ssh_cmd $remote_access sudo \"chown -R root:root $remote_path/\""

  local kernel_uninstall_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"$cmd\""

  declare -a expected_cmd=(
    "$dir_kw_deploy"
    "$rsync_debian"
    "$cmd_chown_debian"
    "$rsync_deploy"
    "$cmd_chown_deploy"
    "$rsync_utils"
    "$cmd_chown_utils"
    "$kernel_uninstall_cmd"
  )

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  setupRemote

  # List of kernels
  ID=1
  options_values['REMOTE_IP']='127.0.0.1'
  options_values['REMOTE_PORT']=3333
  output=$(kernel_uninstall 3 0 "$kernel_list" "TEST_MODE")
  compare_command_sequence 'expected_cmd' "$output" "$ID"

  # Reboot
  ID=2
  output=$(kernel_uninstall 3 1 "$kernel_list" "TEST_MODE")
  cmd="bash $remote_path/deploy.sh --uninstall_kernel 1 remote $kernel_list TEST_MODE"
  kernel_uninstall_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"$cmd\""
  expected_cmd[7]="$kernel_uninstall_cmd"

  compare_command_sequence 'expected_cmd' "$output" "$ID"

  # Single kernel
  ID=3
  output=$(kernel_uninstall 3 1 "$single_kernel" "TEST_MODE")
  cmd="bash $remote_path/deploy.sh --uninstall_kernel 1 remote $single_kernel TEST_MODE"
  kernel_uninstall_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"$cmd\""
  expected_cmd[7]="$kernel_uninstall_cmd"

  compare_command_sequence 'expected_cmd' "$output" "$ID"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_cleanup()
{
  local output=""
  local cmd_remote="rm -rf $test_path/$LOCAL_TO_DEPLOY_DIR/*"
  local cmd_to_deploy="rm -rf $test_path/$LOCAL_REMOTE_DIR/*"

  declare -a expected_cmd=(
    'Cleaning up temporary files...'
    "$cmd_to_deploy"
    "$cmd_remote"
    'Exiting...'
  )
  #shellcheck disable=SC2153
  options_values[REMOTE]=1
  output=$(cleanup "TEST_MODE")
  while read -r f; do
    assertFalse "$ID (cmd: $count) - Expected \"${f}\" to be \"${expected_cmd[$count]}\"" \
      '[[ ${expected_cmd[$count]} != ${f} ]]'
    ((count++))
  done <<< "$output"
}

function test_parse_deploy_options()
{
  unset options_values
  unset remote_parameters
  declare -gA options_values
  declare -gA remote_parameters
  local expected

  # test default options
  parse_deploy_options
  assertEquals "($LINENO)" '' "${options_values['UNINSTALL']}"
  assertEquals "($LINENO)" '0' "${options_values['LS']}"
  assertEquals "($LINENO)" '0' "${options_values['REBOOT']}"
  assertEquals "($LINENO)" '0' "${options_values['MODULES']}"
  assertEquals "($LINENO)" '0' "${options_values['LS_LINE']}"
  assertEquals "($LINENO)" 'nconfig' "${options_values['MENU_CONFIG']}"
  assertEquals "($LINENO)" '1' "${options_values['TARGET']}"

  # test individual options
  unset options_values
  declare -gA options_values
  parse_deploy_options --remote 'user@127.0.2.1:8888'
  assertEquals "($LINENO)" 'user' "${remote_parameters['REMOTE_USER']}"
  assertEquals "($LINENO)" '127.0.2.1:8888' "${remote_parameters['REMOTE']}"
  assertEquals "($LINENO)" '8888' "${remote_parameters['REMOTE_PORT']}"
  assertEquals "($LINENO)" '127.0.2.1' "${remote_parameters['REMOTE_IP']}"

  unset options_values
  declare -gA options_values
  expected="kw deploy: option '--remote' requires an argument"
  parse_deploy_options --remote
  assertEquals "($LINENO)" '22' "$?"
  assertEquals "($LINENO)" "$expected" "${options_values['ERROR']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --remote ':8888' > /dev/null
  assertEquals "($LINENO)" '22' "$?"
  assertEquals "($LINENO)" 'Invalid remote: :8888' "${options_values['ERROR']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --local
  assertEquals "($LINENO)" '2' "${options_values['TARGET']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --vm
  assertEquals "($LINENO)" '1' "${options_values['TARGET']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --reboot
  assertEquals "($LINENO)" '1' "${options_values['REBOOT']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -r
  assertEquals "($LINENO)" '1' "${options_values['REBOOT']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --modules
  assertEquals "($LINENO)" '1' "${options_values['MODULES']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -m
  assertEquals "($LINENO)" '1' "${options_values['MODULES']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --list
  assertEquals "($LINENO)" '1' "${options_values['LS']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -l
  assertEquals "($LINENO)" '1' "${options_values['LS']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --ls-line
  assertEquals "($LINENO)" '1' "${options_values['LS_LINE']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -s
  assertEquals "($LINENO)" '1' "${options_values['LS_LINE']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --uninstall 'kernel_xpto'
  assertEquals "($LINENO)" 'kernel_xpto' "${options_values['UNINSTALL']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -u 'kernel_xpto'
  assertEquals "($LINENO)" 'kernel_xpto' "${options_values['UNINSTALL']}"

  # test integration of options
  unset options_values
  declare -gA options_values
  parse_deploy_options --remote 'user@127.0.2.1:8888' -m --ls-line -u 'kernel_xpto'
  assertEquals "($LINENO)" 'kernel_xpto' "${options_values['UNINSTALL']}"
  assertEquals "($LINENO)" '1' "${options_values['MODULES']}"
  assertEquals "($LINENO)" '1' "${options_values['LS_LINE']}"
  assertEquals "($LINENO)" 'user' "${remote_parameters['REMOTE_USER']}"
  assertEquals "($LINENO)" '127.0.2.1:8888' "${remote_parameters['REMOTE']}"
  assertEquals "($LINENO)" '8888' "${remote_parameters['REMOTE_PORT']}"
  assertEquals "($LINENO)" '127.0.2.1' "${remote_parameters['REMOTE_IP']}"
}

invoke_shunit
