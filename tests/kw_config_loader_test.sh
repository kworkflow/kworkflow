#!/bin/bash

include './tests/utils.sh'
include './src/kw_config_loader.sh'

KWORKFLOW='kw'

TMP_DIR=tests/.tmp_kw_config_loader_test

function setUp()
{
  mkdir -p "$TMP_DIR"
  cp "$PWD/etc/kworkflow_template.config" "$TMP_DIR/kworkflow.config"
  configurations=()
}

function tearDown()
{
  rm -rf "$TMP_DIR"
}

function test_parse_configuration_success_exit_code()
{
  parse_configuration tests/samples/kworkflow.config
  assertTrue 'kw failed to load a regular config file' "[ 0 -eq $? ]"
}

function test_parse_configuration_config_with_spaces_and_comments()
{
  parse_configuration 'tests/samples/kworkflow_space_comments.config'
  assertTrue "($LINENO): Kw failed to load a regular config file" "[ 0 -eq $? ]"

  assertEquals "($LINENO)" "${configurations['arch']}" 'arm64'
  assertEquals "($LINENO)" "${configurations['kernel_img_name']}" 'Image'
  assertEquals "($LINENO)" "${configurations['virtualizer']}" 'libvirt'
  assertEquals "($LINENO)" "${configurations['reboot_after_deploy']}" 'no'
}

function test_parser_configuration_failed_exit_code()
{
  parse_configuration tests/foobarpotato
  assertTrue 'kw loaded an unsupported file' "[ 22 -eq $? ]"
}

function assertConfigurations()
{
  declare -n configurations_ref=$1
  declare -n expected_configurations_ref=$2
  local lineno=${3:-LINENO}

  # check if configurations is contained in expected_configurations
  for k in "${!configurations_ref[@]}"; do
    if [[ ${expected_configurations_ref[$k]+token} != token ]]; then
      fail "($lineno): Did not expect setting '$k'."
    elif [[ ${configurations_ref[$k]} != "${expected_configurations_ref[$k]}" ]]; then
      fail "($lineno): Expected setting '${k}' to be '${expected_configurations_ref[$k]}' (found '${configurations_ref[$k]}')."
    fi
  done

  # check if configurations has all expected_configurations keys
  for k in "${!expected_configurations_ref[@]}"; do
    if [[ ${configurations_ref[$k]+token} != token ]]; then
      fail "($lineno): Expected setting '$k' to be present."
    fi
  done
}

# Test if parse_configuration correctly parses all settings in a file
function test_parse_configuration_output()
{
  declare -A expected_configurations=(
    [arch]='arm64'
    [kernel_img_name]='Image'
    [cross_compile]='aarch64-linux-gnu-'
    [virtualizer]='libvirt'
    [qemu_path_image]='/home/xpto/p/virty.qcow2'
    [ssh_user]='juca'
    [ssh_ip]='127.0.0.1'
    [ssh_port]='3333'
    [mount_point]='/home/lala'
    [default_deploy_target]='vm'
    [reboot_after_deploy]='no'
    [gui_on]='turn on'
    [gui_off]='turn off'
    [doc_type]='htmldocs'
    [send_opts]='--annotate --cover-letter --no-chain-reply-to --thread'
    [blocked_emails]='test@email.com'
    [checkpatch_opts]='--no-tree --color=always --strict'
    [get_maintainer_opts]='--separator , --nokeywords --nogit --nogit-fallback --norolestats'
    [kw_files_remote_path]='/opt/kw'
    [deploy_temporary_files_path]='/tmp/kw'
  )

  cp tests/samples/kworkflow.config "$TMP_DIR/"

  pushd "$TMP_DIR" > /dev/null || {
    fail "($LINENO): It was not possible to pushd into temp directory"
    return
  }
  parse_configuration "$PWD/kworkflow.config"
  popd > /dev/null || {
    fail "($LINENO): It was not possible to popd from temp directory"
    return
  }

  assertConfigurations configurations expected_configurations "$LINENO"

  true # Reset return value
}

