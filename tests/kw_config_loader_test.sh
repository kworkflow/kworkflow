#!/bin/bash

include './tests/utils.sh'
include './src/kw_config_loader.sh'

KWORKFLOW='kw'

function setUp()
{
  original_dir="$PWD"
  export TMPDIR_KW_FOLDER="$SHUNIT_TMPDIR/.kw"
  mkdir -p "$TMPDIR_KW_FOLDER"

  KW_CONFIG_TEMPLATE="$PWD/etc/init_templates/x86-64/kworkflow_template.config"
  KW_BUILD_CONFIG_TEMPLATE="$PWD/etc/init_templates/x86-64/build_template.config"

  # Copy required files for test
  cp "$KW_CONFIG_TEMPLATE" "$TMPDIR_KW_FOLDER/kworkflow.config"
  cp "$KW_BUILD_CONFIG_TEMPLATE" "$TMPDIR_KW_FOLDER/build.config"
  cp "${SAMPLES_DIR}/kworkflow_space_comments.config" "$SHUNIT_TMPDIR"

  configurations=()
  build_config=()

  # Let's run all tests in the sample dir
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
}

function tearDown()
{
  # Get back to kw dir
  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  unset configurations
  declare -gA configurations

  unset build_config
  declare -gA build_config

  unset deploy_config
  declare -gA deploy_config

  unset mail_config
  declare -gA mail_config

  unset notification_config
  declare -gA notification_config

  if [[ -d "$SHUNIT_TMPDIR" ]]; then
    rm -rf "$SHUNIT_TMPDIR"
  fi
}

function test_parse_configuration_success_exit_code()
{
  parse_configuration "$KW_CONFIG_SAMPLE"
  assertTrue 'kw failed to load a regular config file' "[ 0 -eq $? ]"
}

function test_parse_configuration_config_with_spaces_and_comments()
{
  parse_configuration 'kworkflow_space_comments.config'
  assertEquals "($LINENO): Kw failed to load a regular config file" 0 "$?"

  assertEquals "($LINENO)" "${configurations['ssh_user']}" 'juca'
  assertEquals "($LINENO)" "${configurations['mount_point']}" '/home/lala'
  assertEquals "($LINENO)" "${configurations['virtualizer']}" 'libvirt'
  assertEquals "($LINENO)" "${configurations['reboot_after_deploy']}" 'no'
}

function test_parser_configuration_failed_exit_code()
{
  parse_configuration 'tests/foobarpotato'
  assertEquals "($LINENO)" "$?" 22
}

# Helper function used to compare expected config agaist the populated data.
function assert_configurations_helper()
{
  declare -n configurations_ref="$1"
  declare -n expected_configurations_ref="$2"
  local lineno=${3:-LINENO}

  # Check if configurations is contained in expected_configurations
  for k in "${!configurations_ref[@]}"; do
    if [[ ${expected_configurations_ref["$k"]+token} != token ]]; then
      fail "($lineno): Did not expect setting '$k'."
    elif [[ ${configurations_ref["$k"]} != "${expected_configurations_ref[$k]}" ]]; then
      fail "($lineno): Expected setting '${k}' to be '${expected_configurations_ref[$k]}' (found '${configurations_ref[$k]}')."
    fi
  done

  # check if configurations has all expected_configurations keys
  for k in "${!expected_configurations_ref[@]}"; do
    if [[ ${configurations_ref["$k"]+token} != token ]]; then
      fail "($lineno): Expected setting '$k' to be present."
    fi
  done
}

# Test if parse_configuration correctly parses all settings in a file
function test_parse_configuration_check_parser_values_only_for_kworkflow_config_file()
{
  # shellcheck disable=2016
  declare -A expected_configurations=(
    [ssh_user]='juca'
    [ssh_ip]='127.0.0.1'
    [ssh_port]='3333'
    [gui_on]='turn on'
    [gui_off]='turn off'
    [checkpatch_opts]='--no-tree --color=always --strict'
    [get_maintainer_opts]='--separator , --nokeywords --nogit --nogit-fallback --norolestats'
  )

  # Let's replace the current config file for this test
  cp "$KW_CONFIG_SAMPLE" "$TMPDIR_KW_FOLDER"
  parse_configuration "$TMPDIR_KW_FOLDER/kworkflow.config"
  assert_configurations_helper configurations expected_configurations "$LINENO"
}

