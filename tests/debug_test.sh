#!/bin/bash

include './src/debug.sh'
include './tests/utils.sh'

function setUp
{
  original_dir="$PWD"

  parse_configuration "$KW_CONFIG_SAMPLE"

  # Create a mock folder for /sys/kernel/debug/tracing/events
  SYS_PATH='/sys/kernel/debug/tracing/events'
  mkdir -p "$SHUNIT_TMPDIR/$SYS_PATH"

  EVENTS_FOLDER_STR="alarmtimer amdgpu amdgpu_dm block bpf_test_run bpf_trace \
cgroup clk cma compaction cpuhp devfreq devlink dma_fence drm enable \
exceptions ext4 fib fib6"

  IF=' ' read -r -a events_folders <<< "$EVENTS_FOLDER_STR"
  for event in "${events_folders[@]}"; do
    mkdir "$SHUNIT_TMPDIR/$SYS_PATH/$event"
  done

  # Create specific events filters
  amdgpu_dm_events_str="amdgpu_dc_performance amdgpu_dc_rreg amdgpu_dc_wreg \
        amdgpu_dm_atomic_check_begin amdgpu_dm_atomic_check_finish \
        amdgpu_dm_atomic_commit_tail_begin amdgpu_dm_atomic_commit_tail_finish \
        amdgpu_dm_atomic_state_template amdgpu_dm_atomic_update_cursor \
        amdgpu_dm_connector_atomic_check amdgpu_dm_crtc_atomic_check \
        amdgpu_dm_dc_clocks_state amdgpu_dm_dce_clocks_state \
        amdgpu_dm_dc_pipe_state amdgpu_dm_plane_atomic_check enable filter"
  mkdir "$SHUNIT_TMPDIR/$SYS_PATH/$event/amdgpu_dm"

  IF=' ' read -r -a amdgpu_events <<< "$amdgpu_dm_events_str"
  for amdgpu_event in "${amdgpu_events[@]}"; do
    mkdir "$SHUNIT_TMPDIR/$SYS_PATH/amdgpu_dm/$amdgpu_event"
  done
}