# Test if etc/kworkflow_template.config contains all the expected settings
function test_parse_configuration_standard_config()
{
  # shellcheck disable=2016
  declare -A expected_configurations=(
    [arch]='x86_64'
    [kernel_img_name]='bzImage'
    [menu_config]='nconfig'
    [virtualizer]='qemu-system-x86_64'
    [qemu_path_image]='/home/USERKW/p/virty.qcow2'
    [qemu_hw_options]='-enable-kvm -daemonize -smp 2 -m 1024'
    [qemu_net_options]='-nic user,hostfwd=tcp::2222-:22,smb=/home/USERKW'
    [ssh_user]='root'
    [ssh_ip]='localhost'
    [ssh_port]='22'
    [mount_point]='/home/USERKW/p/mount'
    [alert]='n'
    [sound_alert_command]='paplay SOUNDPATH/bell.wav'
    [visual_alert_command]='notify-send -i checkbox -t 10000 "kw" "Command: \"$COMMAND\" completed!"'
    [default_deploy_target]='vm'
    [reboot_after_deploy]='no'
    [disable_statistics_data_track]='no'
    [doc_type]='htmldocs'
    [send_opts]='--annotate --cover-letter --no-chain-reply-to --thread'
    [checkpatch_opts]='--no-tree --color=always --strict'
    [get_maintainer_opts]='--separator , --nokeywords --nogit --nogit-fallback --norolestats'
    [kw_files_remote_path]='/opt/kw'
    [deploy_temporary_files_path]='/tmp/kw'
    [deploy_default_compression]='lzop'
  )

  parse_configuration "$TMP_DIR/kworkflow.config"
  assertConfigurations configurations expected_configurations "$LINENO"

  true # Reset return value
}

# To test the order of config file loading, we will put a file named
# kworkflow.config in each place, in order, and remove the previous one.
# The order is: PWD, XDG_CONFIG_HOME, XDG_CONFIG_DIRS, KW_ETC_DIR
function test_parse_configuration_files_loading_order()
{
  local expected
  local original_dir="$PWD"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO): It was not possible to move to temporary directory"
    return
  }

  KW_ETC_DIR='1'
  XDG_CONFIG_DIRS='2:3:4'
  XDG_CONFIG_HOME='5'

  expected=(
    "1/$CONFIG_FILENAME"
    "4/$KWORKFLOW/$CONFIG_FILENAME"
    "3/$KWORKFLOW/$CONFIG_FILENAME"
    "2/$KWORKFLOW/$CONFIG_FILENAME"
    "5/$KWORKFLOW/$CONFIG_FILENAME"
  )

  output="$(
    function parse_configuration()
    {
      printf '%s\n' "$@"
    }
    load_configuration
  )"

  compare_command_sequence 'Wrong config file reading order' "$LINENO" 'expected' "$output"

  # IF XDG global variables are not defined
  unset XDG_CONFIG_DIRS
  unset XDG_CONFIG_HOME
  HOME='5'

  expected=(
    "1/$CONFIG_FILENAME"
    "/etc/xdg/$KWORKFLOW/$CONFIG_FILENAME"
    "5/.config/$KWORKFLOW/$CONFIG_FILENAME"
    "$PWD/$CONFIG_FILENAME"
  )

  output="$(
    function parse_configuration()
    {
      printf '%s\n' "$@"
    }
    load_configuration
  )"

  compare_command_sequence 'Wrong config file reading order' "$LINENO" 'expected' "$output"

  cd "$original_dir" || {
    fail "($LINENO): It was not possible to move back to original directory"
    return
  }
}

function test_show_variables_completeness()
{
  local -A shown_options
  local -A possible_options
  local output

  # get all assigned options, including commented ones
  # remove #'s and ='s to get option names
  output="$(cat 'etc/kworkflow_template.config')"
  output="$(printf '%s\n' "$output" | grep -oE '^(#?\w+=?)' | sed -E 's/[#=]//g')"

  for option in $output; do
    possible_options["$option"]='1'
  done

  output="$(show_variables 'TEST_MODE' | grep -E '^    ')"
  # shellcheck disable=2001
  output="$(printf '%s\n' "$output" | sed 's/.*(\(\S*\)).*/\1/')"

  for option in $output; do
    shown_options["$option"]=1
  done

  for option in "${!possible_options[@]}"; do
    if [[ ! -v shown_options["$option"] ]]; then
      fail "($LINENO): show_variables is missing option $option"
    fi
  done

  for option in "${!shown_options[@]}"; do
    if [[ ! -v possible_options["$option"] ]]; then
      fail "($LINENO): show_variable is showing $option not present in kworkflow_template.config"
    fi
  done
}

