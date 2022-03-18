#!/bin/bash

include './src/deploy.sh'
include './tests/utils.sh'

function setUp()
{
  local create_mkinitcpio="$1"

  FAKE_KERNEL="$SHUNIT_TMPDIR"

  # This creates a fake folder which should mock a kernel tree root. A .git
  # dir is also created inside tests/.tmp so that get_maintainer.pl thinks
  # it is a git repo. This is done in order to avoid some warnings that
  # get_maintainer.pl prints when no .git is found.
  mk_fake_kernel_root "$FAKE_KERNEL"

  # Override some global variable
  export test_path="$FAKE_KERNEL"
  export KW_CACHE_DIR="$SHUNIT_TMPDIR/.cache"
  export KW_ETC_DIR="$PWD/$SAMPLES_DIR/etc"
  export DEPLOY_SCRIPT="$test_path/$kernel_install_path/deploy.sh"
  export KW_PLUGINS_DIR="$PWD/src/plugins"
  export REMOTE_KW_DEPLOY='/opt/kw'

  KW_LIB_DIR="$PWD/$SAMPLES_DIR"

  # Create fake .cache
  mkdir -p "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR/lib/modules"
  mkdir -p "$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/"

  # Define some basic values for configurations
  parse_configuration "$KW_CONFIG_SAMPLE"

  # Usually, we call populate_remote_info to fill out remote info. However, to
  # keep the test more reliable, we manually set this values here
  remote_parameters['REMOTE_IP']=${configurations[ssh_ip]}
  remote_parameters['REMOTE_PORT']=${configurations[ssh_port]}
  remote_parameters['REMOTE_USER']=${configurations[ssh_user]}

  # Mock functions
  shopt -s expand_aliases
  alias which_distro='which_distro_mock'
  alias detect_distro='which_distro_mock'
  alias get_kernel_release='get_kernel_release_mock'
  alias get_kernel_version='get_kernel_version_mock'
  alias sudo='sudo_mock'
  alias date='date_mock'
  alias generate_tarball='generate_tarball_mock'
  alias vm_umount='vm_umount_mock'

  # Standard configuration makes the below standard commands
  CONFIG_REMOTE='juca@127.0.0.1'
  CONFIG_SSH='ssh -p 3333'
  CONFIG_RSYNC="rsync --info=progress2 -e '$CONFIG_SSH'"
  STD_RSYNC_FLAG="-LrlptD --rsync-path='sudo rsync'"

  DEPLOY_REMOTE_PREFIX="bash $REMOTE_KW_DEPLOY/remote_deploy.sh"
  DEPLOY_REMOTE_PREFIX+=" --kw-path '$REMOTE_KW_DEPLOY' --kw-tmp-files '$KW_DEPLOY_TMP_FILE'"

  # Default deploy messages
  SENDING_KERNEL_MSG='* Sending kernel image and config file to the remote'
  PREPARING_MODULES_MSG='* Preparing modules'
  UPDATE_KW_REMOTE_MSG='* Sending kw to the remote'
}

function tearDown()
{
  configurations=()

  rm -rf "$FAKE_KERNEL"
}

# Some of the functions invoked by kw need to be mocked; otherwise, we cannot
# test all the elements in the function. The following functions try to mimic
# some of these functions behaviour.
function which_distro_mock()
{
  printf '%s\n' 'debian'
}

function which_distro_none_mock()
{
  printf '%s\n' 'none'
}

function detect_distro_arch_mock()
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

function collect_deploy_info_other_mock()
{
  printf '[bootloader]=LILO [distro]=fedora'
}

function sudo_mock()
{
  printf '%s\n' "$*"
}

function find_kernels_mock()
{
  printf 'vmlinuz-1\n'
  printf 'vmlinuz-2\n'
  printf 'vmlinuz-3\n'
  printf 'vmlinuz-4\n'
  printf 'vmlinuz-5\n'
}

