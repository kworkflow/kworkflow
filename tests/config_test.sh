#!/bin/bash

include './src/config.sh'
include './tests/utils.sh'

function setUp()
{
  export KW_CONFIG_BASE_PATH="${SHUNIT_TMPDIR}/.kw"
  export ORIGINAL_PATH="$PWD"

  mkdir -p "${KW_CONFIG_BASE_PATH}"

  # Copy sample files
  cp "${KW_BUILD_CONFIG_SAMPLE}" "${KW_CONFIG_BASE_PATH}"
  cp "${KW_CONFIG_SAMPLE_X86}" "${KW_CONFIG_BASE_PATH}"

  # Let's run all test in a well-contained folder
  cd "${KW_CONFIG_BASE_PATH}"
}

function tearDown()
{
  cd "$ORIGINAL_PATH"
  rm -rf "${KW_CONFIG_BASE_PATH}"
}

function test_is_config_file_valid()
{
  is_config_file_valid 'invalid'
  assertEquals "($LINENO)" "$?" 22

  is_config_file_valid 'builds'
  assertEquals "($LINENO)" "$?" 22

  is_config_file_valid 'kworkflows'
  assertEquals "($LINENO)" "$?" 22

  # Valid options
  is_config_file_valid 'kworkflow'
  assertEquals "($LINENO)" "$?" 0

  is_config_file_valid 'build'
  assertEquals "($LINENO)" "$?" 0
}

function test_is_a_valid_config_option_only_valid_options()
{
  is_a_valid_config_option 'build' 'cross_compile'
  assertEquals "($LINENO)" "$?" 0

  is_a_valid_config_option 'kworkflow' 'ssh_ip'
  assertEquals "($LINENO)" "$?" 0
}

function test_is_a_valid_config_invalid_parameters()
{
  local output

  output=$(is_a_valid_config_option 'build')
  assertEquals "($LINENO)" "$?" 22

  output=$(is_a_valid_config_option 'kworkflow')
  assertEquals "($LINENO)" "$?" 22

  output=$(is_a_valid_config_option 'kworkflow' 'this_is_invalid')
  assertEquals "($LINENO)" "$?" 95

  output=$(is_a_valid_config_option 'build' 'nop')
  assertEquals "($LINENO)" "$?" 95
}

function test_set_config_value_changing_default_value()
{
  local output

  set_config_value 'use_llvm' 'lala' "${KW_CONFIG_BASE_PATH}/build.config"
  output=$(grep 'use_llvm' "${KW_CONFIG_BASE_PATH}/build.config")
  assert_equals_helper 'Change llvm' "($LINENO)" "$output" 'use_llvm=lala'

  set_config_value 'menu_config' 'menuconfig' "${KW_CONFIG_BASE_PATH}/build.config"
  output=$(grep 'menu_config' "${KW_CONFIG_BASE_PATH}/build.config")
  assert_equals_helper 'Change llvm' "($LINENO)" "$output" 'menu_config=menuconfig'
}

invoke_shunit