# Test if etc/init_templates/kworkflow_template.config contains all the expected settings
function test_parse_configuration_standard_config()
{
  declare -A expected_configurations=(
    [ssh_user]='root'
    [ssh_ip]='localhost'
    [ssh_port]='22'
    [alert]='n'
    [sound_alert_command]='paplay SOUNDPATH/bell.wav'
    [visual_alert_command]='notify-send -i checkbox -t 10000 "kw" "Command: \"$COMMAND\" completed!"'
    [disable_statistics_data_track]='no'
    [send_opts]='--annotate --cover-letter --no-chain-reply-to --thread'
    [checkpatch_opts]='--no-tree --color=always --strict'
    [get_maintainer_opts]='--separator , --nokeywords --nogit --nogit-fallback --norolestats'
  )

  parse_configuration "$KW_CONFIG_TEMPLATE"
  assert_configurations_helper configurations expected_configurations "$LINENO"
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
    "1/${CONFIG_FILENAME}"
    "4/${KWORKFLOW}/${CONFIG_FILENAME}"
    "3/${KWORKFLOW}/${CONFIG_FILENAME}"
    "2/${KWORKFLOW}/${CONFIG_FILENAME}"
    "5/${KWORKFLOW}/${CONFIG_FILENAME}"
    "${PWD}/.kw/${CONFIG_FILENAME}"
  )

  output="$(
    function parse_configuration()
    {
      printf '%s\n' "$1"
    }
    load_configuration 'kworkflow'
  )"
  compare_command_sequence 'Wrong config file reading order' "$LINENO" 'expected' "$output"

  # IF XDG global variables are not defined
  unset XDG_CONFIG_DIRS
  unset XDG_CONFIG_HOME
  HOME='5'

  expected=(
    "1/${CONFIG_FILENAME}"
    "/etc/xdg/${KWORKFLOW}/${CONFIG_FILENAME}"
    "5/.config/${KWORKFLOW}/${CONFIG_FILENAME}"
    "${PWD}/.kw/${CONFIG_FILENAME}"
  )

  output="$(
    function parse_configuration()
    {
      printf '%s\n' "$1"
    }
    load_configuration 'kworkflow'
  )"

  compare_command_sequence 'Wrong config file reading order' "$LINENO" 'expected' "$output"

  cd "$original_dir" || {
    fail "($LINENO): It was not possible to move back to original directory"
    return
  }
}

function get_all_assigned_options_to_string_helper()
{
  local config_path="$1"
  local output

  output="$(< "$config_path")"
  output="$(printf '%s\n' "$output" | grep -oE '^(#?\w+=?)' | sed -E 's/[#=]//g')"

  printf '%s' "$output"
}

function test_show_variables_main_completeness()
{
  local -A shown_options
  local -A possible_options
  local output
  local output_mail
  local output_build
  local output_deploy
  local output_notification

  configurations=()

  # get all assigned options, including commented ones
  # remove #'s and ='s to get option names
  output=$(get_all_assigned_options_to_string_helper "$KW_CONFIG_TEMPLATE")
  output_build="$(get_all_assigned_options_to_string_helper "$KW_BUILD_CONFIG_SAMPLE")"
  output_deploy="$(get_all_assigned_options_to_string_helper "$KW_DEPLOY_CONFIG_SAMPLE")"
  output_mail="$(get_all_assigned_options_to_string_helper "$KW_MAIL_CONFIG_SAMPLE")"
  output_notification="$(get_all_assigned_options_to_string_helper "$KW_NOTIFICATION_CONFIG_SAMPLE")"

  output+=" $output_build $output_deploy $output_mail $output_notification"
  for option in $output; do
    possible_options["$option"]=1
  done

  cp "$KW_CONFIG_SAMPLE" "$TMPDIR_KW_FOLDER"
  cp "$KW_BUILD_CONFIG_SAMPLE" "$TMPDIR_KW_FOLDER"
  cp "$KW_MAIL_CONFIG_SAMPLE" "$TMPDIR_KW_FOLDER"
  cp "$KW_NOTIFICATION_CONFIG_SAMPLE" "$TMPDIR_KW_FOLDER"
  cp "${SAMPLES_DIR}/deploy_all_options.config" "${TMPDIR_KW_FOLDER}/deploy.config"

  load_all_config

  output="$(show_variables_main 'TEST_MODE' | grep -E '^    ')"
  output="$(printf '%s\n' "$output" | sed 's/.*(\(\S*\)).*/\1/')"

  for option in $output; do
    shown_options["$option"]=1
  done

  assert_configurations_helper possible_options shown_options "$LINENO"
}

