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
    printf '%s\n' "${events_hash[*]}"
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
    printf '%s\n' "${events_hash[*]}"
  )
  array_of_values=("${events_hash[*]}")
  compare_array_values expected_multiple_filters array_of_values "$LINENO"

  events_hash=()
  convert_event_syntax_to_sys_path_hash "$no_specific_event"
  output=$(
    IFS=$'\n'
    printf '%s\n' "${!events_hash[*]}"
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
    printf '%s\n' "${!events_hash[*]}"
  )
  assertEquals "($LINENO) Wrong syntax:" "$output" ''
  assertEquals "($LINENO) Return error:" "$ret" 22

  events_hash=()
  convert_event_syntax_to_sys_path_hash ':'
  ret="$?"
  output=$(
    IFS=$'\n'
    printf '%s\n' "${!events_hash[*]}"
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
    "printf '%s\n' 'x > 42' > /sys/kernel/debug/tracing/dummy/filter1/filter"
    "printf '%s\n' 'x < 42' > /sys/kernel/debug/tracing/dummy/filter2/filter"
    "printf '%s\n' 1 > /sys/kernel/debug/tracing/dummy/filter1/enable"
    "printf '%s\n' 1 > /sys/kernel/debug/tracing/dummy/filter2/enable"
    "printf '%s\n' 1 > /sys/kernel/debug/tracing/dummy/test2/enable"
    "printf '%s\n' 1 > /sys/kernel/debug/tracing/dummy/test1/enable"
    "printf '%s\n' 1 > /sys/kernel/debug/tracing/dummy/test1/enable && printf '%s\n' 1 > /sys/kernel/debug/tracing/tracing_on"
  )

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  output=$(build_event_command_string '')
  output=$(printf '%s\n' "$output" | sed -r 's/;/\n/g' | sed -r 's/^\s//g')
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
    "printf '%s\n' '0' > /sys/kernel/debug/tracing/dummy/filter1/filter"
    "printf '%s\n' '0' > /sys/kernel/debug/tracing/dummy/filter2/filter"
    "printf '%s\n' '0' > /sys/kernel/debug/tracing/dummy/test2/filter"
    "printf '%s\n' '0' > /sys/kernel/debug/tracing/dummy/test1/filter"
    "printf '%s\n' 0 > /sys/kernel/debug/tracing/dummy/filter1/enable"
    "printf '%s\n' 0 > /sys/kernel/debug/tracing/dummy/filter2/enable"
    "printf '%s\n' 0 > /sys/kernel/debug/tracing/dummy/test2/enable"
    "printf '%s\n' 0 > /sys/kernel/debug/tracing/dummy/test1/enable"
    "printf '%s\n' 0 > /sys/kernel/debug/tracing/tracing_on && printf '%s\n' '0' > /sys/kernel/debug/tracing/dummy/filter1/filter"
  )

  output=$(build_event_command_string '' 0)
  output=$(printf '%s\n' "$output" | sed -r 's/;/\n/g' | sed -r 's/^\s//g')
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

  # Validate ftrace
  parser_debug_options --ftrace
  assert_equals_helper 'Expected ftrace failure' "$LINENO" "$?" 22

  parser_debug_options --list --ftrace
  assert_equals_helper 'Expected ftrace failure' "$LINENO" "$?" 22
}

function test_ftrace_list()
{
  local output
  local expected_cmd

  declare -a expected_cmd=(
    '1. hwlat'
    '2. blk'
    '3. mmiotrace'
    '4. function_graph'
    '5. wakeup_dl'
    '6. wakeup_rt'
    '7. wakeup'
    '8. function'
    '9. nop'
  )

  # Let's overwrite cmd_manager behavior temporarily
  function cmd_manager()
  {
    printf '%s\n' 'hwlat blk mmiotrace function_graph wakeup_dl wakeup_rt wakeup function nop'
  }

  function cmd_remotely()
  {
    printf '%s\n' 'hwlat blk mmiotrace function_graph wakeup_dl wakeup_rt wakeup function nop'
  }

  # Local
  output=$(ftrace_list 2)
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # Remote
  output=$(ftrace_list 3)
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # VM
  output=$(ftrace_list 1)
  declare -a expected_cmd=(
    'Target is a VM'
    '1. hwlat'
    '2. blk'
    '3. mmiotrace'
    '4. function_graph'
    '5. wakeup_dl'
    '6. wakeup_rt'
    '7. wakeup'
    '8. function'
    '9. nop'
  )
  compare_command_sequence 'expected_cmd' "$output" "$LINENO"

  # Let's reload cmd_manager
  source 'src/kwlib.sh' --source-only
  source 'src/remote.sh' --source-only
}

# Mock function
function get_today_info()
{
  printf 'kw_2021_10_22-07_34_07'
}

