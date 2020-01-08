#!/bin/bash

. ./tests/utils --source-only

function suite
{
  suite_addTest "testParseRegularConfig"
  suite_addTest "testParseUnsupportedFile"
  suite_addTest "testDefaultConfigFile"
  suite_addTest "testLocalConfigFile"
}

function setUp
{
    mkdir -p tests/.tmp_commons_test
    cp "$PWD/etc/kworkflow_template.config" tests/.tmp_commons_test/kworkflow.config
}

function tearDown
{
    rm -rf tests/.tmp_commons_test
}

function testParseRegularConfig
{
    . ./src/commons.sh --source-only

    parse_configuration tests/samples/kworkflow.config
    assertTrue "Kw failed to load a regular config file" "[ 0 -eq $? ]"
}

function testParseUnsupportedFile
{
    . ./src/commons.sh --source-only

    parse_configuration tests/commons_test.sh
    assertTrue "kw loaded an unsopported file" "[ 22 -eq $? ]"
}

function testDefaultConfigFile
{
    local path_repo=$PWD

    . ./src/commons.sh --source-only

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

    parse_configuration tests/.tmp_commons_test/kworkflow.config

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

function testLocalConfigFile
{
    . ./src/commons.sh --source-only

    declare -A expected_configurations=(
      [arch]="arm"
      [virtualizer]="libvirt"
      [qemu_path_image]="/home/xpto/p/virty.qcow2"
      [ssh_ip]="127.0.0.1"
      [ssh_port]="3333"
      [mount_point]="/home/lala"
      [default_deploy_target]="vm"
    )

    cp tests/samples/kworkflow.config tests/.tmp_commons_test/

    pushd tests/.tmp_commons_test > /dev/null
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

invoke_shunit
