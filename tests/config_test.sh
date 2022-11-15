#!/bin/bash

include './src/config.sh'
include './tests/utils.sh'

function setUp()
{
  export KW_CONFIG_BASE_PATH="${SHUNIT_TMPDIR}/.kw"
  export ORIGINAL_PATH="$PWD"

  mkdir -p "${KW_CONFIG_BASE_PATH}"

  # Copy sample files
  cp "${KW_CONFIG_SAMPLE_X86}" "${KW_CONFIG_BASE_PATH}"
  cp "${KW_BUILD_CONFIG_SAMPLE}" "${KW_CONFIG_BASE_PATH}"
  cp "${KW_MAIL_CONFIG_SAMPLE}" "${KW_CONFIG_BASE_PATH}"
  cp "${KW_DEPLOY_CONFIG_SAMPLE}" "${KW_CONFIG_BASE_PATH}"
  cp "${KW_NOTIFICATION_CONFIG_SAMPLE}" "${KW_CONFIG_BASE_PATH}"
  cp "${KW_CONFIG_SAMPLE}" "${KW_CONFIG_BASE_PATH}"

  # Let's run all test in a well-contained folder
  cd "${KW_CONFIG_BASE_PATH}" || {
    fail "($LINENO): setUp: It was not possible to move into ${KW_CONFIG_BASE_PATH}"
    return
  }
}

