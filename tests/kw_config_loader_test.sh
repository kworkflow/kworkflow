#!/bin/bash

. ./tests/utils --source-only
. ./src/kw_config_loader.sh --source-only

TMP_DIR=tests/.tmp_kw_config_loader_test

function suite
{
  suite_addTest "parser_success_exit_code_Test"
  suite_addTest "parser_failed_exit_code_Test"
  suite_addTest "parser_output_Test"
  suite_addTest "default_config_file_Test"
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

function parser_success_exit_code_Test
{
    parse_configuration tests/samples/kworkflow.config
    assertTrue "Kw failed to load a regular config file" "[ 0 -eq $? ]"
}

function parser_failed_exit_code_Test
{
    parse_configuration tests/kw_config_loader_test.sh
    assertTrue "kw loaded an unsupported file" "[ 22 -eq $? ]"
}

# Test if parse_configuration correctly parses all settings in a file
function parser_output_Test
{
    declare -A expected_configurations=(
      [arch]="arm"
      [virtualizer]="libvirt"
      [qemu_path_image]="/home/xpto/p/virty.qcow2"
      [ssh_ip]="127.0.0.1"
      [ssh_port]="3333"
      [mount_point]="/home/lala"
      [default_deploy_target]="vm"
    )

    cp tests/samples/kworkflow.config "$TMP_DIR/"

    pushd "$TMP_DIR" > /dev/null
    parse_configuration $PWD/kworkflow.config
    popd > /dev/null

    # check if configurations is contained in expected_configurations
    for k in "${!configurations[@]}"; do
        if [[ ${configurations[$k]} != ${expected_configurations[$k]} ]]; then
            fail "Expected configuration \"${k}\" to be \"${expected_configurations[$k]}\" (found \"${configurations[$k]}\")"
        fi
    done

    # check if expected_configurations is contained in configurations
    for k in "${!expected_configurations[@]}"; do
        if [[ ${configurations[$k]} != ${expected_configurations[$k]} ]]; then
            fail "Did not expected \"${k}\" to be in configurations"
        fi
    done

    true # Reset return value
}

# Test if etc/kworkflow_template.config contains all the expected settings
function default_config_file_Test
{
    local path_repo=$PWD

    declare -A expected_configurations=(
      [arch]="x86_64"
      [virtualizer]="qemu-system-x86_64"
      [qemu_path_image]="/home/USERKW/p/virty.qcow2"
      [qemu_hw_options]="-enable-kvm -daemonize -smp 2 -m 1024"
      [qemu_net_options]="-net nic -net user,hostfwd=tcp::2222-:22,smb=/home/USERKW"
      [ssh_ip]="localhost"
      [ssh_port]="22"
      [mount_point]="/home/USERKW/p/mount"
      [alert]="n"
      [sound_alert_command]="paplay INSTALLPATH/sounds/complete.wav"
      [visual_alert_command]="notify-send -i checkbox -t 10000 \"kw\" \"Command: \\\\\"\$COMMAND\\\\\" completed!\""
      [default_deploy_target]="vm"
      [reboot_after_deploy]="no"
    )

    parse_configuration "$TMP_DIR/kworkflow.config"

    # check if configurations is contained in expected_configurations
    for k in "${!configurations[@]}"; do
        if [[ ${configurations[$k]} != ${expected_configurations[$k]} ]]; then
            fail "Expected configuration \"${k}\" to be \"${expected_configurations[$k]}\" (found \"${configurations[$k]}\")"
        fi
    done

    # check if expected_configurations is contained in configurations
    for k in "${!expected_configurations[@]}"; do
        if [[ ${configurations[$k]} != ${expected_configurations[$k]} ]]; then
            fail "Did not expected \"${k}\" to be in configurations"
        fi
    done

    true # Reset return value
}

invoke_shunit