# Function that we must replace
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
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
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
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Local - We need to force a specific distro
  expected_cmd=()

  # Let's change the detect ditro to point to Arch
  alias detect_distro='detect_distro_arch_mock'
  output=$(prepare_distro_for_deploy 2 'TEST_MODE')
  expected_cmd=(
    '-> Basic distro set up'
    '' # Extra space for the \n
    'yes | pacman -Syu rsync screen pv bzip2 lzip lzop zstd xz'
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_update_status_log()
{
  local output
  local ssh_prefix='ssh -p 3333 juca@127.0.0.1 sudo'
  local log_date
  local cmd
  local expected_data

  # Remote
  log_date=$(date)
  cmd="\"printf '%s;%s\n' '3' '$log_date' >> $REMOTE_KW_DEPLOY/status\""
  output=$(update_status_log 3 'TEST_MODE')

  assert_equals_helper 'Status file remote' "$LINENO" "$ssh_prefix $cmd" "$output"

  # Local
  REMOTE_KW_DEPLOY="$SHUNIT_TMPDIR"
  update_status_log 2
  output=$(cat "$SHUNIT_TMPDIR/status")
  expected_data='2;12/31/2021-09:49:21'

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

  # 1. Fail case
  check_setup_status 1
  assert_equals_helper 'Wrong return value' "($LINENO)" 2 "$?"

  # 2. Success case
  touch "$REMOTE_KW_DEPLOY/status"
  check_setup_status 1
  assert_equals_helper 'Wrong return value' "($LINENO)" 0 "$?"
}

function test_modules_install_to()
{
  local output
  local make_cmd="make INSTALL_MOD_PATH=$test_path modules_install"

  declare -a expected_cmd=(
    '* Preparing modules'
    "$make_cmd"
  )

  output=$(modules_install_to "$test_path" 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_kernel_install_to_remote()
{
  local name='test'
  local original="$PWD"
  local kernel_image_path='arch/arm64/boot/Image'
  local kernel_image_remote_path="$KW_DEPLOY_TMP_FILE/vmlinuz-test"
  local deploy_params="test debian Image 1 arm64 'remote' TEST_MODE"
  local deploy_cmd="$DEPLOY_REMOTE_PREFIX"
  local send_kernel_from_host2remote
  local execute_deploy_remote
  local config_warning
  local expected_cmd
  local output
  local deploy_message='* Sending kernel image and config file to the remote'

  # Composing expected commands
  deploy_cmd+=" --kernel-update $deploy_params"

  send_kernel_from_host2remote="$CONFIG_RSYNC $kernel_image_path "
  send_kernel_from_host2remote+="$CONFIG_REMOTE:$kernel_image_remote_path $STD_RSYNC_FLAG"

  execute_deploy_remote="$CONFIG_SSH $CONFIG_REMOTE sudo \"$deploy_cmd\""
  config_warning='Undefined .config file for the target kernel. Consider using kw bd'

  declare -a expected_cmd=(
    "$SENDING_KERNEL_MSG"
    "$send_kernel_from_host2remote"
    "$config_warning"
    "$execute_deploy_remote"
  )

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # Test 1: Local deploy: reboot
  output=$(run_kernel_install 1 'test' 'TEST_MODE' 3) # 3: REMOTE_TARGET
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Update values
  # NOTICE: I added one extra space in the below line for match what we
  # expect since I believe it is not worth to change the kernel_install
  # function just for it.

  # Test 2: No reboot
  deploy_params="test debian Image 0 arm64 'remote' TEST_MODE"
  deploy_cmd="$DEPLOY_REMOTE_PREFIX"
  deploy_cmd+=" --kernel-update $deploy_params"

  execute_deploy_remote="$CONFIG_SSH $CONFIG_REMOTE sudo \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$SENDING_KERNEL_MSG"
    "$send_kernel_from_host2remote"
    "$config_warning"
    "$execute_deploy_remote"
  )

  output=$(run_kernel_install 0 'test' 'TEST_MODE' 3 '127.0.0.1:3333')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_archlinux_install_to_remote()
{
  local name='test'
  local original="$PWD"
  local kernel_image_path='arch/arm64/boot/Image'
  local kernel_image_remote_path="$KW_DEPLOY_TMP_FILE/vmlinuz-test"
  local deploy_params="test arch Image 1 arm64 'remote' TEST_MODE"
  local deploy_cmd="$DEPLOY_REMOTE_PREFIX"
  local send_kernel_from_host2remote
  local execute_deploy_remote
  local config_warning='Undefined .config file for the target kernel. Consider using kw bd'
  local output

  # Composing expected commands
  deploy_cmd+=" --kernel-update $deploy_params"

  # Setup this test for ArchLinux as a target
  # We need to force ArchLinux in the distro detection
  alias detect_distro='detect_distro_arch_mock'

  send_kernel_from_host2remote="$CONFIG_RSYNC $kernel_image_path "
  send_kernel_from_host2remote+="$CONFIG_REMOTE:$kernel_image_remote_path $STD_RSYNC_FLAG"
  execute_deploy_remote="$CONFIG_SSH $CONFIG_REMOTE sudo \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$SENDING_KERNEL_MSG"
    "$send_kernel_from_host2remote"
    "$config_warning"
    "$execute_deploy_remote"
  )

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(run_kernel_install 1 'test' 'TEST_MODE' 3) # 3: REMOTE_TARGET
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_install_x86_64_to_remote()
{
  local original="$PWD"
  local remote='root@localhost'
  local remote_path='/root/kw_deploy'
  local kernel_image_path='arch/x86_64/boot/bzImage'
  local kernel_image_remote_path="$KW_DEPLOY_TMP_FILE/vmlinuz-test"
  local deploy_params="test debian bzImage 1 x86_64 'remote' TEST_MODE"
  local deploy_cmd="$DEPLOY_REMOTE_PREFIX"
  local ssh_cmd='ssh -p 22'
  local rsync_cmd="rsync --info=progress2 -e '$ssh_cmd'"
  local config_warning='Undefined .config file for the target kernel. Consider using kw bd'
  local send_kernel_from_host2remote
  local execute_deploy_remote
  local output

  # Composing expected commands
  deploy_cmd+=" --kernel-update $deploy_params"

  # Test preparation
  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  # Reset values
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

  send_kernel_from_host2remote="$rsync_cmd $kernel_image_path "
  send_kernel_from_host2remote+="$remote:$kernel_image_remote_path $STD_RSYNC_FLAG"
  execute_deploy_remote="$ssh_cmd $remote sudo \"$deploy_cmd\""

  declare -a expected_cmd=(
    "$SENDING_KERNEL_MSG"
    "$send_kernel_from_host2remote"
    "$config_warning"
    "$execute_deploy_remote"
  )

  output=$(run_kernel_install 1 'test' 'TEST_MODE' 3 '127.0.0.1:3333')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

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
  assertEquals "($LINENO)" "$output" "$expected_msg"
  assert_equals_helper "Could not find a valid image" "$LINENO" "$expected_msg" "$output"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_install_local()
{
  local original="$PWD"
  # We force Debian files in the setup; for this reason, we are using the
  # commands used to deploy a new kernel image on debian.
  local cmd_cp_kernel_img="sudo -E cp  arch/arm64/boot/Image /boot/vmlinuz-test"
  local cmd_update_initramfs="sudo -E update-initramfs -c -k test"
  local cmd_update_grub="sudo -E grub-mkconfig -o /boot/grub/grub.cfg"
  #cmd_update_grub+=' |& pv -p --line-mode --size 17 > /dev/null'
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

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  alias collect_deploy_info='collect_deploy_info_mock'
  # This mock refers to the function run_bootloader_update
  alias find='find_kernels_mock'
  output=$(run_kernel_install 1 'test' 'TEST_MODE' 2)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Test 2: Copy config file
  cp "$SAMPLES_DIR/.config" ./ # Config file with "test" as a kernel name
  declare -a expected_cmd=(
    "sudo -E cp $PWD/.config /boot/config-test"
    "$cmd_cp_kernel_img"
    "$cmd_update_initramfs"
    "$cmd_update_grub"
    "$cmd_touch_kernel_log"
    "$cmd_grep_list"
    "$cmd_reboot"
  )

  output=$(run_kernel_install 1 'test' 'TEST_MODE' 2)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  ## Make sure that we are not running as a root user
  alias id='root_id_mock;true'
  output=$(run_kernel_install 1 'test' 'TEST_MODE' 2)
  ret="$?"
  assert_equals_helper 'Wrong return value' "($LINENO)" 1 "$ret"

  # Test 3: Unknown distro
  alias detect_distro='which_distro_none_mock'
  output=$(run_kernel_install 1 'test' 'TEST_MODE' 2)
  assert_equals_helper 'Wrong return value' "($LINENO)" 95 "$?"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_install_to_vm()
{
  local name='test'
  local original="$PWD"
  local kernel_image_path='arch/arm64/boot/Image'
  local kernel_image_remote_path="$KW_DEPLOY_TMP_FILE/vmlinuz-test"
  local deploy_params="test debian Image 1 arm64 'remote' TEST_MODE"
  local deploy_cmd="$DEPLOY_REMOTE_PREFIX"
  local send_kernel_from_host2remote
  local execute_deploy_remote
  local config_warning
  local expected_cmd
  local output

  # Note: We do not thoroughly test this feature here because, for the vm
  # installation, we include the utils file in execution time. In this sense,
  # the included test must be kept in the utils file and not here; for this
  # reason, we just check the first part of this function.

  # Composing expected commands
  config_warning='Undefined .config file for the target kernel. Consider using kw bd'

  declare -a expected_cmd=(
    "$config_warning"
    'Did you check if your VM is mounted?'
  )

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # Test 1: No config file
  output=$(run_kernel_install 0 'test' 'TEST_MODE' 1)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Test 2: Create a config file that matches the kernel build
  cp "$SAMPLES_DIR/.config" ./ # Config file with "test" as a kernel name
  configurations[mount_point]="$PWD/la"
  declare -a expected_cmd=(
    "cp $PWD/.config ${configurations[mount_point]}/boot/config-$name"
    'Did you check if your VM is mounted?'
  )

  output=$(run_kernel_install 0 "$name" 'TEST_MODE' 1)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Test 3: Invalid distro
  alias detect_distro='which_distro_none_mock'

  output=$(run_kernel_install 0 "$name" 'TEST_MODE' 1)
  assert_equals_helper 'Wrong return value' "($LINENO)" 95 "$?"

  cd "$original" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_kernel_modules()
{
  local count=0
  local remote_path="$KW_DEPLOY_TMP_FILE"
  local kernel_install_path="$SHUNIT_TMPDIR/kernel_install"
  local to_deploy_path="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR"
  local local_remote_path="$KW_CACHE_DIR/$LOCAL_REMOTE_DIR"
  local version='5.4.0-rc7-test'
  local deploy_remote_cmd="$DEPLOY_REMOTE_PREFIX"
  local output
  local dir_kw_deploy
  local rsync_debian
  local rsync_utils
  local make_install_cmd
  local compress_cmd
  local rsync_tarball
  local exec_module_install

  # Create remote directory
  dir_kw_deploy="$CONFIG_SSH $CONFIG_REMOTE sudo \"mkdir -p $remote_path\""
  # Rsync script command
  rsync_debian="$CONFIG_RSYNC $kernel_install_path/debian.sh $CONFIG_REMOTE:$remote_path/distro_deploy.sh $STD_RSYNC_FLAG"

  rsync_deploy="$CONFIG_RSYNC $kernel_install_path/remote_deploy.sh $CONFIG_REMOTE:$remote_path/ $STD_RSYNC_FLAG"

  rsync_utils="$CONFIG_RSYNC $kernel_install_path/utils.sh $CONFIG_REMOTE:$remote_path/ $STD_RSYNC_FLAG"

  # Install modules
  make_install_cmd="make INSTALL_MOD_PATH=$local_remote_path/ modules_install"

  # Compress modules for sending
  compress_cmd="tar --auto-compress --directory='$local_remote_path/lib/modules/' --create --file='$to_deploy_path/$version.tar' $version"

  # Rsync modules
  rsync_tarball="$CONFIG_RSYNC $to_deploy_path/$version.tar $CONFIG_REMOTE:$remote_path $STD_RSYNC_FLAG"

  # Install module inside remote
  deploy_remote_cmd+=" --modules $version.tar"

  exec_module_install="$CONFIG_SSH $CONFIG_REMOTE sudo \"$deploy_remote_cmd\""

  # Test 1: Check modules deploy for a remote

  declare -a expected_cmd=(
    "$PREPARING_MODULES_MSG"
    "$make_install_cmd" # make install
    "$compress_cmd"     # Prepare tarball
    "* Sending kernel modules ($version) to the remote"
    "$rsync_tarball"       # Sending tarball
    "$exec_module_install" # Installing module in the target
  )

  # Create folder so generate_tarball won't complain
  mkdir -p "$local_remote_path/lib/modules/$version"

  output=$(modules_install 'TEST_MODE' 3)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Test 2: Deploy modules to local
  output=$(modules_install 'TEST_MODE' 1)
  declare -a expected_cmd=(
    "$PREPARING_MODULES_MSG"
    'make INSTALL_MOD_PATH=/home/lala modules_install'
  )
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Test 3: Deploy modules locally vm
  output=$(modules_install 'TEST_MODE' 2)
  declare -a expected_cmd=(
    "$PREPARING_MODULES_MSG"
    'sudo -E make modules_install'
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

# This test validates the correct behavior of list kernel on a remote machine
# by checking the expected command sequence; It is important to highlight that
# we are not testing the actual kernel list code, this part is validated on
# another test file.
function test_list_remote_kernels()
{
  # Rsync script command
  local remote_list_cmd="$CONFIG_SSH $CONFIG_REMOTE sudo"
  local output
  local deploy_remote_cmd="$DEPLOY_REMOTE_PREFIX"

  # Composing command
  deploy_remote_cmd+=" --list-kernels TEST_MODE 0 "
  remote_list_cmd+=" \"$deploy_remote_cmd\""

  output=$(run_list_installed_kernels 'TEST_MODE' 0 3)

  assert_equals_helper 'Standard list' "$LINENO" "$remote_list_cmd" "$output"
}

function test_kernel_uninstall()
{
  local remote_path="$REMOTE_KW_DEPLOY"
  local kernel_list='5.5.0-rc7,5.6.0-rc8,5.7.0-rc2'
  local single_kernel='5.7.0-rc2'
  local deploy_remote_cmd="$DEPLOY_REMOTE_PREFIX"
  local run_kernel_uninstall_cmd="$CONFIG_SSH $CONFIG_REMOTE"

  # Rsync script command
  deploy_remote_cmd+=" --uninstall-kernels '0' 'remote' '$kernel_list' 'TEST_MODE' ''"

  run_kernel_uninstall_cmd+=" sudo \"$deploy_remote_cmd\""

  # List of kernels
  output=$(run_kernel_uninstall 3 0 "$kernel_list" 'TEST_MODE')
  assert_equals_helper 'Standard uninstall' "$LINENO" "$run_kernel_uninstall_cmd" "$output"

  # Reboot
  output=$(run_kernel_uninstall 3 1 "$kernel_list" 'TEST_MODE')
  deploy_remote_cmd="$DEPLOY_REMOTE_PREFIX"
  deploy_remote_cmd+=" --uninstall-kernels '1' 'remote' '$kernel_list' 'TEST_MODE' ''"

  run_kernel_uninstall_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"$deploy_remote_cmd\""
  assert_equals_helper 'Reboot option' "$LINENO" "$run_kernel_uninstall_cmd" "$output"

  # Single kernel
  output=$(run_kernel_uninstall 3 1 "$single_kernel" 'TEST_MODE')

  deploy_remote_cmd="$DEPLOY_REMOTE_PREFIX"
  deploy_remote_cmd+=" --uninstall-kernels '1' 'remote' '$single_kernel' 'TEST_MODE' ''"
  run_kernel_uninstall_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"$deploy_remote_cmd\""
  assert_equals_helper 'Reboot option' "$LINENO" "$run_kernel_uninstall_cmd" "$output"
}

function test_cleanup()
{
  local output=''
  local cmd_remote="rm -rf $KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/*"
  local cmd_to_deploy="rm -rf $KW_CACHE_DIR/$LOCAL_REMOTE_DIR/*"

  declare -a expected_cmd=(
    'Cleaning up temporary files...'
    "$cmd_to_deploy"
    "$cmd_remote"
    'Exiting...'
  )

  #shellcheck disable=SC2153
  options_values[REMOTE]=1
  output=$(cleanup 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
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
  assert_equals_helper 'Default UNINSTALL did not match expectation' "($LINENO)" '' "${options_values['UNINSTALL']}"
  assert_equals_helper 'Default UNINSTALL_FORCE did not match expectation' "($LINENO)" '' "${options_values['UNINSTALL_FORCE']}"
  assert_equals_helper 'Default LS did not match expectation' "($LINENO)" '0' "${options_values['LS']}"
  assert_equals_helper 'Default REBOOT did not match expectation' "($LINENO)" '0' "${options_values['REBOOT']}"
  assert_equals_helper 'Default MODULES did not match expectation' "($LINENO)" '0' "${options_values['MODULES']}"
  assert_equals_helper 'Default LS_LINE did not match expectation' "($LINENO)" '0' "${options_values['LS_LINE']}"
  assert_equals_helper 'Default LS_ALL did not match expectation' "($LINENO)" '' "${options_values['LS_ALL']}"
  assert_equals_helper 'Default MENU_CONFIG did not match expectation' "($LINENO)" 'nconfig' "${options_values['MENU_CONFIG']}"
  assert_equals_helper 'Default TARGET did not match expectation' "($LINENO)" '1' "${options_values['TARGET']}"

  # test individual options
  unset options_values
  declare -gA options_values
  parse_deploy_options --remote 'user@127.0.2.1:8888'
  assert_equals_helper 'Could not set deploy REMOTE_USER' "($LINENO)" 'user' "${remote_parameters['REMOTE_USER']}"
  assert_equals_helper 'Could not set deploy REMOTE' "($LINENO)" '127.0.2.1:8888' "${remote_parameters['REMOTE']}"
  assert_equals_helper 'Could not set deploy REMOTE_PORT' "($LINENO)" '8888' "${remote_parameters['REMOTE_PORT']}"
  assert_equals_helper 'Could not set deploy REMOTE_IP' "($LINENO)" '127.0.2.1' "${remote_parameters['REMOTE_IP']}"

  unset options_values
  declare -gA options_values
  expected="kw deploy: option '--remote' requires an argument"
  parse_deploy_options --remote
  assert_equals_helper 'Wrong return value' "($LINENO)" '22' "$?"
  assertEquals "($LINENO)" "$expected" "${options_values['ERROR']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --remote ':8888' > /dev/null
  assert_equals_helper 'Wrong return value' "($LINENO)" '22' "$?"
  assertEquals "($LINENO)" 'Invalid remote: :8888' "${options_values['ERROR']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --local
  assert_equals_helper 'Could not set deploy TARGET' "($LINENO)" '2' "${options_values['TARGET']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --vm
  assert_equals_helper 'Could not set deploy TARGET' "($LINENO)" '1' "${options_values['TARGET']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --reboot
  assert_equals_helper 'Could not set deploy REBOOT' "($LINENO)" '1' "${options_values['REBOOT']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -r
  assert_equals_helper 'Could not set deploy REBOOT' "($LINENO)" '1' "${options_values['REBOOT']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --modules
  assert_equals_helper 'Could not set deploy MODULES' "($LINENO)" '1' "${options_values['MODULES']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -m
  assert_equals_helper 'Could not set deploy MODULES' "($LINENO)" '1' "${options_values['MODULES']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --list
  assert_equals_helper 'Could not set deploy LS' "($LINENO)" '1' "${options_values['LS']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -l
  assert_equals_helper 'Could not set deploy LS' "($LINENO)" '1' "${options_values['LS']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --ls-line
  assert_equals_helper 'Could not set deploy LS_LINE' "($LINENO)" '1' "${options_values['LS_LINE']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -s
  assert_equals_helper 'Could not set deploy LS_LINE' "($LINENO)" '1' "${options_values['LS_LINE']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --list-all
  assert_equals_helper 'Could not set deploy LS_ALL' "($LINENO)" '1' "${options_values['LS_ALL']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -a
  assert_equals_helper 'Could not set deploy LS_ALL' "($LINENO)" '1' "${options_values['LS_ALL']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --uninstall 'kernel_xpto'
  assert_equals_helper 'Could not set deploy UNINSTALL' "($LINENO)" 'kernel_xpto' "${options_values['UNINSTALL']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -u 'kernel_xpto'
  assert_equals_helper 'Could not set deploy UNINSTALL' "($LINENO)" 'kernel_xpto' "${options_values['UNINSTALL']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --uninstall 'kernel_xpto' --force
  assert_equals_helper 'Could not set deploy UNINSTALL_FORCE' "($LINENO)" '1' "${options_values['UNINSTALL_FORCE']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options -u 'kernel_xpto' -f
  assert_equals_helper 'Could not set deploy UNINSTALL_FORCE' "($LINENO)" '1' "${options_values['UNINSTALL_FORCE']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options --uninstall 'kernel_xpto' --force
  assert_equals_helper 'Could not set deploy UNINSTALL_FORCE' "($LINENO)" '1' "${options_values['UNINSTALL_FORCE']}"

  unset options_values
  declare -gA options_values
  parse_deploy_options 'TEST_MODE'
  assert_equals_helper 'Could not set deploy TEST_MODE' "($LINENO)" 'TEST_MODE' "${options_values['TEST_MODE']}"

  # test integration of options
  unset options_values
  declare -gA options_values
  parse_deploy_options --remote 'user@127.0.2.1:8888' -m --ls-line -u 'kernel_xpto'
  assert_equals_helper 'Option composition failed on UNINSTALL' "($LINENO)" 'kernel_xpto' "${options_values['UNINSTALL']}"
  assert_equals_helper 'Option composition failed on MODULES' "($LINENO)" '1' "${options_values['MODULES']}"
  assert_equals_helper 'Option composition failed on LS_LINE' "($LINENO)" '1' "${options_values['LS_LINE']}"
  assert_equals_helper 'Option composition failed on REMOTE_USER' "($LINENO)" 'user' "${remote_parameters['REMOTE_USER']}"
  assert_equals_helper 'Option composition failed on REMOTE' "($LINENO)" '127.0.2.1:8888' "${remote_parameters['REMOTE']}"
  assert_equals_helper 'Option composition failed on REMOTE_PORT' "($LINENO)" '8888' "${remote_parameters['REMOTE_PORT']}"
  assert_equals_helper 'Option composition failed on REMOTE_IP' "($LINENO)" '127.0.2.1' "${remote_parameters['REMOTE_IP']}"
}

function test_prepare_host_deploy_dir()
{
  local output
  local ret

  # Let's make sure that we don't have any old files
  rm -rf "$SHUNIT_TMPDIR"

  # Check if we correctly create new directories
  prepare_host_deploy_dir
  assertTrue "($LINENO): Cache dir not created" '[[ -d $KW_CACHE_DIR ]]'
  assertTrue "($LINENO): Local dir not created" '[[ -d $KW_CACHE_DIR/$LOCAL_REMOTE_DIR ]]'
  assertTrue "($LINENO): Check if kw dir was created" '[[ -d $KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR ]]'
}

function prepare_remote_list_of_files()
{
  local distro="$1"

  printf '{remote_deploy.sh,utils.sh,%s.sh,bootloader_utils.sh,grub.sh}' "$distro"
}

function test_prepare_remote_dir()
{
  local scripts_path="$KW_PLUGINS_DIR/kernel_install"
  local debian_sync_files_cmd
  local arch_sync_files_cmd
  local output
  local rsync_quiet="rsync  -e '$CONFIG_SSH'"

  to_copy=$(prepare_remote_list_of_files 'debian')
  debian_sync_files_cmd="$rsync_quiet $scripts_path/$to_copy $CONFIG_REMOTE:$REMOTE_KW_DEPLOY $STD_RSYNC_FLAG --archive"

  # Test 1: Normal remote prepare
  declare -a expected_cmd=(
    "$debian_sync_files_cmd"
    "$CONFIG_SSH $CONFIG_REMOTE sudo \"mkdir -p $KW_DEPLOY_TMP_FILE\""
  )

  output=$(prepare_remote_dir '' '' '' '' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Test 2: Force ArchLinux
  expected_cmd=()
  to_copy=$(prepare_remote_list_of_files 'arch')
  arch_sync_files_cmd="$rsync_quiet $scripts_path/$to_copy $CONFIG_REMOTE:$REMOTE_KW_DEPLOY $STD_RSYNC_FLAG --archive"
  declare -a expected_cmd=(
    "$arch_sync_files_cmd"
    "$CONFIG_SSH $CONFIG_REMOTE sudo \"mkdir -p $KW_DEPLOY_TMP_FILE\""
    "$CONFIG_RSYNC $KW_ETC_DIR/template_mkinitcpio.preset $CONFIG_REMOTE:$REMOTE_KW_DEPLOY $STD_RSYNC_FLAG"
  )

  alias detect_distro='detect_distro_arch_mock'
  output=$(prepare_remote_dir '' '' '' '' 'TEST_MODE')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Test 3: First deploy
  alias detect_distro='which_distro_mock'
  to_copy=$(prepare_remote_list_of_files 'debian')
  expected_cmd=()
  output=$(prepare_remote_dir '' '' '' 1 'TEST_MODE')

  declare -a expected_cmd=(
    "$UPDATE_KW_REMOTE_MSG"
    "$CONFIG_SSH $CONFIG_REMOTE sudo \"mkdir -p $REMOTE_KW_DEPLOY\""
    "scp -q $scripts_path/$to_copy $CONFIG_REMOTE:$REMOTE_KW_DEPLOY"
    "$CONFIG_SSH $CONFIG_REMOTE sudo \"mkdir -p $KW_DEPLOY_TMP_FILE\""
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Test 4: Unsupported distro
  alias detect_distro='which_distro_none_mock'

  output=$(prepare_remote_dir '' '' '' '' 'TEST_MODE')
  assert_equals_helper 'Wrong return value' "($LINENO)" 95 "$?"
}

function test_collect_target_info_for_deploy()
{
  local output

  # Corner-cases
  alias detect_distro='which_distro_none_mock'
  output=$(collect_target_info_for_deploy 1 'TEST_MODE')
  assert_equals_helper 'Wrong return value' "($LINENO)" 95 "$?"

  # VM
  alias detect_distro='which_distro_mock'
  collect_target_info_for_deploy 1 'TEST_MODE'
  assert_equals_helper 'Check bootloader' "($LINENO)" "${target_deploy_info[bootloader]}" 'GRUB'
  assert_equals_helper 'Check distro' "($LINENO)" "${target_deploy_info[distro]}" 'arch'

  # LOCAL
  alias collect_deploy_info='collect_deploy_info_other_mock'
  collect_target_info_for_deploy 2 'TEST_MODE'
  assert_equals_helper 'Check bootloader' "($LINENO)" "${target_deploy_info[bootloader]}" 'LILO'
  assert_equals_helper 'Check distro' "($LINENO)" "${target_deploy_info[distro]}" 'fedora'

  # REMOTE
  function cmd_remotely()
  {
    printf '[bootloader]=syslinux [distro]=chrome'
  }
  collect_target_info_for_deploy 3 'TEST_MODE'
  assert_equals_helper 'Check bootloader' "($LINENO)" "${target_deploy_info[bootloader]}" 'syslinux'
  assert_equals_helper 'Check distro' "($LINENO)" "${target_deploy_info[distro]}" 'chrome'
}

invoke_shunit