function tearDown()
{
  cd "$ORIGINAL_PATH" || {
    fail "($LINENO): tearDown: It was not possible to move into ${ORIGINAL_PATH}"
    return
  }

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

function test_set_config_value_with_dot_in_the_value()
{
  validate_option_parameter 'this.is valid'
  assertEquals "($LINENO)" "$?" 0

  validate_option_parameter 'this.is valid.also.valid'
  assertEquals "($LINENO)" "$?" 0

  validate_option_parameter 'this is.not.valid'
  assertEquals "($LINENO)" "$?" 22
}

function test_check_if_target_config_exist()
{
  check_if_target_config_exist 'deploy' 'deploy.config'
  assertEquals "($LINENO)" "$?" 0

  check_if_target_config_exist 'deploy' 'la.config'
  assertEquals "($LINENO)" "$?" 2
}

function test_parse_config_options()
{
  unset options_values
  declare -gA options_values

  parse_config_options
  assert_equals_helper 'Expected local as a default scope' \
    "($LINENO)" 'local' "${options_values['SCOPE']}"

  # test default options
  parse_config_options --global

  assert_equals_helper 'Set global scope' \
    "($LINENO)" 'global' "${options_values['SCOPE']}"

  parse_config_options --local
  assert_equals_helper 'Set local scope' \
    "($LINENO)" 'local' "${options_values['SCOPE']}"

  parse_config_options 'build.something=xpto'
  assert_equals_helper 'Expected <build.something=xpto>' \
    "($LINENO)" 'build.something=xpto ' "${options_values['PARAMETERS']}"

  parse_config_options --invalid
  assertEquals "($LINENO)" 22 "$?"
}

function test_show_configurations_without_parameters()
{
  local output

  # The config files are expected to be inside of a .kw folder so we need to go
  # up one level
  cd '../' || {
    fail "($LINENO): It was not possible to move into the parent directory."
    return
  }

  output=$(show_configurations)

  assert_line_match "$LINENO" 'build.arch=arm64' "$output"
  assert_line_match "$LINENO" 'build.kernel_img_name=Image' "$output"
  assert_line_match "$LINENO" 'build.cross_compile=aarch64-linux-gnu-' "$output"
  assert_line_match "$LINENO" 'build.menu_config=nconfig' "$output"
  assert_line_match "$LINENO" 'build.doc_type=htmldocs' "$output"
  assert_line_match "$LINENO" 'build.cpu_scaling_factor=100' "$output"
  assert_line_match "$LINENO" 'build.enable_ccache=true' "$output"
  assert_line_match "$LINENO" 'build.warning_level=2' "$output"
  assert_line_match "$LINENO" 'build.use_llvm=yes' "$output"

  assert_line_match "$LINENO" 'mail.send_opts=--annotate --cover-letter --no-chain-reply-to --thread' "$output"
  assert_line_match "$LINENO" 'mail.blocked_emails=test@email.com' "$output"

  assert_line_match "$LINENO" 'deploy.default_deploy_target=remote' "$output"
  assert_line_match "$LINENO" 'deploy.reboot_after_deploy=no' "$output"
  assert_line_match "$LINENO" 'deploy.kw_files_remote_path=/opt/kw' "$output"
  assert_line_match "$LINENO" 'deploy.deploy_temporary_files_path=/tmp/kw' "$output"
  assert_line_match "$LINENO" 'deploy.strip_modules_debug_option=yes' "$output"
  assert_line_match "$LINENO" 'deploy.dtb_copy_pattern=broadcom/*.dtb' "$output"
  assert_line_match "$LINENO" 'deploy.deploy_default_compression=lzop' "$output"

  assert_line_match "$LINENO" 'notification.alert=n' "$output"
  assert_line_match "$LINENO" 'notification.sound_alert_command=paplay SOUNDPATH/bell.wav' "$output"
  assert_line_match "$LINENO" 'notification.visual_alert_command=notify-send lala' "$output"

  assert_line_match "$LINENO" 'kworkflow.ssh_user=juca' "$output"
  assert_line_match "$LINENO" 'kworkflow.ssh_ip=127.0.0.1' "$output"
  assert_line_match "$LINENO" 'kworkflow.ssh_port=3333' "$output"
  assert_line_match "$LINENO" 'kworkflow.gui_on=turn on' "$output"
  assert_line_match "$LINENO" 'kworkflow.gui_off=turn off' "$output"
  assert_line_match "$LINENO" 'kworkflow.checkpatch_opts=--no-tree --color=always --strict' "$output"
  assert_line_match "$LINENO" 'kworkflow.get_maintainer_opts=--separator , --nokeywords --nogit --nogit-fallback --norolestats' "$output"

  cd "${KW_CONFIG_BASE_PATH}" || {
    fail "($LINENO): It was not possible to move into ${KW_CONFIG_BASE_PATH}"
    return
  }
}

function test_show_configurations_with_parameters()
{
  local output

  # The config files are expected to be inside of a .kw folder so we need to go
  # up one level
  cd '../' || {
    fail "($LINENO): It was not possible to move into the parent directory."
    return
  }

  output=$(show_configurations 'notification')

  assert_line_match "$LINENO" 'notification.alert=n' "$output"
  assert_line_match "$LINENO" 'notification.sound_alert_command=paplay SOUNDPATH/bell.wav' "$output"
  assert_line_match "$LINENO" 'notification.visual_alert_command=notify-send lala' "$output"

  # These lines should not be present in the output
  assert_no_line_match "$LINENO" 'build.arch=arm64' "$output"
  assert_no_line_match "$LINENO" 'kworkflow.ssh_port=3333' "$output"
  assert_no_line_match "$LINENO" 'deploy.dtb_copy_pattern=broadcom/*.dtb' "$output"
  assert_no_line_match "$LINENO" 'mail.blocked_emails=test@email.com' "$output"

  cd "${KW_CONFIG_BASE_PATH}" || {
    fail "($LINENO): It was not possible to move into ${KW_CONFIG_BASE_PATH}"
    return
  }
}

function test_show_configurations_invalid_target()
{
  local output

  output=$(show_configurations invalid_target)
  assertEquals "($LINENO)" "$output" 'Invalid config target: invalid_target'
  show_configurations invalid_target > /dev/null 2>&1
  assertEquals "($LINENO)" "$?" 22
}

invoke_shunit