function test_dmesg_debug()
{
  local output
  local expected_cmd
  local std_dmesg='dmesg --human --color=always'
  local std_ssh='ssh -p 3333 juca@127.0.0.1'
  local igt_cmd_sample='$HOME/igt-gpu-tools/build/tests/kms_plane --run-subtest plane-position-covered'
  local cmd_intermediary

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

  # Check cmd option
  # Local
  # --cmd "SOMETHING"
  output=$(dmesg_debug 2 'TEST_MODE' '' '' "$igt_cmd_sample")
  expected_cmd="dmesg --clear && $igt_cmd_sample && $std_dmesg --nopager"
  assert_equals_helper '[local] dmesg with CMD' "$LINENO" "$expected_cmd" "$output"

  # --cmd "SOMETHING" --history
  output=$(dmesg_debug 2 'TEST_MODE' 'kw_debug' '' "$igt_cmd_sample")
  expected_cmd="dmesg --clear && $igt_cmd_sample && $std_dmesg --nopager | tee kw_debug/dmesg"
  assert_equals_helper '[local] dmesg with CMD' "$LINENO" "$expected_cmd" "$output"

  # --cmd "SOMETHING" --follow --history
  output=$(dmesg_debug 2 'TEST_MODE' 'kw_debug' 1 "$igt_cmd_sample")
  cmd_intermediary="screen -dmS kw_2021_10_22-07_34_07 $igt_cmd_sample"
  expected_cmd="dmesg --clear && $cmd_intermediary && $std_dmesg --follow | tee kw_debug/dmesg"
  assert_equals_helper '[local] dmesg with CMD' "$LINENO" "$expected_cmd" "$output"

  # Remote
  # --remote --cmd "SOMETHING"
  output=$(dmesg_debug 3 'TEST_MODE' '' '' "$igt_cmd_sample")
  expected_cmd="$std_ssh sudo \"dmesg --clear && $igt_cmd_sample && $std_dmesg --nopager\""
  assert_equals_helper '[remote]' "$LINENO" "$expected_cmd" "$output"

  # --remote --cmd "SOMETHING" --history
  output=$(dmesg_debug 3 'TEST_MODE' 'kw_debug' '' "$igt_cmd_sample")
  expected_cmd="$std_ssh sudo \"dmesg --clear && $igt_cmd_sample && $std_dmesg --nopager\" | tee kw_debug/dmesg"
  assert_equals_helper '[remote]' "$LINENO" "$expected_cmd" "$output"

  # --cmd "SOMETHING" --follow --history
  output=$(dmesg_debug 3 'TEST_MODE' 'kw_debug' 1 "$igt_cmd_sample")
  cmd_intermediary="screen -dmS kw_2021_10_22-07_34_07 $igt_cmd_sample"
  expected_cmd="$std_ssh sudo \"dmesg --clear && $cmd_intermediary && $std_dmesg --follow\" | tee kw_debug/dmesg"
  assert_equals_helper '[remote]' "$LINENO" "$expected_cmd" "$output"

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

function test_stop_debug()
{
  local output
  local -a expected_cmd_sequence
  local std_ssh='ssh -p 3333 juca@127.0.0.1'

  #Not a follow option
  output=$(stop_debug 'TEST_MODE')
  assert_equals_helper 'We should return 0' "$LINENO" '' "$output"

  # Event: Local
  options_values['DMESG']=''
  options_values['FOLLOW']=1
  options_values['EVENT']=1
  options_values['TARGET']=2
  output=$(stop_debug 'TEST_MODE')

  declare -a expected_cmd_sequence=(
    'Disabling events in the target machine : 1'
    "sudo bash -c \"printf '%s\n' 0 > /sys/kernel/debug/tracing/tracing_on\""
  )
  compare_command_sequence 'expected_cmd_sequence' "$output" "$LINENO"

  # Event: Remote
  options_values['TARGET']=3
  output=$(stop_debug 'TEST_MODE')

  declare -a expected_cmd_sequence=(
    'Disabling events in the target machine : 1'
    "$std_ssh sudo \"printf '%s\n' 0 > /sys/kernel/debug/tracing/tracing_on\""
  )
  compare_command_sequence 'expected_cmd_sequence' "$output" "$LINENO"

  # Dmesg: Local
  options_values['EVENT']=''
  options_values['DMESG']=1
  options_values['TARGET']=2
  interrupt_data_hash['DMESG']="screen -S XPTO-LA -X quit > /dev/null"

  output=$(stop_debug 'TEST_MODE')
  assert_equals_helper 'Stop local dmesg' "$LINENO" "${interrupt_data_hash['DMESG']}" "$output"

  # Dmesg: Remote
  options_values['TARGET']=3
  interrupt_data_hash['DMESG']="screen -S XPTO-LA -X quit > /dev/null"
  external_cmd="$std_ssh sudo \"${interrupt_data_hash['DMESG']}\""

  output=$(stop_debug 'TEST_MODE')
  assert_equals_helper 'Stop remote dmesg' "$LINENO" "$external_cmd" "$output"
}

invoke_shunit
