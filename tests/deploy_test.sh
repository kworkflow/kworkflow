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

function detect_distro_mock()
{
  printf '%s\n' 'arch'
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

function date_mock()
{
  printf '12/31/2021-09:49:21\n'
}

function collect_deploy_info_mock()
{
  printf '[bootloader]=GRUB [distro]=arch'
}

function oneTimeSetUp()
{
  function sudo()
  {
    eval "$*"
  }
  export -f sudo
}

function setUp()
{
  local create_mkinitcpio="$1"

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
  export KW_PLUGINS_DIR="$PWD/src/plugins"
  export modules_path="$test_path/$kernel_install_path/lib/modules"

  KW_LIB_DIR="$PWD/$SAMPLES_DIR"

  mkdir "$test_path/$LOCAL_TO_DEPLOY_DIR"
  mkdir "$test_path/$LOCAL_REMOTE_DIR"
  if [[ -z "$create_mkinitcpio" ]]; then
    cp -f "$SAMPLES_DIR/$preset_name" "$FAKE_KERNEL/$LOCAL_TO_DEPLOY_DIR/test.preset"
  fi

  # Let's add some files to make it a little bit more realistic
  touch "$test_path/$LOCAL_TO_DEPLOY_DIR/file_1"

  touch "$test_path/$LOCAL_REMOTE_DIR/file_1"
  touch "$test_path/$LOCAL_REMOTE_DIR/file_2"

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

  # Global variable
  REMOTE_KW_DEPLOY='/opt/kw'
}

function setupRemote()
{
  local -r modules_name="test"
  local -r kernel_install_path="kernel_install"

  export test_path="$FAKE_KERNEL"
  export KW_CACHE_DIR="$test_path"
  export KW_PLUGINS_DIR="$test_path"
  export DEPLOY_SCRIPT="$test_path/$kernel_install_path/deploy.sh"
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
  configurations=()

  rm -rf "$FAKE_KERNEL"
}

function test_setup_remote_ssh_with_passwordless()
{
  local output
  declare -a expected_cmd=(
    '-> Trying to set up passwordless access'
    '' # Extra line due to \n in the say message
    'ssh-copy-id root@127.0.0.1'
    'ssh -q -o BatchMode=yes -o ConnectTimeout=5 -p 3333 root@127.0.0.1 exit'
    'ssh-copy-id juca@127.0.0.1'
    'ssh -q -o BatchMode=yes -o ConnectTimeout=5 -p 3333 juca@127.0.0.1 exit'
  )

  output=$(setup_remote_ssh_with_passwordless 'TEST_MODE')
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"
}

function test_prepare_distro_for_deploy()
{
  local output
  local ssh_prefix='ssh -p 3333 juca@127.0.0.1 sudo'
  local cmd="bash $REMOTE_KW_DEPLOY/remote_deploy.sh"
  cmd+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
  cmd+=" --deploy-setup TEST_MODE"

  declare -a expected_cmd=(
    '-> Basic distro set up'
    '' # Extra space for the \n in the message
    "$ssh_prefix \"$cmd\""
  )

  # Remote
  output=$(prepare_distro_for_deploy 3 'TEST_MODE')
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # Local - We need to force a specific distro
  expected_cmd=()
  alias detect_distro='detect_distro_mock'
  output=$(prepare_distro_for_deploy 2 'TEST_MODE')
  expected_cmd=(
    '-> Basic distro set up'
    '' # Extra space for the \n
    'yes | pacman -Syu rsync screen'
  )

  compare_command_sequence 'expected_cmd' "$output" "$LINENO"
}

function test_update_status_log()
{
  local output
  local ssh_prefix='ssh -p 3333 juca@127.0.0.1 sudo'
  local log_date
  local cmd
  local expected_data

  # Remote
  alias date='date_mock'
  log_date=$(date)
  cmd="\"printf '%s;%s\n' '3' '$log_date' >> $REMOTE_KW_DEPLOY/status\""
  output=$(update_status_log 3 'TEST_MODE')

  assert_equals_helper 'Status file remote' "$LINENO" "$ssh_prefix $cmd" "$output"

  # Local/VM
  REMOTE_KW_DEPLOY="$SHUNIT_TMPDIR"
  update_status_log 1
  output=$(cat "$SHUNIT_TMPDIR/status")
  expected_data='1;12/31/2021-09:49:21'

  assert_equals_helper 'Status file data' "$LINENO" "$expected_data" "$output"
}

function test_check_setup_status()
{
  local output
  local expected_cmd
  local cmd_check="test -f $REMOTE_KW_DEPLOY/status"
  local ssh_prefix='ssh -p 3333 juca@127.0.0.1 sudo'

  # Remote
  output=$(check_setup_status 3 'TEST_MODE')
  expected_cmd="$ssh_prefix \"$cmd_check\""
  assert_equals_helper 'Status remote check' "$LINENO" "$expected_cmd" "$output"

  # Local
  REMOTE_KW_DEPLOY="$SHUNIT_TMPDIR"
  rm "$REMOTE_KW_DEPLOY/status"

  # 1. Fail case
  check_setup_status 1
  assertEquals "($LINENO)" 2 "$?"

  # 2. Success case
  touch "$REMOTE_KW_DEPLOY/status"
  check_setup_status 1
  assertEquals "($LINENO)" 0 "$?"
}

function test_modules_install_to()
{
  local original="$PWD"

  # Copy test.preset to remote
  local make_install_cmd="make INSTALL_MOD_PATH=$test_path modules_install"

  cd "$test_path" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(modules_install_to "$test_path" "TEST_MODE")

  if [[ "$output" != "$make_install_cmd" ]]; then
    fail "$LINENO - Expected \"$output\" to be \"$make_install_cmd\""
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
  local remote='juca@127.0.0.1'
  local kernel_image_path='arch/arm64/boot/Image'
  local kernel_image_remote_path="$KW_DEPLOY_TMP_FILE/vmlinuz-test"
  local ssh_cmd='ssh -p 3333'
  local rsync_cmd="rsync -e '$ssh_cmd'"
  local rsync_flags="-LrlptD --rsync-path='sudo rsync'"
  local deploy_params="test debian Image 1 arm64 'remote' TEST_MODE"
  local deploy_cmd=''

  deploy_cmd="bash $REMOTE_KW_DEPLOY/remote_deploy.sh"
  deploy_cmd+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
  deploy_cmd+=" --kernel-update $deploy_params"

  # For this test we expected three steps:
  #
  # 1. Copy kernel image (cmd_image_remote)
  # 2. Execute deploy command (cmd_deploy_image)
  #
  # The following commands represets those steps
  local cmd_image_remote="$rsync_cmd $kernel_image_path $remote:$kernel_image_remote_path $rsync_flags"
  local cmd_deploy_image="$ssh_cmd $remote sudo \"$deploy_cmd\""
  local config_warning='Undefined .config file for the target kernel. Consider using kw bd'

  declare -a expected_cmd=(
    "$cmd_image_remote"
    "$config_warning"
    "$cmd_deploy_image"
  )

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']=3333
  remote_parameters['REMOTE_USER']='juca'

  output=$(run_kernel_install 1 'test' 'TEST_MODE' 3) # 3: REMOTE_TARGET

  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # Update values
  # NOTICE: I added one extra space in the below line for match what we
  # expect since I believe it is not worth to change the kernel_install
  # function just for it.
  deploy_params="test debian Image 0 arm64 'remote' TEST_MODE"
  deploy_cmd="bash $REMOTE_KW_DEPLOY/remote_deploy.sh"
  deploy_cmd+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
  deploy_cmd+=" --kernel-update $deploy_params"

  cmd_deploy_image="$ssh_cmd $remote sudo \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_image_remote"
    "$config_warning"
    "$cmd_deploy_image"
  )

  output=$(run_kernel_install 0 'test' 'TEST_MODE' 3 '127.0.0.1:3333')
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # We want to test an corner case described by the absence of mkinitcpio
  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  tearDown
  setUp 'no_mkinitcpio'

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(run_kernel_install 0 'test' 'TEST_MODE' 3 '127.0.0.1:3333')

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  tearDown
}

