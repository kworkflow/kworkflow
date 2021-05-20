#!/bin/bash

. ./tests/utils --source-only
. ./src/kw_config_loader.sh --source-only

TMP_DIR=tests/.tmp_kw_config_loader_test

function suite
{
  suite_addTest "parse_configuration_success_exit_code_Test"
  suite_addTest "parser_configuration_failed_exit_code_Test"
  suite_addTest "parse_configuration_output_Test"
  suite_addTest "parse_configuration_standard_config_Test"
  suite_addTest "parse_configuration_files_loading_order_Test"
}

function setUp
{
  mkdir -p "$TMP_DIR"
  cp "$PWD/etc/kworkflow_template.config" "$TMP_DIR/kworkflow.config"
  configurations=()
}

function tearDown
{
  rm -rf "$TMP_DIR"
}

function parse_configuration_success_exit_code_Test
{
  parse_configuration tests/samples/kworkflow.config
  assertTrue "Kw failed to load a regular config file" "[ 0 -eq $? ]"
}

function parser_configuration_failed_exit_code_Test
{
  parse_configuration tests/kw_config_loader_test.sh
  assertTrue "kw loaded an unsupported file" "[ 22 -eq $? ]"
}

function assertConfigurations
{
  declare -n configurations_ref=$1
  declare -n expected_configurations_ref=$2

  # check if configurations is contained in expected_configurations
  for k in "${!configurations_ref[@]}"; do
    if [[ ${expected_configurations_ref[$k]+token} != token ]]; then
      fail "Did not expect setting \"$k\"."
    elif [[ ${configurations_ref[$k]} != ${expected_configurations_ref[$k]} ]]; then
      fail "Expected setting \"${k}\" to be \"${expected_configurations_ref[$k]}\" (found \"${configurations_ref[$k]}\")."
    fi
  done

  # check if configurations has all expected_configurations keys
  for k in "${!expected_configurations_ref[@]}"; do
    if [[ ${configurations_ref[$k]+token} != token ]]; then
      fail "Expected setting \"$k\" to be present."
    fi
  done
}

# Test if parse_configuration correctly parses all settings in a file
function parse_configuration_output_Test
{
  declare -A expected_configurations=(
    [arch]="arm64"
    [kernel_img_name]="Image"
    [cross_compile]="aarch64-linux-gnu-"
    [virtualizer]="libvirt"
    [qemu_path_image]="/home/xpto/p/virty.qcow2"
    [ssh_ip]="127.0.0.1"
    [ssh_port]="3333"
    [mount_point]="/home/lala"
    [default_deploy_target]="vm"
    [reboot_after_deploy]="no"
    [gui_on]="turn on"
    [gui_off]="turn off"
    [doc_type]="htmldocs"
  )

  cp tests/samples/kworkflow.config "$TMP_DIR/"

  pushd "$TMP_DIR" > /dev/null
  parse_configuration $PWD/kworkflow.config
  popd > /dev/null

  assertConfigurations configurations expected_configurations

  true # Reset return value
}

# Test if etc/kworkflow_template.config contains all the expected settings
function parse_configuration_standard_config_Test
{
  local path_repo=$PWD

  declare -A expected_configurations=(
    [arch]="x86_64"
    [kernel_img_name]="bzImage"
    [menu_config]="nconfig"
    [virtualizer]="qemu-system-x86_64"
    [qemu_path_image]="/home/USERKW/p/virty.qcow2"
    [qemu_hw_options]="-enable-kvm -daemonize -smp 2 -m 1024"
    [qemu_net_options]="-net nic -net user,hostfwd=tcp::2222-:22,smb=/home/USERKW"
    [ssh_ip]="localhost"
    [ssh_port]="22"
    [mount_point]="/home/USERKW/p/mount"
    [alert]="n"
    [sound_alert_command]="paplay SOUNDPATH/complete.wav"
    [visual_alert_command]="notify-send -i checkbox -t 10000 \"kw\" \"Command: \\\\\"\$COMMAND\\\\\" completed!\""
    [default_deploy_target]="vm"
    [reboot_after_deploy]="no"
    [disable_statistics_data_track]="no"
    [doc_type]="htmldocs"
  )

  parse_configuration "$TMP_DIR/kworkflow.config"
  assertConfigurations configurations expected_configurations

  true # Reset return value
}

function parse_configuration_files_loading_order_Test
{
  expected="$KW_ETC_DIR/$CONFIG_FILENAME
$HOME/.kw/$CONFIG_FILENAME
$PWD/$CONFIG_FILENAME"

  output="$(
    function parse_configuration { echo "$@"; }
    load_configuration
  )"

  expected_vs_got="Expected:\n>>>$expected<<<\nGot:\n>>>$output<<<"

  [[ "$output" == "$expected" ]]
  assertTrue "Wrong config file reading order.\n$expected_vs_got" $?
}

invoke_shunit