function test_show_variables_main_correctness()
{
  local output
  local option
  local value
  local message

  # show_variables_main will load the config file, and for this test we want to
  # avoid this behaviour. For this reason, we are deleting the .kw folder
  rm -rf .kw

  declare -gA configurations=(
    [ssh_ip]=1
    [ssh_port]=2
    [mount_point]='/home/lala'
    [menu_config]=4
    [virtualizer]='libvirt'
    [qemu_hw_options]=6
    [qemu_net_options]=7
    [qemu_path_image]='/home/xpto/p/virty.qcow2'
    [alert]='n'
    [sound_alert_command]='paplay SOUNDPATH/bell.wav'
    [visual_alert_command]='notify-send lala'
    [default_deploy_target]='remote'
    [reboot_after_deploy]='no'
    [deploy_temporary_files_path]='/tmp/kw'
    [dtb_copy_pattern]='broadcom/*.dtb'
    [strip_modules_debug_option]='yes'
    [deploy_default_compression]='lzop'
    [kw_files_remote_path]='/opt/kw'
    [send_opts]='--annotate --cover-letter --no-chain-reply-to --thread'
    [blocked_emails]='test@email.com'
    [disable_statistics_data_track]=14
    [gui_on]=15
    [gui_off]=16
  )

  output="$(show_variables_main | grep -E '^\s{3,}')"
  while read -r line; do
    option="$(printf '%s\n' "$line" | sed -E 's/.*\((\S*)\).*/\1/')"
    value=$(printf '%s\n' "$line" | sed -E 's/.*: (.*)/\1/')
    if [[ "${configurations[$option]}" != "$value" ]]; then
      message="Value of option $option should be "
      message+="${configurations["$option"]} but is $value"
      fail "($LINENO): $message"
    fi
  done <<< "$output"
}

function test_load_configuration()
{
  local msg='We will stop supporting kworkflow.config in the kernel root directory in favor of using a .kw/ directory.'
  local -a expected

  function parse_configuration()
  {
    :
  }

  # We want to force kw to warn users
  cp "$KW_CONFIG_TEMPLATE" "${SHUNIT_TMPDIR}/kworkflow.config"

  mk_fake_kernel_root "$PWD"

  # No to updating kworkflow.config to .kw/kworkflow.config
  output="$(printf '%s\n' 'n' | load_kworkflow_config)"
  assertEquals "($LINENO): There should have been a warning" "$output" "$msg"
  assertTrue 'kworkflow.config was moved' '[[ -f "$PWD/$CONFIG_FILENAME" ]]'

  # Yes to updating kworkflow.config to .kw/kworkflow.config
  output="$(printf '%s\n' 'y' | load_configuration)"

  assertEquals "($LINENO): There should have been a warning" "$output" "$msg"

  assertTrue '.kw was not created' '[[ -d "$PWD/$KW_DIR/" ]]'
  assertTrue 'kworkflow.config is not inside .kw' '[[ -f "$PWD/$KW_DIR/$CONFIG_FILENAME" ]]'
  assertTrue 'kworkflow.config was not moved' '[[ ! -f "$PWD/$CONFIG_FILENAME" ]]'

  rm -rf "${SHUNIT_TMPDIR:?}"/*
  mkdir -p "${SHUNIT_TMPDIR}/${KW_DIR}"
  cp "${KW_CONFIG_TEMPLATE}" "${SHUNIT_TMPDIR}/${KW_DIR}/kworkflow.config"

  expected=(
    "1/${CONFIG_FILENAME}"
    "/etc/xdg/${KWORKFLOW}/${CONFIG_FILENAME}"
    "5/.config/${KWORKFLOW}/${CONFIG_FILENAME}"
    "${PWD}/${KW_DIR}/${CONFIG_FILENAME}"
  )

  output="$(
    function parse_configuration()
    {
      printf '%s\n' "$1"
    }
    load_configuration 'kworkflow'
  )"

  compare_command_sequence '' "$LINENO" 'expected' "$output"
}

invoke_shunit