function test_kernel_archlinux_install()
{
  local name='test'
  local original="$PWD"
  local remote='juca@127.0.0.1'
  local kernel_image_path='arch/arm64/boot/Image'
  local kernel_image_remote_path="$KW_DEPLOY_TMP_FILE/vmlinuz-test"
  local ssh_cmd='ssh -p 3333'
  local rsync_cmd="rsync -e '$ssh_cmd'"
  local rsync_flags="-LrlptD --rsync-path='sudo rsync'"
  local deploy_params="test arch Image 1 arm64 'remote' TEST_MODE"
  local deploy_cmd=''
  local config_warning='Undefined .config file for the target kernel. Consider using kw bd'

  deploy_cmd="bash $REMOTE_KW_DEPLOY/remote_deploy.sh"
  deploy_cmd+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
  deploy_cmd+=" --kernel-update $deploy_params"

  # For this test we expected three steps:
  #
  # 1. Copy kernel image (cmd_image_remote)
  # 2. Execute deploy command (cmd_deploy_image)
  #
  # The following commands represets those steps
  local cmd_image_remote="$rsync_cmd $kernel_image_path $remote:$kernel_image_remote_path $rsync_flags"
  local cmd_deploy_image="$ssh_cmd $remote sudo \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_image_remote"
    "$config_warning"
    "$cmd_deploy_image"
  )

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']=3333
  remote_parameters['REMOTE_USER']='juca'

  alias detect_distro='detect_distro_mock'
  output=$(run_kernel_install 1 'test' 'TEST_MODE' 3) # 3: REMOTE_TARGET

  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  alias detect_distro='which_distro_mock'
  # We want to test an corner case described by the absence of mkinitcpio
  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_install_x86_64()
{
  local original="$PWD"
  local remote='root@localhost'
  local remote_path='/root/kw_deploy'
  local kernel_image_path='arch/x86_64/boot/bzImage'
  local kernel_image_remote_path="$KW_DEPLOY_TMP_FILE/vmlinuz-test"
  local ssh_cmd='ssh -p 22'
  local rsync_cmd="rsync -e '$ssh_cmd'"
  local rsync_flags="-LrlptD --rsync-path='sudo rsync'"
  local deploy_params="test debian bzImage 1 x86_64 'remote' TEST_MODE"
  local deploy_cmd="bash $REMOTE_KW_DEPLOY/remote_deploy.sh --kernel_update $deploy_params"
  local config_warning='Undefined .config file for the target kernel. Consider using kw bd'

  deploy_cmd="bash $REMOTE_KW_DEPLOY/remote_deploy.sh"
  deploy_cmd+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
  deploy_cmd+=" --kernel-update $deploy_params"

  # Test preparation
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
  # 1. Copy kernel image (cmd_image_remote)
  # 2. Execute deploy command (cmd_deploy_image)
  # The following commands represets those steps
  local cmd_image_remote="$rsync_cmd $kernel_image_path $remote:$kernel_image_remote_path $rsync_flags"
  local cmd_deploy_image="$ssh_cmd $remote sudo \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$cmd_image_remote"
    "$config_warning"
    "$cmd_deploy_image"
  )

  output=$(run_kernel_install 1 'test' 'TEST_MODE' 3 '127.0.0.1:3333')
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # Test kernel image infer
  configurations['kernel_img_name']=''
  output=$(run_kernel_install 1 'test' 'TEST_MODE' 3 '127.0.0.1:3333' |
    tail -n +1 | head -1)
  expected_msg='kw inferred arch/x86_64/boot/arch/x86_64/boot/bzImage as a kernel image'
  assert_equals_helper "Infer kernel image" "$LINENO" "$expected_msg" "$output"

  # Test failures
  rm -rf arch/x86_64/
  output=$(run_kernel_install 1 'test' 'TEST_MODE' 3 '127.0.0.1:3333' |
    tail -n +1 | head -1)
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
  local remote_path="$KW_DEPLOY_TMP_FILE"
  local ssh_cmd='ssh -p 3333'
  local rsync_cmd="rsync -e '$ssh_cmd'"
  local kernel_install_path='tests/.tmp/kernel_install'
  local to_deploy_path='tests/.tmp/to_deploy'
  local local_remote_path='tests/.tmp/remote'
  local version='5.4.0-rc7-test'
  local rsync_flags="-LrlptD --rsync-path='sudo rsync'"

  # Create remote directory
  local dir_kw_deploy="$ssh_cmd $remote_access sudo \"mkdir -p $remote_path\""
  # Rsync script command
  local rsync_debian="$rsync_cmd $kernel_install_path/debian.sh $remote_access:$remote_path/distro_deploy.sh $rsync_flags"

  local rsync_deploy="$rsync_cmd $kernel_install_path/remote_deploy.sh $remote_access:$remote_path/ $rsync_flags"

  local rsync_utils="$rsync_cmd $kernel_install_path/utils.sh $remote_access:$remote_path/ $rsync_flags"

  # Install modules
  local make_install_cmd="make INSTALL_MOD_PATH=$local_remote_path/ modules_install"

  # Kernel release
  local expected_output="Kernel: $version"

  # Compress modules for sending
  local compress_cmd="tar -C $local_remote_path/lib/modules/ --auto-compress -cf $to_deploy_path/$version.tar $version"

  # Rsync modules
  local rsync_tarball="$rsync_cmd $to_deploy_path/$version.tar $remote_access:$remote_path $rsync_flags"

  # Install module inside remote
  local exec_module_install="$ssh_cmd $remote_access sudo \"bash $REMOTE_KW_DEPLOY/remote_deploy.sh"
  exec_module_install+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
  exec_module_install+=" --modules $version.tar\""

  # For this test we expected three steps:
  #
  # 1. Call prepare_host_dir
  # 2. Call prepare_remote_dir
  # 3. Call modules_install_to
  # 4. Get kernel Release
  # 5. Generate tarball based on kernel release name
  # 6. Send tarball to target
  # 7. Install modules in the target

  declare -a expected_cmd=(
    "$make_install_cmd"    # make install
    "$expected_output"     # Release output
    "$compress_cmd"        # Prepare tarball
    "$rsync_tarball"       # Sending tarball
    "$exec_module_install" # Installing module in the target
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
  local cmd_touch_kernel_log="touch $REMOTE_KW_DEPLOY/INSTALLED_KERNELS"
  local cmd_grep_list="grep -Fxq test $REMOTE_KW_DEPLOY/INSTALLED_KERNELS"
  local cmd_reboot="sudo -E reboot"
  local cmd_register_kernel="sudo tee -a '$REMOTE_KW_DEPLOY/INSTALLED_KERNELS' > /dev/null"
  local config_warning='Undefined .config file for the target kernel. Consider using kw bd'
  local msg=""

  declare -a expected_cmd=(
    "$config_warning"
    "$cmd_cp_kernel_img"
    "$cmd_update_initramfs"
    "$cmd_update_grub"
    "$cmd_touch_kernel_log"
    "$cmd_grep_list"
    #"$cmd_register_kernel"
    "$cmd_reboot"
  )

  # ATTENTION: $FAKE_KERNEL got two levels deep (tests/.tmp); for this reason,
  # we have to update KW_PLUGINS_DIR for this test for making sure that we use a
  # real plugin.
  export KW_PLUGINS_DIR='../../src/plugins'

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  alias collect_deploy_info='collect_deploy_info_mock'
  output=$(run_kernel_install 1 'test' 'TEST_MODE' 2)
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  ## Make sure that we are not running as a root user
  alias id='root_id_mock;true'
  output=$(run_kernel_install 1 'test' 'TEST_MODE' 2)
  ret="$?"
  assertEquals "($LINENO)" 1 "$ret"

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
  # Rsync script command
  local remote_list_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"bash $REMOTE_KW_DEPLOY/remote_deploy.sh"

  remote_list_cmd+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
  remote_list_cmd+=" --list-kernels TEST_MODE 0 \""

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  setupRemote

  output=$(run_list_installed_kernels 'TEST_MODE' 0 3)

  assert_equals_helper 'Standard list' "$LINENO" "$remote_list_cmd" "$output"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_uninstall()
{
  local original="$PWD"
  local remote_access='juca@127.0.0.1'
  local remote_path="$REMOTE_KW_DEPLOY"
  local kernel_list='5.5.0-rc7,5.6.0-rc8,5.7.0-rc2'
  local single_kernel='5.7.0-rc2'

  # Rsync script command
  local cmd="bash $remote_path/remote_deploy.sh"
  cmd+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
  cmd+=" --uninstall-kernels '0' 'remote' '$kernel_list' 'TEST_MODE' ''"
  local run_kernel_uninstall_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"$cmd\""

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  setupRemote

  # List of kernels
  options_values['REMOTE_IP']='127.0.0.1'
  options_values['REMOTE_PORT']=3333
  output=$(run_kernel_uninstall 3 0 "$kernel_list" 'TEST_MODE')
  assert_equals_helper 'Standard uninstall' "$LINENO" "$run_kernel_uninstall_cmd" "$output"
  # Reboot
  output=$(run_kernel_uninstall 3 1 "$kernel_list" 'TEST_MODE')
  cmd="bash $remote_path/remote_deploy.sh"
  cmd+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
  cmd+=" --uninstall-kernels '1' 'remote' '$kernel_list' 'TEST_MODE' ''"

  run_kernel_uninstall_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"$cmd\""
  assert_equals_helper 'Reboot option' "$LINENO" "$run_kernel_uninstall_cmd" "$output"

  # Single kernel
  output=$(run_kernel_uninstall 3 1 "$single_kernel" 'TEST_MODE')

  cmd="bash $remote_path/remote_deploy.sh"
  cmd+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"
  cmd+=" --uninstall-kernels '1' 'remote' '$single_kernel' 'TEST_MODE' ''"
  run_kernel_uninstall_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"$cmd\""
  assert_equals_helper 'Reboot option' "$LINENO" "$run_kernel_uninstall_cmd" "$output"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_cleanup()
{
  local output=''
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
  output=$(cleanup 'TEST_MODE')
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"
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
  assertEquals "($LINENO)" '' "${options_values['UNINSTALL_FORCE']}"
  assertEquals "($LINENO)" '0' "${options_values['LS']}"
  assertEquals "($LINENO)" '0' "${options_values['REBOOT']}"
  assertEquals "($LINENO)" '0' "${options_values['MODULES']}"
  assertEquals "($LINENO)" '0' "${options_values['LS_LINE']}"
  assertEquals "($LINENO)" '' "${options_values['LS_ALL']}"
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
  parse_deploy_options --list-all
  assertEquals "($LINENO)" '1' "${options_values['LS_ALL']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -a
  assertEquals "($LINENO)" '1' "${options_values['LS_ALL']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --uninstall 'kernel_xpto'
  assertEquals "($LINENO)" 'kernel_xpto' "${options_values['UNINSTALL']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -u 'kernel_xpto'
  assertEquals "($LINENO)" 'kernel_xpto' "${options_values['UNINSTALL']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --uninstall 'kernel_xpto' --force
  assertEquals "($LINENO)" '1' "${options_values['UNINSTALL_FORCE']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -u 'kernel_xpto' -f
  assertEquals "($LINENO)" '1' "${options_values['UNINSTALL_FORCE']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --uninstall 'kernel_xpto' --force
  assertEquals "($LINENO)" '1' "${options_values['UNINSTALL_FORCE']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options 'TEST_MODE'
  assertEquals "($LINENO)" 'TEST_MODE' "${options_values['TEST_MODE']}"

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

function test_prepare_host_deploy_dir()
{
  local output
  local ret

  # Check if we correctly create new directories
  prepare_host_deploy_dir
  assertTrue "($LINENO): Cache dir not created" '[[ -d $KW_CACHE_DIR ]]'
  assertTrue "($LINENO): Local dir not created" '[[ -d $KW_CACHE_DIR/$LOCAL_REMOTE_DIR ]]'
  assertTrue "($LINENO): Check if kw dir was created" '[[ -d $KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR ]]'
}

function test_prepare_remote_dir()
{
  local remote='172.16.224.1'
  local user='root'
  local port='2222'
  local flag='TEST_MODE'
  local to_copy="{remote_deploy.sh,utils.sh,debian.sh,bootloader_utils.sh,grub.sh}"
  local rsync_flags="-LrlptD --rsync-path='sudo rsync'"
  local scripts_path="$KW_PLUGINS_DIR/kernel_install"
  local target_address="$user@$remote"
  local sync_files_cmd
  local ssh_prefix="ssh -p $port $target_address sudo"

  sync_files_cmd="rsync -e 'ssh -p 2222' $scripts_path/$to_copy $target_address:$REMOTE_KW_DEPLOY $rsync_flags --archive"

  declare -a expected_cmd=(
    "$sync_files_cmd"
    "ssh -p $port $user@$remote sudo \"mkdir -p $KW_DEPLOY_TMP_FILE\""
  )

  output=$(prepare_remote_dir "$remote" "$port" "$user" '' "$flag")
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # First deploy
  expected_cmd=()
  output=$(prepare_remote_dir "$remote" "$port" "$user" 1 "$flag")

  declare -a expected_cmd=(
    "$ssh_prefix \"mkdir -p $REMOTE_KW_DEPLOY\""
    "scp -q $scripts_path/$to_copy $user@$remote:$REMOTE_KW_DEPLOY"
    "$ssh_prefix \"mkdir -p $KW_DEPLOY_TMP_FILE\""
  )

  compare_command_sequence 'expected_cmd' "$output" "$LINENO"
}

invoke_shunit