function test_show_variables_correctness()
{
  local output
  local option
  local value
  local message

  unset configurations
  declare -gA configurations=(
    [ssh_ip]=1
    [ssh_port]=2
    [mount_point]=3
    [arch]=4
    [kernel_img_name]=5
    [cross_compile]=6
    [menu_config]=7
    [doc_type]=8
    [virtualizer]=9
    [qemu_hw_options]=10
    [qemu_net_options]=11
    [qemu_path_image]=12
    [alert]=13
    [sound_alert_command]=14
    [visual_alert_command]=15
    [default_deploy_target]=16
    [reboot_after_deploy]=17
    [disable_statistics_data_track]=18
    [gui_on]=19
    [gui_off]=20
  )

  output="$(show_variables | grep -E '^    ')"

  while read -r line; do
    option="$(printf '%s\n' "$line" | sed -E 's/.*\((\S*)\).*/\1/')"
    value=$(printf '%s\n' "$line" | sed -E 's/.*: (.*)/\1/')
    if [[ "${configurations["$option"]}" != "$value" ]]; then
      message="Value of option $option should be "
      message+="${configurations["$option"]} but is $value"
      fail "($LINENO): $message"
    fi
  done <<< "$output"
}

function test_load_configuration()
{
  local current_path="$PWD"
  local msg='We will stop supporting kworkflow.config in the kernel root directory in favor of using a .kw/ directory.'
  local -a expected

  function parse_configuration()
  {
    :
  }

  cp "$PWD/etc/kworkflow_template.config" "$SHUNIT_TMPDIR/kworkflow.config"

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO): It was not possible to move to temporary directory"
    return
  }
  mk_fake_kernel_root "$PWD"

  # No to updating kworkflow.config to .kw/kworkflow.config
  output="$(printf '%s\n' 'n' | load_configuration)"
  assertEquals "($LINENO): There should have been a warning" "$output" "$msg"
  assertTrue 'kworkflow.config was moved' '[[ -f "$PWD/$CONFIG_FILENAME" ]]'

  # Yes to updating kworkflow.config to .kw/kworkflow.config
  output="$(printf '%s\n' 'y' | load_configuration)"

  assertEquals "($LINENO): There should have been a warning" "$output" "$msg"

  assertTrue '.kw was not created' '[[ -d "$PWD/$KW_DIR/" ]]'
  assertTrue 'kworkflow.config is not inside .kw' '[[ -f "$PWD/$KW_DIR/$CONFIG_FILENAME" ]]'
  assertTrue 'kworkflow.config was not moved' '[[ ! -f "$PWD/$CONFIG_FILENAME" ]]'

  rm -rf "${SHUNIT_TMPDIR:?}"/*
  mkdir -p "$SHUNIT_TMPDIR/$KW_DIR"
  cp "$current_path/etc/kworkflow_template.config" "$SHUNIT_TMPDIR/$KW_DIR/kworkflow.config"

  expected=(
    "1/$CONFIG_FILENAME"
    "/etc/xdg/$KWORKFLOW/$CONFIG_FILENAME"
    "5/.config/$KWORKFLOW/$CONFIG_FILENAME"
    "$PWD/$KW_DIR/$CONFIG_FILENAME"
  )

  output="$(
    function parse_configuration()
    {
      printf '%s\n' "$@"
    }
    load_configuration
  )"

  compare_command_sequence '' "$LINENO" 'expected' "$output"

  cd "$current_path" || {
    fail "($LINENO): It was not possible to move back from temp directory"
    return
  }
}

invoke_shunit
