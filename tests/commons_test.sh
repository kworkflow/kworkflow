#!/bin/bash

. ./tests/utils --source-only

function suite
{
  suite_addTest "testConfigFileNotFound"
  suite_addTest "testConfigFileFound"
}

function setUp
{
    mkdir -p tests/.tmp_commons_test
}

function tearDown
{
    rm -rf tests/.tmp_commons_test
}

function testConfigFileNotFound
{
    . ./src/commons.sh --source-only

    declare -A expected_configurations=(
      [qemu_path_image]=$VDISK
      [qemu_hw_options]=$QEMU_OPT
      [qemu_net_options]=""
      [port]=$DEFAULT_PORT
      [ip]=$DEFAULT_IP
    )

    pushd tests/.tmp_commons_test
    check_local_configuration
    popd

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

function testConfigFileFound
{
    . ./src/commons.sh --source-only

    declare -A expected_configurations=(
      [key1]="value1"
      [key2]="value2"
      [key3]="value3"
      [ip]="127.0.0.1"
      [port]="2222"
    )

    cp tests/samples/kworkflow.config tests/.tmp_commons_test/

    pushd tests/.tmp_commons_test
    check_local_configuration
    popd

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
