#!/bin/bash

include './src/debug.sh'
include './tests/utils.sh'

original_dir="$PWD"
default_ssh='ssh -p 3333 juca@127.0.0.1'
debug_on="printf '%s\n' 1 > /sys/kernel/debug/tracing/tracing_on"
debug_off="printf '%s\n' 0 > /sys/kernel/debug/tracing/tracing_on"
event_path='/sys/kernel/debug/tracing/events'
trace_pipe_path='/sys/kernel/debug/tracing/trace_pipe'
disable_amdgpu_dm_event="printf '%s\n' 0 > $event_path/amdgpu_dm/enable"
enable_amdgpu_dm_event="printf '%s\n' 1 > $event_path/amdgpu_dm/enable"
disable_amdgpu_dm_filter="printf '0\n' > $event_path/amdgpu_dm/filter"
igt_cmd_sample='$HOME/igt-gpu-tools/build/tests/kms_plane --run-subtest plane-position-covered'

function setUp
{
  # Default config
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
  if [[ -d "$SHUNIT_TMPDIR" ]]; then
    rm -rf "${SHUNIT_TMPDIR}"
  fi
}

# Mock function
function get_today_info()
{
  printf 'kw_2021_10_22-07_34_07'
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
  assert_equals_helper 'Return error:' "($LINENO)" "$ret" 22
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
  assert_equals_helper 'Wrong syntax:' "($LINENO)" "$output" ''
  assert_equals_helper 'Return error:' "($LINENO)" "$ret" 22

  events_hash=()
  convert_event_syntax_to_sys_path_hash ':'
  ret="$?"
  output=$(
    IFS=$'\n'
    printf '%s\n' "${!events_hash[*]}"
  )
  assert_equals_helper 'Wrong syntax:' "($LINENO)" "$output" ''
  assert_equals_helper 'Return error:' "($LINENO)" "$ret" 22
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
    "printf 'nop' > $FTRACE_CURRENT_PATH"
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
function test_parser_debug_options_remote()
{
  # 1) Parser remote without config file.
  parser_debug_options --remote 'juca@localhost:33'
  assert_equals_helper 'Expected localhost' "$LINENO" "${remote_parameters['REMOTE_IP']}" 'localhost'
  assert_equals_helper 'Expected port 33' "$LINENO" "${remote_parameters['REMOTE_PORT']}" 33
  assert_equals_helper 'Expected user' "$LINENO" "${remote_parameters['REMOTE_USER']}" 'juca'

  # 2) Parser remote with config file

  # Setup folder to emulate kw config
  mkdir -p "${SHUNIT_TMPDIR}/.kw"
  cp "${KW_REMOTE_SAMPLES_DIR}/remote.config" "${SHUNIT_TMPDIR}/.kw"

  # Execute function inside emulate kw config
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # 2.1) We have a config file, with origin set as host, and user request it
  parser_debug_options --remote 'origin'
  assert_equals_helper 'Expected origin' "$LINENO" "${remote_parameters['REMOTE_FILE_HOST']}" 'origin'

  # 2.2) We have a config file, with --remote NAME, but we don't have NAME in the
  #      config file.
  parser_debug_options --remote 'debian-test-dns'
  assert_equals_helper 'Expected empty' "$LINENO" "${remote_parameters['REMOTE_FILE_HOST']}" ''
  assert_equals_helper 'Expected debian-test-dns' "$LINENO" "${remote_parameters['REMOTE_IP']}" 'debian-test-dns'

  parser_debug_options --remote '192.0.2.0'
  assert_equals_helper 'Expected 192.0.2.0' "$LINENO" "${remote_parameters['REMOTE_IP']}" '192.0.2.0'

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

function test_parser_debug_options()
{
  local event_str
  local fake_cmd='modprobe amdgpu'

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

  ftrace_str='something:another,thing'
  parser_debug_options --ftrace="$ftrace_str"
  assert_equals_helper 'Expected ftrace syntax' "$LINENO" "${options_values['FTRACE']}" "$ftrace_str"

  ftrace_str='something:'
  parser_debug_options --ftrace="$ftrace_str"
  assert_equals_helper 'Expected ftrace setup' "$LINENO" "${options_values['FTRACE']}" "$ftrace_str"

  ftrace_str='something:  la, llu,    xpto'
  parser_debug_options --ftrace="$ftrace_str"
  assert_equals_helper 'Expected ftrace string' "$LINENO" "${options_values['FTRACE']}" "$ftrace_str"
}

function test_build_ftrace_command_string()
{
  local output
  local expected_cmd
  local disable_trace="printf '0' > /sys/kernel/debug/tracing/tracing_on"
  local enable_trace="printf '1' > /sys/kernel/debug/tracing/tracing_on"
  local current_tracer='/sys/kernel/debug/tracing/current_tracer'
  local ftracer_filter='/sys/kernel/debug/tracing/set_ftrace_filter'

  # function_graph
  output=$(build_ftrace_command_string 'function_graph')
  expected_cmd="$disable_trace && printf '%s' 'function_graph' > $current_tracer && $enable_trace"
  assert_equals_helper 'Expected to enable function_graph' "$LINENO" "$output" "$expected_cmd"

  output=$(build_ftrace_command_string '    function_graph        ')
  assert_equals_helper 'Expected to enable function_graph' "$LINENO" "$output" "$expected_cmd"

  # function_graph: -> Should fail
  output=$(build_ftrace_command_string 'function_graph:  ')
  ret="$?"
  assert_equals_helper 'Expected a failure' "$LINENO" 22 "$ret"

  # function_graph:, -> Should fail
  output=$(build_ftrace_command_string 'function_graph:,')
  ret="$?"
  assert_equals_helper 'Expected a failure' "$LINENO" 22 "$ret"

  # function_graph:amdgpu_dm*
  output=$(build_ftrace_command_string 'function_graph:amdgpu_dm*')
  expected_cmd="$disable_trace && printf '%s' 'function_graph' > $current_tracer"
  expected_cmd+=" && printf '%s' 'amdgpu_dm*' >> $ftracer_filter"
  expected_cmd+=" && $enable_trace"
  assert_equals_helper 'Expected amdgpu_dm filters' "$LINENO" "$output" "$expected_cmd"

  # function_graph:amdgpu_dm*,dc_*,drm_test
  output=$(build_ftrace_command_string 'function_graph:amdgpu_dm*,dc_*,drm_test')
  expected_cmd="$disable_trace && printf '%s' 'function_graph' > $current_tracer"
  expected_cmd+=" && printf '%s' 'amdgpu_dm*' >> $ftracer_filter"
  expected_cmd+=" && printf '%s' 'dc_*' >> $ftracer_filter"
  expected_cmd+=" && printf '%s' 'drm_test' >> $ftracer_filter"
  expected_cmd+=" && $enable_trace"
  assert_equals_helper 'Expected to find multiple filters' "$LINENO" "$output" "$expected_cmd"

  # function_graph: amdgpu_dm*,   dc_*
  output=$(build_ftrace_command_string 'function_graph: amdgpu_dm*,   dc_*')
  expected_cmd="$disable_trace && printf '%s' 'function_graph' > $current_tracer"
  expected_cmd+=" && printf '%s' 'amdgpu_dm*' >> $ftracer_filter"
  expected_cmd+=" && printf '%s' 'dc_*' >> $ftracer_filter"
  expected_cmd+=" && $enable_trace"
  assert_equals_helper 'Expected to find multiple filters' "$LINENO" "$output" "$expected_cmd"

  # Empty
  output=$(build_ftrace_command_string '')
  ret="$?"
  assert_equals_helper 'Expected a failure' "$LINENO" 22 "$ret"

  # Disable
  output=$(build_ftrace_command_string 'function_graph:amdgpu_dm*' 1)
  expected_cmd="$disable_trace && printf '' > $ftracer_filter && printf 'nop' > $FTRACE_CURRENT_PATH"
  assert_equals_helper 'Expected disable command' "$LINENO" "$output" "$expected_cmd"
}

function test_ftrace_debug()
{
  local output
  local expected_cmd
  local expected_cmd_base
  local disable_trace="printf '0' > /sys/kernel/debug/tracing/tracing_on"
  local enable_trace="printf '1' > /sys/kernel/debug/tracing/tracing_on"
  local current_tracer='/sys/kernel/debug/tracing/current_tracer'
  local ftracer_filter='/sys/kernel/debug/tracing/set_ftrace_filter'
  local trace_pipe='/sys/kernel/debug/tracing/trace_pipe'
  local default_ssh='ssh -p 3333 juca@127.0.0.1 sudo'
  local screen_command
  local screen_id

  # Local machine
  output=$(ftrace_debug 2 'TEST_MODE' 'function_graph:amdgpu_dm*')
  expected_cmd="$disable_trace && printf '%s' 'function_graph' > $current_tracer"
  expected_cmd+=" && printf '%s' 'amdgpu_dm*' >> $ftracer_filter && $enable_trace"
  assert_equals_helper 'Expected command' "$LINENO" "$output" "$expected_cmd"

  expected_cmd_base="$expected_cmd"

  # Remote
  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='3333'
  remote_parameters['REMOTE_USER']='juca'

  output=$(ftrace_debug 3 'TEST_MODE' 'function_graph:amdgpu_dm*')
  expected_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"$expected_cmd_base\""
  assert_equals_helper 'Expected remote command' "$LINENO" "$output" "$expected_cmd"

  # Follow
  output=$(ftrace_debug 3 'TEST_MODE' 'function_graph:amdgpu_dm*' '' 1)
  expected_cmd="ssh -p 3333 juca@127.0.0.1 sudo \"$expected_cmd_base && cat $trace_pipe\""
  assert_equals_helper 'Expected follow' "$LINENO" "$output" "$expected_cmd"

  # History
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  mkdir 'kw_debug'

  output=$(ftrace_debug 2 'TEST_MODE' 'function_graph: amdgpu_dm*' 'kw_debug')
  expected_cmd="$expected_cmd_base | tee kw_debug/ftrace"
  assert_equals_helper '[local] We expected a log file' "$LINENO" "$expected_cmd" "$output"
  # Check if was created a ftrace file
  assertTrue "($LINENO) Expected to find kw_debug/ftrace file" '[[ -f "$PWD/kw_debug/ftrace" ]]'

  output=$(ftrace_debug 2 'TEST_MODE' 'function_graph: amdgpu_dm*' 'kw_debug' 1)
  expected_cmd="$expected_cmd_base && cat $trace_pipe | tee kw_debug/ftrace"
  assert_equals_helper '[local] We expected a log file' "$LINENO" "$expected_cmd" "$output"

  output=$(ftrace_debug 3 'TEST_MODE' 'function_graph: amdgpu_dm*' 'kw_debug' 1)
  expected_cmd="$default_ssh \"$expected_cmd_base && cat $trace_pipe\" | tee kw_debug/ftrace"
  assert_equals_helper '[remote] We expected a log file' "$LINENO" "$expected_cmd" "$output"

  # Test cmd option; unfortunately, it is a horrible command sequence.
  expected_cmd="$expected_cmd_base"
  screen_id='kw_2021_10_22-07_34_07' # We mocked this value
  screen_command="screen -L -Logfile ~/$screen_id -dmS $screen_id cat $trace_pipe"
  expected_cmd+=" && $screen_command && ./root/something && $disable_trace"
  expected_cmd+=" && printf '' > /sys/kernel/debug/tracing/set_ftrace_filter"
  expected_cmd+=" && printf 'nop' > $FTRACE_CURRENT_PATH"
  screen_command="screen -S $screen_id -X quit > /dev/null"
  expected_cmd+=" && $screen_command | tee kw_debug/ftrace"
  USER='MOCK'
  declare -a expected_cmd_seq=(
    "$expected_cmd"
    "sudo cp /root/kw_2021_10_22-07_34_07 kw_debug/ftrace && sudo chown $USER:$USER kw_debug/ftrace"
  )
  output=$(ftrace_debug 2 'TEST_MODE' 'function_graph:amdgpu_dm*' 'kw_debug' '' './root/something')
  compare_command_sequence '' "$LINENO" 'expected_cmd_seq' "$output"

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
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
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Remote
  output=$(ftrace_list 3)
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

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
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Let's reload cmd_manager
  source 'src/kwlib.sh' --source-only
  source 'src/remote.sh' --source-only
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

  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='3333'
  remote_parameters['REMOTE_USER']='juca'

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

function test_event_debug()
{
  local expected_cmd="$default_ssh sudo \" $enable_amdgpu_dm_event && $debug_on\""
  local ret

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  mkdir 'kw_debug'

  # Failure case
  output=$(event_debug 3 'TEST_MODE' 'lala;:')
  ret="$?"
  assert_equals_helper 'Invalid syntax' "$LINENO" "$ret" 22

  # List
  output=$(event_debug 3 'TEST_MODE' 'amdgpu_dm' '' '' '' 1)
  ret="$?"
  assert_equals_helper 'List' "$LINENO" "$ret" 0

  output=$(event_debug 2 'TEST_MODE' 'amdgpu_dm' '' '' '' 1)
  ret="$?"
  assert_equals_helper 'List' "$LINENO" "$ret" 0

  # Simple case
  output=$(event_debug 3 'TEST_MODE' 'amdgpu_dm')
  assert_equals_helper 'Expected to enable amdgpu_dm' "$LINENO" "$expected_cmd" "$output"

  expected_cmd="sudo bash -c \" $enable_amdgpu_dm_event && $debug_on\""
  output=$(event_debug 2 'TEST_MODE' 'amdgpu_dm')
  assert_equals_helper 'Expected to enable amdgpu_dm' "$LINENO" "$expected_cmd" "$output"

  # Follow
  expected_cmd="$default_ssh sudo \" $enable_amdgpu_dm_event && $debug_on && cat $trace_pipe_path\""
  output=$(event_debug 3 'TEST_MODE' 'amdgpu_dm' '' 1)
  assert_equals_helper 'Expected to follow amdgpu_dm' "$LINENO" "$expected_cmd" "$output"

  # Disable
  expected_cmd="$default_ssh sudo \"$debug_off && $disable_amdgpu_dm_filter; $disable_amdgpu_dm_event && printf 'nop' > $FTRACE_CURRENT_PATH\""
  output=$(event_debug 3 'TEST_MODE' 'amdgpu_dm' '' 1 '' '' 1)
  assert_equals_helper 'Expected to disable amdgpu_dm' "$LINENO" "$expected_cmd" "$output"

  # CMD
  # TODO: This is super ugly, let's rework this in the future
  expected_cmd="$enable_amdgpu_dm_event && $debug_on"
  expected_cmd+=" && screen -L -Logfile ~/kw_2021_10_22-07_34_07 -dmS kw_2021_10_22-07_34_07"
  expected_cmd+=" cat $trace_pipe_path && $igt_cmd_sample"
  expected_cmd+=" && $debug_off && $disable_amdgpu_dm_filter; $disable_amdgpu_dm_event"
  expected_cmd+=" && printf 'nop' > $FTRACE_CURRENT_PATH"
  expected_cmd+=" && screen -S kw_2021_10_22-07_34_07 -X quit"
  declare -a expected_cmd_seq=(
    "$default_ssh sudo \" $expected_cmd\" | tee kw_debug/event"
    "rsync --info=progress2 -e 'ssh -p 3333' juca@127.0.0.1:${HOME}/kw_2021_10_22-07_34_07 kw_debug/event -LrlptD --rsync-path='sudo rsync'"
  )

  output=$(event_debug 3 'TEST_MODE' 'amdgpu_dm' 'kw_debug' '' "$igt_cmd_sample")
  compare_command_sequence '' "$LINENO" 'expected_cmd_seq' "$output"

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
  local ftracer_filter='/sys/kernel/debug/tracing/set_ftrace_filter'
  local disable_trace="printf '0' > /sys/kernel/debug/tracing/tracing_on && printf '' > $ftracer_filter"
  local disable_cmd

  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='3333'
  remote_parameters['REMOTE_USER']='juca'

  #Not a follow option
  output=$(stop_debug 'TEST_MODE')
  assert_equals_helper 'We should return 0' "$LINENO" '' "$output"

  # Dmesg: Local
  options_values['EVENT']=''
  options_values['FTRACE']=''
  options_values['FOLLOW']=1
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

function test_reset_debug()
{
  local disable_cmd
  local std_ssh='ssh -p 3333 juca@127.0.0.1 sudo'
  local current_tracer='/sys/kernel/debug/tracing/current_tracer'
  local ftracer_filter='/sys/kernel/debug/tracing/set_ftrace_filter'
  local expected_cmd

  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='3333'
  remote_parameters['REMOTE_USER']='juca'

  disable_cmd="$debug_off && printf 'nop' > $current_tracer"
  disable_cmd+=" && printf '' > $ftracer_filter && printf '' > $trace_pipe_path"
  disable_cmd+=" && lsof 2>/dev/null | grep $trace_pipe_path | tr -s ' ' | cut -d ' ' -f2 | xargs -I{} kill -9 {}"

  # Local
  expected_cmd="sudo bash -c \"$disable_cmd\""
  output=$(reset_debug 2 'TEST_MODE')
  assert_equals_helper 'Local reset' "$LINENO" "$expected_cmd" "$output"

  # Remote
  expected_cmd="$std_ssh \"$disable_cmd\""
  output=$(reset_debug 3 'TEST_MODE')
  assert_equals_helper 'Remote reset' "$LINENO" "$expected_cmd" "$output"
}

invoke_shunit