function tearDown()
{
  # Clean everything inside directory
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  rm -rf ./*

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

function test_prepare_log_database()
{
  local output=''

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(prepare_log_database)
  assertTrue "($LINENO) Expected an empty string" '[[ -z "$output" ]]'

  dir_id=$(date +1_%Y-%m-%d)
  output=$(prepare_log_database 1)
  assertTrue "($LINENO) Expected to find $KW_DEBUG/$dir_id folder" '[[ -d "$PWD/$KW_DEBUG/$dir_id" ]]'

  dir_id=$(date +2_%Y-%m-%d)
  output=$(prepare_log_database 1)
  assertTrue "($LINENO) Expected to find $KW_DEBUG/$dir_id folder" '[[ -d "$PWD/$KW_DEBUG/$dir_id" ]]'

  # Try after 10
  for i in 3 4 5 6 7 8 9 10 11 12; do
    dir_id=$(date "+$i""_%Y-%m-%d")
    mkdir -p "$PWD/$KW_DEBUG/$dir_id"
  done

  dir_id=$(date +13_%Y-%m-%d)
  output=$(prepare_log_database 1)

  assertTrue "($LINENO) Expected to find $KW_DEBUG/$dir_id folder" '[[ -d "$PWD/$KW_DEBUG/$dir_id" ]]'

  mkdir -p "$PWD/$KW_DEBUG/add_noise"
  dir_id=$(date +3_%Y-%m-%d)
  output=$(prepare_log_database 1)
  assertTrue "($LINENO) Random directory inside debug dir" '[[ -d "$PWD/$KW_DEBUG/$dir_id" ]]'
  touch "$PWD/$KW_DEBUG/now_a_junk_file"
  dir_id=$(date +4_%Y-%m-%d)
  output=$(prepare_log_database 1)
  assertTrue "($LINENO) Random file inside debug dir" '[[ -d "$PWD/$KW_DEBUG/$dir_id" ]]'
}

function test_process_list()
{
  local raw_input=''
  local output=''
  local event=''

  raw_input=$(find "$SHUNIT_TMPDIR/$SYS_PATH" -maxdepth 1 | column)
  output=$(process_list "$raw_input" '')
  assertTrue "($LINENO) We expected a substring \"$raw_input\", but we got \"$output\"" '[[ "$output" =~ "$raw_input" ]]'

  raw_input=$(find "$SHUNIT_TMPDIR/$SYS_PATH/amdgpu_dm" -maxdepth 1)
  raw_input=$(sed '/^ssh\|^enable\|^filter/d' <<< "$raw_output" | nl)
  output=$(process_list "$raw_input" "1")
  assertTrue "($LINENO) We expected a substring \"$raw_input\", but we got \"$output\"" '[[ "$output" =~ "$raw_input" ]]'

  raw_input=''
  output=$(process_list "$raw_input" 1)
  ret="$?"
  assertEquals "($LINENO) Return error:" "$ret" 22
}

function test_convert_event_syntax_to_sys_path_hash()
{
  local single_event='amdgpu_dm:amdgpu_dm_dc_clocks_state,amdgpu_dm_dce_clocks_state'
  local multiple_event='amdgpu_dm:amdgpu_dm_dc_clocks_state,amdgpu_dm_dce_clocks_state;kvm:kvm_entry,kvm_fpu'
  local single_filter_event='amdgpu_dm:amdgpu_dm_dc_clocks_state,amdgpu_dm_dce_clocks_state[sclk_khz > 0]'
  local multiple_filters='amdgpu_dm:amdgpu_dm_dc_clocks_state[sclk_khz == 3 && x > 2],amdgpu_dm_dce_clocks_state[sclk_khz > 0]'
  local multiple_filters_and_events="$multiple_filters;kvm:kvm_entry[kvm == 32],kvm_fpu[3.43 <= x]"
  local no_specific_event='amdgpu_dm'

  # Wrong syntax validation
  local no_colon='amdgpu_dm amdgpu_dm_dc_clocks_state,amdgpu_dm_dce_clocks_state'
  local root_event_problem='amdgpu_dm:'
  local array_of_keys
  local array_of_values

  declare -a expected_single_events=(
    "$EVENT_BASE_PATH/amdgpu_dm/amdgpu_dm_dc_clocks_state"
    "$EVENT_BASE_PATH/amdgpu_dm/amdgpu_dm_dce_clocks_state"
  )

  declare -a expected_multiple_events=(
    "$EVENT_BASE_PATH/amdgpu_dm/amdgpu_dm_dc_clocks_state"
    "$EVENT_BASE_PATH/amdgpu_dm/amdgpu_dm_dce_clocks_state"
    "$EVENT_BASE_PATH/kvm/kvm_entry"
    "$EVENT_BASE_PATH/kvm/kvm_fpu"
  )

  declare -a expected_single_filter_events=(
    "$EVENT_BASE_PATH/amdgpu_dm/amdgpu_dm_dc_clocks_state"
    "$EVENT_BASE_PATH/amdgpu_dm/amdgpu_dm_dce_clocks_state"
  )

  declare -a expected_multiple_filters=(
    'sclk_khz == 3 && x > 2'
    'sclk_khz > 0'
  )

  declare -a expected_multiple_events_and_filters=(
    'sclk_khz == 3 && x > 2'
    'sclk_khz > 0'
    'kvm == 32'
    '3.43 <= x'
  )

  events_hash=()
  convert_event_syntax_to_sys_path_hash "$single_event"
  array_of_keys=("${!events_hash[@]}")
  compare_array_values expected_single_events array_of_keys "$LINENO"

  events_hash=()
  convert_event_syntax_to_sys_path_hash "$multiple_event"
  array_of_keys=("${!events_hash[@]}")
  compare_array_values expected_multiple_events array_of_keys "$LINENO"

  events_hash=()
  convert_event_syntax_to_sys_path_hash "$single_filter_event"
  array_of_keys=("${!events_hash[@]}")
  compare_array_values expected_single_filter_events array_of_keys
  # Checking filter
  output=$(
    IFS=$'\n'
    echo "${events_hash[*]}"
  )
  assertTrue "($LINENO) Did not find 'sclk_khz > 1'" '[[ "$output" =~ "sclk_khz > 0" ]]'

  # Multiple filters
  events_hash=()
  convert_event_syntax_to_sys_path_hash "$multiple_filters"
  array_of_keys=("${!events_hash[@]}")
  compare_array_values expected_single_filter_events array_of_keys "$LINENO"
  # Checking filter
  output=$(
    IFS=$'\n'
    echo "${events_hash[*]}"
  )
  array_of_values=("${events_hash[*]}")
  compare_array_values expected_multiple_filters array_of_values "$LINENO"

  events_hash=()
  convert_event_syntax_to_sys_path_hash "$no_specific_event"
  output=$(
    IFS=$'\n'
    echo "${!events_hash[*]}"
  )
  assertTrue "($LINENO) Expected to find the root event 'amdgpu_dm'" '[[ "$output" =~ "$EVENT_BASE_PATH/amdgpu_dm" ]]'

  # Multiple filters and events
  events_hash=()
  convert_event_syntax_to_sys_path_hash "$multiple_filters_and_events"
  array_of_values=("${events_hash[*]}")
  compare_array_values expected_multiple_events_and_filters array_of_values "$LINENO"

  # Invalid
  events_hash=()
  convert_event_syntax_to_sys_path_hash "$no_colon"
  ret="$?"
  output=$(
    IFS=$'\n'
    echo "${!events_hash[*]}"
  )
  assertEquals "($LINENO) Wrong syntax:" "$output" ''
  assertEquals "($LINENO) Return error:" "$ret" 22

  events_hash=()
  convert_event_syntax_to_sys_path_hash ':'
  ret="$?"
  output=$(
    IFS=$'\n'
    echo "${!events_hash[*]}"
  )
  assertEquals "($LINENO) Wrong syntax:" "$output" ''
  assertEquals "($LINENO) Return error:" "$ret" 22
}

function test_build_event_command_string()
{
  local dummy_path="$TRACING_BASE_PATH/dummy"
  declare -lA events_hash
  declare -la commands_array

  events_hash=()
  events_hash=(["$dummy_path/test1"]=''
    ["$dummy_path/filter1"]='x > 42'
    ["$dummy_path/test2"]=''
    ["$dummy_path/filter2"]='x < 42')

  declare -a expected_string_command=(
    "echo 'x > 42' > /sys/kernel/debug/tracing/dummy/filter1/filter"
    "echo 'x < 42' > /sys/kernel/debug/tracing/dummy/filter2/filter"
    'echo 1 > /sys/kernel/debug/tracing/dummy/filter1/enable'
    'echo 1 > /sys/kernel/debug/tracing/dummy/filter2/enable'
    'echo 1 > /sys/kernel/debug/tracing/dummy/test2/enable'
    'echo 1 > /sys/kernel/debug/tracing/dummy/test1/enable'
    'echo 1 > /sys/kernel/debug/tracing/dummy/test1/enable && echo 1 > /sys/kernel/debug/tracing/tracing_on'
  )

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(build_event_command_string '')
  output=$(echo "$output" | sed -r 's/;/\n/g' | sed -r 's/^\s//g')
  IFS=$'\n' read -rd '' -a commands_array <<< "$output"

  compare_array_values expected_string_command commands_array "$LINENO"

  # Check disable
  commands_array=()
  events_hash=()
  events_hash=(["$dummy_path/test1"]=''
    ["$dummy_path/filter1"]=''
    ["$dummy_path/test2"]=''
    ["$dummy_path/filter2"]='')

  declare -a expected_string_command_disable=(
    "echo '0' > /sys/kernel/debug/tracing/dummy/filter1/filter"
    "echo '0' > /sys/kernel/debug/tracing/dummy/filter2/filter"
    "echo '0' > /sys/kernel/debug/tracing/dummy/test2/filter"
    "echo '0' > /sys/kernel/debug/tracing/dummy/test1/filter"
    'echo 0 > /sys/kernel/debug/tracing/dummy/filter1/enable'
    'echo 0 > /sys/kernel/debug/tracing/dummy/filter2/enable'
    'echo 0 > /sys/kernel/debug/tracing/dummy/test2/enable'
    'echo 0 > /sys/kernel/debug/tracing/dummy/test1/enable'
    "echo 0 > /sys/kernel/debug/tracing/tracing_on && echo '0' > /sys/kernel/debug/tracing/dummy/filter1/filter"
  )

  output=$(build_event_command_string '' 0)
  output=$(echo "$output" | sed -r 's/;/\n/g' | sed -r 's/^\s//g')
  IFS=$'\n' read -rd '' -a commands_array <<< "$output"
  compare_array_values expected_string_command_disable commands_array "$LINENO"

  # List
  events_hash=()
  events_hash=(["$dummy_path/test1"]=''
    ["$dummy_path/test2"]='')

  expected_list_commands='ls /sys/kernel/debug/tracing/dummy/test2 && ls /sys/kernel/debug/tracing/dummy/test1'
  output=$(build_event_command_string 1)
  assertTrue "($LINENO) Expected to find $expected_list_commands" '[[ "$output" == "$expected_list_commands" ]]'
}

#debug [--remote [REMOTE:PORT]] --cmd=\"COMMAND\"\n" \
function test_parser_debug_options()
{
  local event_str
  local fake_cmd='modprobe amdgpu'

  configurations['default_deploy_target']=3 # REMOTE

  # Validate remote option
  parser_debug_options --remote 'juca@localhost:33'
  assert_equals_helper 'Expected localhost' "$LINENO" "${remote_parameters['REMOTE_IP']}" 'localhost'

  assert_equals_helper 'Expected port 33' "$LINENO" "${remote_parameters['REMOTE_PORT']}" 33
  assert_equals_helper 'Expected user' "$LINENO" "${remote_parameters['REMOTE_USER']}" 'juca'

  # Validate list option
  parser_debug_options --list
  assert_equals_helper 'Expected list' "$LINENO" "${options_values['LIST']}" 1

  parser_debug_options --list --event 'amdgpu_dm'
  assert_equals_helper 'Expected amdgpu_dm' "$LINENO" "${options_values['EVENT']}" 'amdgpu_dm'

  # Validate history option
  parser_debug_options --history
  assert_equals_helper 'Expected history' "$LINENO" "${options_values['HISTORY']}" 1

  # Validate follow
  parser_debug_options --follow
  assert_equals_helper 'Expected follow' "$LINENO" "${options_values['FOLLOW']}" 1

  # Validate event
  event_str='amdgpu_dm:dc_something[x>3]'
  parser_debug_options --event "$event_str"
  assert_equals_helper 'Expected event' "$LINENO" "${options_values['EVENT']}" "$event_str"

  # Validate disable event
  parser_debug_options --event "$event_str" --disable
  assert_equals_helper 'Expected event' "$LINENO" "${options_values['DISABLE']}" 1

  # Validate disable event
  parser_debug_options --event "$event_str" --cmd "$fake_cmd"
  assert_equals_helper 'Expected event' "$LINENO" "${options_values['CMD']}" "$fake_cmd"

  # Check local option
  parser_debug_options --local --event "$event_str" --disable
  assert_equals_helper 'Expected event' "$LINENO" "${options_values['TARGET']}" 2

  # Check test_mode
  parser_debug_options test_mode
  assert_equals_helper 'Expected event' "$LINENO" "${options_values['TEST_MODE']}" 'TEST_MODE'

  # Validate dmesg
  parser_debug_options --dmesg
  assert_equals_helper 'Expected dmesg' "$LINENO" "${options_values['DMESG']}" 1

}

function test_dmesg_debug()
{
  local output
  local expected_cmd
  local std_dmesg='dmesg --human --color=always'
  local std_ssh='ssh -p 3333 juca@127.0.0.1'

  # Basic behavior
  output=$(dmesg_debug 2 'TEST_MODE' '' '' '')
  expected_cmd="$std_dmesg --nopager"
  assert_equals_helper 'Expected dmesg command' "$LINENO" "$expected_cmd" "$output"

  output=$(dmesg_debug 3 'TEST_MODE' '' '' '')
  expected_cmd="$std_ssh sudo \"$std_dmesg --nopager\""
  assert_equals_helper 'Expected dmesg command' "$LINENO" "$expected_cmd" "$output"

  output=$(dmesg_debug 3 'TEST_MODE' '' 1 '')
  expected_cmd="$std_ssh sudo \"$std_dmesg --follow\""
  assert_equals_helper '[remote] Expected to find follow param' "$LINENO" "$expected_cmd" "$output"

  output=$(dmesg_debug 2 'TEST_MODE' '' 1 '')
  expected_cmd="$std_dmesg --follow"
  assert_equals_helper '[local] Expected to find follow param' "$LINENO" "$expected_cmd" "$output"

  # Check history

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  mkdir 'kw_debug'

  output=$(dmesg_debug 2 'TEST_MODE' 'kw_debug' '' '')
  expected_cmd="$std_dmesg --nopager | tee kw_debug/dmesg"
  assert_equals_helper '[local] We expected a log file' "$LINENO" "$expected_cmd" "$output"

  output=$(dmesg_debug 2 'TEST_MODE' 'kw_debug' 1 '')
  expected_cmd="$std_dmesg --follow | tee kw_debug/dmesg"
  assert_equals_helper '[local] Log file with follow' "$LINENO" "$expected_cmd" "$output"

  # Check if was created a dmesg file
  assertTrue "($LINENO) Expected to find kw_debug/dmesg file" '[[ -f "$PWD/kw_debug/dmesg" ]]'

  output=$(dmesg_debug 3 'TEST_MODE' 'kw_debug' 1 '')
  expected_cmd="$std_ssh sudo \"$std_dmesg --follow\" | tee kw_debug/dmesg"
  assert_equals_helper '[remote] Log file created' "$LINENO" "$expected_cmd" "$output"

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

invoke_shunit
