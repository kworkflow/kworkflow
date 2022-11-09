# Kw provides a set of mechanisms for making it easy to use some of the kernels
# debug options such as events and ftrace. This file comprises a rich set of
# functions to deal with this activity.

include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kw_time_and_date.sh"
include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/remote.sh"

# Hash containing user options
declare -gA options_values
declare -gA events_hash
declare -gA interrupt_data_hash

declare -gr TRACING_BASE_PATH='/sys/kernel/debug/tracing'
declare -gr TRACING_ON="$TRACING_BASE_PATH/tracing_on"
declare -gr EVENT_BASE_PATH="$TRACING_BASE_PATH/events"
declare -gr TRACE_PIPE="$TRACING_BASE_PATH/trace_pipe"
declare -gr FTRACE_CURRENT_PATH="$TRACING_BASE_PATH/current_tracer"
declare -gr FTRACE_FILTER="$TRACING_BASE_PATH/set_ftrace_filter"

declare -gr KW_DEBUG='kw_debug'

# Manager function responsible for getting all user options and taking action
# on which procedure should be invoked.
#
# Return:
# Return 0 in a normal case or an errno code.
function debug_main()
{
  local remote
  local flag='SILENT'
  local user_cmd=''
  local test_mode=''
  local target=''
  local event=''
  local ftrace=''
  local dmesg=''
  local user_cmd=''
  local keep_history=''
  local disable=''
  local list=''
  local follow=''
  local reset=''
  local base_log_path

  parser_debug_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    debug_help
    return 22
  fi

  test_mode="${options_values['TEST_MODE']}"
  target="${options_values['TARGET']}"
  event="${options_values['EVENT']}"
  ftrace="${options_values['FTRACE']}"
  dmesg="${options_values['DMESG']}"
  user_cmd="${options_values['CMD']}"
  keep_history="${options_values['HISTORY']}"
  disable="${options_values['DISABLE']}"
  list="${options_values['LIST']}"
  follow="${options_values['FOLLOW']}"
  reset="${options_values['RESET']}"

  # Base path for saving log files
  base_log_path=$(prepare_log_database "$keep_history")

  signal_manager 'stop_debug' || warning 'Was not able to set signal handler'

  if [[ "$target" == "$REMOTE_TARGET" ]]; then
    # Check connection before try to work with remote
    is_ssh_connection_configured "$flag"
    if [[ "$?" != 0 ]]; then
      ssh_connection_failure_message
      exit 101 # ENETUNREACH
    fi
  fi

  # --list change the behaviour inside event, for this reason let's ignore
  # list if event is set
  if [[ -n "$list" && -z "$event" ]]; then
    list_debug "$target" "$list" "$flag"
    return
  fi

  if [[ -n "$reset" ]]; then
    reset_debug "$target"
    return "$?"
  fi

  if [[ -n "$event" ]]; then
    event_debug "$target" "$flag" "$event" "$base_log_path" "$follow" "$user_cmd" "$list" "$disable"
    return "$?"
  fi

  if [[ -n "$dmesg" ]]; then
    dmesg_debug "$target" "$flag" "$base_log_path" "$follow" "$user_cmd"
    return "$?"
  fi

  if [[ -n "$ftrace" ]]; then
    ftrace_debug "$target" "$flag" "$ftrace" "$base_log_path" "$follow" "$user_cmd" "$list" "$disable"
    return "$?"
  fi

  if [[ "$test_mode" == 'TEST_MODE' ]]; then
    printf '%s\n' "${remote_parameters['REMOTE_IP']} ${remote_parameters['REMOTE_PORT']} $target $event $user_cmd"
    return 0
  fi
}

# List debug options for ftrace and event.
#
# @target: Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), or 3 (REMOTE_TARGET)
# @list_target: List debug options
# @flag: How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Return 22 in case of invalid option
function list_debug()
{
  local target="$1"
  local list_target="$2"
  local flag="$3"
  local char_repetition
  local specific_event

  # List all options
  if [[ "$list_target" == 1 ]]; then
    say "Ftrace options:"
    ftrace_list "$target" "$flag"
    say "Event options:"
    event_debug "$target" "$flag" '' '' '' '' 1
    return 0
  fi

  char_repetition=$(str_count_char_repetition "$list_target" ':')
  if [[ "$char_repetition" -ge 1 ]]; then
    specific_event=$(printf '%s' "$list_target" | cut -d ':' -f2)
    list_target=$(printf '%s' "$list_target" | cut -d ':' -f1)
  fi

  case "$list_target" in
    events)
      event_debug "$target" "$flag" "$specific_event" '' '' '' 1
      ;;
    ftrace)
      ftrace_list "$target" "$flag"
      ;;
    *)
      complain "Invalid option: $list_target. Do you mean events or ftrace?"
      return 22 # EINVAL
      ;;
  esac
}

# When users cancel some of the debug operations, we might have a situation
# where we accidentally leave some configurations set, which may cause problems
# when trying to use the debug option a second time. In particular, it is
# common to have a hung process in the trace_pipe file. This function is
# responsible for resetting and killing any debug option process.
#
# @target: Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), or 3 (REMOTE_TARGET)
# @flag: How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
function reset_debug()
{
  local target="$1"
  local flag="$2"
  local reset_cmd
  local kill_hang_cmd

  # Note that event already clean part of the ftrace files, except by the
  # ftrace filter
  reset_cmd=$(build_event_command_string '' 0)
  reset_cmd+=" && printf '' > $FTRACE_FILTER"

  # We might have a hang process on trace_pipe, let's make sure we kill it
  kill_hang_cmd="lsof 2>/dev/null | grep $TRACE_PIPE | tr -s ' ' | cut -d ' ' -f2"
  kill_hang_cmd+=" | xargs -I{} kill -9 {}"

  # Make sure the we clean trace pipe
  reset_cmd+=" && printf '' > $TRACING_BASE_PATH/trace_pipe"
  reset_cmd+=" && $kill_hang_cmd"

  case "$target" in
    2) # LOCAL
      cmd_manager "$flag" "sudo bash -c \"$reset_cmd\""
      ;;
    3 | 1) # REMOTE && VM
      local remote="${remote_parameters['REMOTE_IP']}"
      local port="${remote_parameters['REMOTE_PORT']}"
      local user="${remote_parameters['REMOTE_USER']}"

      if [[ "$target" == 1 ]]; then
        say 'Target is a VM'
        # TODO: We should check if the VM is up and running
      fi

      cmd_remotely "$reset_cmd" "$flag" "$remote" "$port" "$user"
      ;;
  esac
}

# This function is responsible for handling dmesg logs.
#
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
# @keep_history: If set to a value different from empty or 0, it will create a
# @follow: Follow log in real-time.
# @user_cmd: User specific command.
#
# Return:
# In case of an error, returns an errno code.
function dmesg_debug()
{
  local target="$1"
  local flag="$2"
  local base_log_path="$3"
  local follow="$4"
  local user_cmd="$5"
  local std_dmesg_cmd='dmesg --human --color=always'
  local save_following_log=''
  local redirect_mode=''
  local cmd
  local user_cmd
  local screen_id
  local screen_cmd

  if [[ -n "$follow" ]]; then
    cmd="$std_dmesg_cmd --follow"
  else
    cmd="$std_dmesg_cmd --nopager"
  fi

  # Capture data
  if [[ -n "$base_log_path" ]]; then
    touch "$base_log_path/dmesg"
    printf '\n' > "$base_log_path/dmesg"
    save_following_log="$base_log_path/dmesg"
  fi

  # User command
  if [[ -n "$user_cmd" ]]; then
    cmd="dmesg --clear && $user_cmd && $cmd"

    if [[ -n "$follow" ]]; then
      screen_id=$(get_today_info '+kw_%Y_%m_%d-%H_%M_%S')
      screen_cmd="screen -dmS $screen_id $user_cmd"
      interrupt_data_hash['DMESG']="screen -S $screen_id -X quit > /dev/null"
      cmd="dmesg --clear && $screen_cmd && $std_dmesg_cmd --follow"
    fi
  fi

  case "$target" in
    2) # LOCAL
      [[ -n "$save_following_log" ]] && redirect_mode='KW_REDIRECT_MODE'
      cmd_manager "$flag" "$cmd" "$redirect_mode" "$save_following_log"
      ;;
    3 | 1) # REMOTE && VM
      if [[ "$target" == 1 ]]; then
        say 'Target is a VM'
        # TODO: We should check if the VM is up and running
      fi

      cmd_remotely "$cmd" "$flag" '' '' '' '' "$save_following_log"
      ;;
  esac
}

# This function manages the trace event.
#
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
# @event: Raw string with event syntax
# @keep_history: If set to a value different from empty or 0, it will create a
# directory structure for keeping the trace history. Otherwise, it will create
# a single file per trace type.
# @follow: Follow log in real-time.
# @user_cmd: User specific command.
# @list: List events.
#
# Return:
# In case of an error, returns an errno code.
function event_debug()
{
  local target="$1"
  local flag="$2"
  local event="$3"
  local base_log_path="$4"
  local follow="$5"
  local user_cmd="$6"
  local list="$7"
  local disable="$8"
  local redirect_mode=''
  local base_log_path
  local disable_cmd
  local command
  local screen_cmd
  local screen_nick
  local screen_end_cmd
  local save_following_log
  local ret

  convert_event_syntax_to_sys_path_hash "$event"
  ret="$?"
  if [[ "$ret" -gt 0 ]]; then
    complain "Invalid syntax at '$event'"
    return "$ret"
  fi

  # Build command
  disable_cmd=$(build_event_command_string '' 0)
  command=$(build_event_command_string '')

  # Capture data
  if [[ -n "$base_log_path" ]]; then
    touch "$base_log_path/event"
    printf '\n' > "$base_log_path/event"
    save_following_log="$base_log_path/event"
  fi

  if [[ "$follow" == 1 ]]; then
    command="$command && cat $TRACE_PIPE"
  fi

  if [[ -n "$user_cmd" && -z "$disable" ]]; then
    save_following_log="$base_log_path/event"
    screen_nick=$(get_today_info '+kw_%Y_%m_%d-%H_%M_%S')
    screen_cmd="screen -L -Logfile ~/$screen_nick -dmS $screen_nick cat $TRACE_PIPE"
    screen_end_cmd="screen -S $screen_nick -X quit"
    command="$command && $screen_cmd && $user_cmd && $disable_cmd && $screen_end_cmd"
  fi

  if [[ "$disable" == 1 ]]; then
    command="$disable_cmd"
  fi

  if [[ -n "$list" ]]; then
    command=$(build_event_command_string "$list")
  fi

  case "$target" in
    2) # LOCAL
      if [[ -n "$list" ]]; then
        flag=${flag:-'SILENT'}
        list_output=$(cmd_manager "$flag" "$save_following_log" "sudo bash -c \"$command\"")
        show_list "$list_output" "$event"
        return "$ret"
      fi

      [[ -n "$save_following_log" ]] && redirect_mode='KW_REDIRECT_MODE'
      cmd_manager "$flag" "sudo bash -c \"$command\"" "$redirect_mode" "$save_following_log"

      if [[ -n "$user_cmd" ]]; then
        command="sudo cp /root/$screen_nick $save_following_log && sudo chown $USER:$USER $save_following_log"
        cmd_manager "$flag" "$command"
      fi
      ;;
    3 | 1) # REMOTE && VM
      local remote="${remote_parameters['REMOTE_IP']}"
      local port="${remote_parameters['REMOTE_PORT']}"
      local user="${remote_parameters['REMOTE_USER']}"

      if [[ "$target" == 1 ]]; then
        say 'Target is a VM'
        # TODO: We should check if the VM is up and running
      fi

      if [[ -n "$list" ]]; then
        list_output=$(cmd_remotely "$command" "$flag" "$remote" "$port" "$user")
        show_list "$list_output" "$event"
        ret="$?"
        return "$ret"
      fi

      cmd_remotely "$command" "$flag" "$remote" "$port" "$user" '' "$save_following_log"

      # If we used --cmd, we need to retrieve the log
      if [[ -n "$user_cmd" ]]; then
        remote2host "$flag" "${HOME}/${screen_nick}" "$save_following_log"
      fi
      ;;
  esac

  return 0
}

# Function dedicated to handling how we capture the ftrace options and display
# them to our users.
#
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), or 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Output all data in a list format
function ftrace_list()
{
  local target="$1"
  local flag="$2"
  local raw_data=''
  local index=1
  local ret
  local cmd_list="cat $TRACING_BASE_PATH/available_tracers"

  case "$target" in
    2) # LOCAL
      raw_data=$(cmd_manager "$flag" "sudo -E $cmd_list")
      ret="$?"
      ;;
    3 | 1) # REMOTE && VM
      local remote="${remote_parameters['REMOTE_IP']}"
      local port="${remote_parameters['REMOTE_PORT']}"
      local user="${remote_parameters['REMOTE_USER']}"

      if [[ "$target" == 1 ]]; then
        say 'Target is a VM'
        # TODO: We should check if the VM is up and running
      fi

      raw_data=$(cmd_remotely "$cmd_list" "$flag" "$remote" "$port" "$user")
      ret="$?"
      ;;
  esac

  [[ "$ret" != 0 ]] && return "$ret"

  IFS=' ' read -r -a ftrace_options <<< "$raw_data"
  for ftrace_available in "${ftrace_options[@]}"; do
    printf ' %d. %s\n' "$index" "$ftrace_available"
    ((index++))
  done
}

# This is the function responsible for managing ftrace tasks.
#
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), or 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
# @ftrace_syntax: Raw string with event syntax
# @keep_history: If set to a value different from empty or 0, it will create a
# directory structure for keeping the trace history. Otherwise, it will create
# a single file per trace type.
# @follow: Follow log in real-time.
# @user_cmd: User specific command.
# @list: List events.
function ftrace_debug()
{
  local target="$1"
  local flag="$2"
  local ftrace_syntax="$3"
  local base_log_path="$4"
  local follow="$5"
  local user_cmd="$6"
  local list="$7"
  local disable="$8"
  local raw_list=''
  local save_following_log
  local redirect_mode
  local ret

  if [[ -n "$list" || "$ftrace_syntax" == 1 ]]; then
    ftrace_list "$target" "$flag"
    return "$?"
  fi

  # Build basic trace command
  cmd_ftrace=$(build_ftrace_command_string "$ftrace_syntax" "$disable")

  # Capture data
  if [[ -n "$base_log_path" ]]; then
    touch "$base_log_path/ftrace"
    printf '\n' > "$base_log_path/ftrace"
    save_following_log="$base_log_path/ftrace"
  fi

  # Follow
  if [[ "$follow" == 1 && -z "$disable" ]]; then
    cmd_ftrace="$cmd_ftrace && cat $TRACE_PIPE"
  fi

  # Handling command
  if [[ -n "$user_cmd" && -z "$disable" ]]; then
    save_following_log="$base_log_path/ftrace"
    screen_nick=$(get_today_info '+kw_%Y_%m_%d-%H_%M_%S')
    screen_cmd="screen -L -Logfile ~/$screen_nick -dmS $screen_nick cat $TRACE_PIPE"
    screen_end_cmd="screen -S $screen_nick -X quit > /dev/null"
    disable_cmd=$(build_ftrace_command_string '' 1)
    cmd_ftrace="$cmd_ftrace && $screen_cmd && $user_cmd && $disable_cmd && $screen_end_cmd"
  fi

  case "$target" in
    2) # LOCAL
      [[ -n "$save_following_log" ]] && redirect_mode='KW_REDIRECT_MODE'

      cmd_manager "$flag" "$cmd_ftrace" "$redirect_mode" "$save_following_log"
      ret="$?"

      if [[ -n "$user_cmd" ]]; then
        cmd_ftrace="sudo cp /root/$screen_nick $save_following_log && sudo chown $USER:$USER $save_following_log"
        cmd_manager "$flag" "$cmd_ftrace"
      fi
      ;;
    3 | 1) # REMOTE && VM
      if [[ "$target" == 1 ]]; then
        say 'Target is a VM'
        # TODO: We should check if the VM is up and running
      fi

      cmd_remotely "$cmd_ftrace" "$flag" '' '' '' '' "$save_following_log"
      ret="$?"

      # If we used --cmd, we need to retrieve the log
      if [[ -n "$user_cmd" ]]; then
        remote2host "$flag" "${HOME}/${screen_nick}" "$save_following_log"
        cmd_manager "$flag" "$cmd_ftrace"
      fi
      ;;
  esac

  # 130 - Owner died happens during the interruption
  if [[ "$ret" != 0 && "$ret" != 130 ]]; then
    complain "Fail to enable ftrace: $ftrace_syntax - $ret"
    complain 'Hint: try to use a wildcard in the filter'
    complain 'Hint: try to use: kw debug --reset'
    return "$ret"
  fi
}

# This function is responsible for building the ftrace string that represents
# the command executed in the target machine.
#
# @ftrace_syntax
#
# Return:
# A string with the final command is composed.
function build_ftrace_command_string()
{
  local ftrace_syntax="$1"
  local ftrace_disable="$2"
  local char_repetition
  local ftrace_filters
  local ftrace_type
  local cmd_disable_ftrace="printf '0' > $TRACING_ON"
  local cmd_enable_ftrace="printf '1' > $TRACING_ON"
  local cmd_ftrace="$cmd_disable_ftrace"
  declare -a filter_list

  if [[ -n "$ftrace_disable" ]]; then
    cmd_ftrace+=" && printf '' > $FTRACE_FILTER"
    cmd_ftrace+=" && printf 'nop' > $FTRACE_CURRENT_PATH"
    printf '%s' "$cmd_ftrace"
    return
  fi

  if [[ -z "$ftrace_syntax" ]]; then
    complain 'Invalid option: empty --ftrace input'
    exit 22 # EINVAL
  fi

  # Pre-process user input by dropping all extra space
  ftrace_syntax=$(str_drop_all_spaces "$ftrace_syntax")

  # Let's check if we have filters or not
  char_repetition=$(str_count_char_repetition "$ftrace_syntax" ':')

  if [[ "$char_repetition" -gt 1 || "$char_repetition" -lt 0 ]]; then
    complain 'Invalid syntax:'
    complain 'Please, use the syntax: <ftrace_type>[:filter[,filter, ...]]'
    exit 22 # EINVAL
  fi

  # Set ftrace type
  ftrace_type=$(printf '%s' "$ftrace_syntax" | cut -d ':' -f1)
  ftrace_type=$(str_strip "$ftrace_type")
  cmd_ftrace+=" && printf '%s' '$ftrace_type' > $FTRACE_CURRENT_PATH"

  # We have filters
  if [[ "$char_repetition" -eq 1 ]]; then
    ftrace_filters=$(printf '%s' "$ftrace_syntax" | cut -d ':' -f2)
    char_repetition=$(str_count_char_repetition "$ftrace_filters" ',')

    if [[ -z "$ftrace_filters" ]]; then
      complain 'Invalid syntax:'
      complain 'If you use ":", you must specify a filter'
      exit 22
    fi

    # We have multiple filters
    if [[ "$char_repetition" -gt 0 ]]; then
      IFS=',' read -r -a filter_list <<< "$ftrace_filters"
      if [[ -z "${filter_list[*]}" ]]; then
        complain 'Invalid syntax:'
        complain 'If you use "," make sure that you add a filter after that'
        exit 22
      fi
    else # single filter
      filter_list[0]="$ftrace_filters"
    fi
  fi

  # Set ftrace filters
  for filter in "${filter_list[@]}"; do
    cmd_ftrace+=" && printf '%s' '$filter' >> $FTRACE_FILTER"
  done

  # Enable traces
  cmd_ftrace+=" && $cmd_enable_ftrace"

  printf '%s' "$cmd_ftrace"
}

# This function sets up all files/directories that will keep the trace
# information captured during the debug. If users use the --history parameter,
# this function will create a folder for saving all debug history; it will
# create directories based on ID and date (e.g., 1_2020-11-12). Otherwise, it
# will create a single file per trace type (e.g., event, ftrace, etc.).
#
# @keep_history: If set to a value different from empty or 0, it will create a
# directory structure for keeping the trace history. Otherwise, it will create
# a single file per trace type.
#
# Return:
# Returns a string containing the base path used to store the trace files.
function prepare_log_database()
{
  local keep_history="$1"
  local debug_files_dir="$PWD/$KW_DEBUG"
  local tmp_id=''
  local dir_id
  local id=1
  local new_id=0
  local log_path="$debug_files_dir"

  if [[ -z "$keep_history" ]]; then
    printf '%s\n' ''
    return 0
  fi

  mkdir -p "$debug_files_dir"

  output=$(ls -A "$debug_files_dir")
  if [[ -n "$output" ]]; then
    id=0
    # Find the latest id
    for dir in "$debug_files_dir"/*; do
      tmp_id=$(basename "$dir" | cut -d_ -f1)
      # Check if is a number
      if ! str_is_a_number "$tmp_id"; then
        continue
      fi

      [[ "$tmp_id" -gt "$new_id" ]] && new_id="$tmp_id"
    done
    ((id++))
  fi
  ((new_id++))
  dir_id=$(date +"$new_id"_%Y-%m-%d)
  log_path=$(join_path "$log_path" "$dir_id")

  mkdir -p "$log_path"

  printf '%s\n' "$log_path"
}

# Show trace options
#
# @list Raw data to be processed and displayed later.
# @type Type of list.
#
# Return:
# Returns a status code
function show_list()
{
  local list="$1"
  local type="$2"
  local ret
  local msg

  process_list "$list" "$type"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    msg='Something went wrong in the listing process. Please, check if'
    msg="$msg you have access to /sys/kernel/debug/ and the parameter."
    complain "$msg"
  fi
  return "$ret"
}

# This function is invoked when --list parameter is employed, and it will
# process raw information related to kernel debug options (usually generate via
# ls command).
#
# @raw_options This is the raw output that will be processed by the function.
# @event Indicates that the user wants to see only event options.
#
# Return:
# It shows a pretty output related to the debug options.
function process_list()
{
  local raw_output="$1"
  local event="$2"

  if [[ -z "$raw_output" ]]; then
    return 22 # EINVAL
  fi

  if [[ -z "$event" ]]; then
    say 'All available events'
    sed '/^ssh\|^enable\|^filter/d' <<< "$raw_output" | column
    return
  fi

  if [[ -n "$event" ]]; then
    say 'Available events for the requested device:'
    sed '/^ssh\|^enable\|^filter/d' <<< "$raw_output" | nl
  fi
}

# This function is responsible for creating commands that deal with event
# manipulation, including enabling, disabling, and listing events.
#
# @list If this parameter is set to be equal to LIST_OPTION (1), it will
#   instruct this function to build a list command.
# @enable If this parameter is set to a value different than 1, an event
#   disable command will be generated.
#
# Return:
# A string with the final command is composed.
function build_event_command_string()
{
  local list="$1"
  local enable="$2"
  local enable_events=''
  local set_filters=''
  local filter=''
  local second_time=0
  local global_trace

  enable=${enable:-'1'}
  global_trace="printf '%s\n' $enable > $TRACING_ON"

  # Enable events
  for event in "${!events_hash[@]}"; do
    local current_event_enable="printf '%s\n' $enable > $event/enable"
    local filter="${events_hash[$event]}"

    if [[ -n "$list" ]]; then
      if [[ "$second_time" == 1 ]]; then
        list_events="$list_events && ls $event"
      else
        list_events="ls $event"
        second_time=1
      fi
      continue
    fi

    if [[ -n "$filter" ]]; then
      filter="printf '%s\n' '$filter' > $event/filter"
      set_filters+="$filter;"
    fi

    # If disable, clean filters
    if [[ "$enable" != 1 && -n "$event" ]]; then
      filter="printf '0\n' > $event/filter"
      set_filters+="$filter;"
    fi

    if [[ -z "$enable_events" ]]; then
      enable_events="$current_event_enable"
      continue
    fi
    enable_events="$enable_events; $current_event_enable"
  done

  if [[ -n "$list" ]]; then
    printf '%s\n' "$list_events"
  else
    if [[ "$enable" != 1 ]]; then
      [[ -n "$set_filters" ]] && global_trace+=" && $set_filters $enable_events"
      # Let's ensure that ftrace is disabled
      global_trace+=" && printf 'nop' > $FTRACE_CURRENT_PATH"
      printf '%s\n' "$global_trace"
    else
      printf '%s\n' "$set_filters $enable_events && $global_trace"
    fi
  fi
}

# The event manipulation has a special syntax for equipping users with a
# flexible way to gettering different trace options. However, we need a
# mechanism to translate the user input into a set of paths that can be used
# for dealing with events. Basically, this function parsers the following
# syntax:
#
# event[:<specific-event[[filter]]>[,<specific-event[[filter]]>,...]][;event...]
#
# @events_str User input that needs to be parsed.
#
# Return:
# In case of an error, returns EINVAL (22).
function convert_event_syntax_to_sys_path_hash()
{
  local events_str="$*"

  IFS=';' read -r -a events_str <<< "$events_str"
  # Target event. e.g.: amdgpu_dm or amdgpu
  for event in "${events_str[@]}"; do
    if [[ "$event" =~ .*':'.* ]]; then
      root_event=$(cut -d ':' -f1 <<< "$event")
      specific_events_str=$(cut -d ':' -f2 <<< "$event")
      # Invalid syntax
      if [[ -z "$specific_events_str" ]]; then
        return 22 # EINVAL
      fi
    elif [[ -n "$event" && ! "$event" =~ .*','.* ]]; then
      events_hash["$EVENT_BASE_PATH/$event"]=''
      continue
    else
      return 22 # EINVAL
    fi

    # Check specific event
    IFS=',' read -r -a specific_events <<< "$specific_events_str"
    for specific_event in "${specific_events[@]}"; do
      local specific_filter=''
      local hash_key=''

      # Check for event filter
      if [[ "$specific_event" =~ .*'['.*']'.* ]]; then
        specific_filter=${specific_event%]*}
        specific_filter=${specific_filter##*[}
        specific_event=$(cut -d "[" -f1 <<< "$specific_event")
      fi

      hash_key="$EVENT_BASE_PATH/$root_event/$specific_event"
      events_hash["$hash_key"]="$specific_filter"
    done
  done

  if [[ -z "$event" ]]; then
    events_hash["$EVENT_BASE_PATH"]=''
  fi
}

function stop_debug()
{
  local flag="$1"
  local remote
  local port
  local user
  local disable_cmd
  local stop_dmesg_cmd
  local target

  # We only need to take action when following log
  [[ -z "${options_values['FOLLOW']}" ]] && return 0

  target="${options_values['TARGET']}"
  flag=${flag:-'SILENT'}

  if [[ -n "${options_values['EVENT']}" || -n "${options_values['FTRACE']}" ]]; then
    say 'Restoring debug files'
    reset_debug "$target" "$flag"
  fi

  if [[ -n "${options_values['DMESG']}" ]]; then
    stop_dmesg_cmd="${interrupt_data_hash['DMESG']}"

    case "$target" in
      2) # LOCAL
        cmd_manager "$flag" "$stop_dmesg_cmd"
        ;;
      3 | 1) # REMOTE && VM
        remote="${remote_parameters['REMOTE_IP']}"
        port="${remote_parameters['REMOTE_PORT']}"
        user="${remote_parameters['REMOTE_USER']}"

        cmd_remotely "$stop_dmesg_cmd" "$flag" "$remote" "$port" "$user"
        ;;
    esac
  fi
}

function parser_debug_options()
{
  local options
  local short_options
  local long_options
  local transition_variables

  long_options='remote:,event:,ftrace:,dmesg,cmd:,local,history,disable,list::,follow,reset,help'
  short_options='r:,e:,t:,g,f,c:,k,d,l::,h'

  options=$(kw_parse "$short_options" "$long_options" "$@")

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw debug' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['TARGET']=''
  options_values['EVENT']=''
  options_values['FTRACE']=''
  options_values['DMESG']=''
  options_values['CMD']=''
  options_values['HISTORY']=''
  options_values['DISABLE']=''
  options_values['LIST']=''
  options_values['FOLLOW']=''

  # Set default values
  if [[ -n ${deploy_config[default_deploy_target]} ]]; then
    transition_variables=${deploy_config[default_deploy_target]}
    options_values['TARGET']=${deploy_target_opt[$transition_variables]}
  else
    options_values['TARGET']="$LOCAL_TARGET"
  fi

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']='Something is wrong in the remote option'
    return 22 # EINVAL
  fi

  if [[ -n ${configurations[debug_event]} ]]; then
    transition_variables=${configurations[debug_event]}
    options_values['EVENT']=${deploy_target_opt[$transition_variables]}
  fi

  eval "set -- $options"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --remote | -r)
        populate_remote_info "$2"
        if [[ "$?" == 22 ]]; then
          options_values['ERROR']="$option"
          return 22
        fi
        options_values['TARGET']="$REMOTE_TARGET"
        shift 2
        ;;
      --local)
        options_values['TARGET']="$LOCAL_TARGET"
        shift
        ;;
      --event | -e)
        options_values['EVENT']+="$2"
        shift 2
        ;;
      --ftrace | -t)
        options_values['FTRACE']+="$2"
        shift 2
        ;;
      --dmesg | -g)
        options_values['DMESG']=1
        shift
        ;;
      --cmd | -c)
        options_values['CMD']+="$2"
        shift 2
        ;;
      --history | -k)
        options_values['HISTORY']=1
        shift
        ;;
      --disable | -d)
        options_values['DISABLE']=1
        shift
        ;;
      --reset)
        options_values['RESET']=1
        shift
        ;;
      --list | -l)
        # Handling optional parameter
        if [[ "$2" =~ ^- || -z "${2// /}" ]]; then
          options_values['LIST']=1
          shift 2
        else
          options_values['LIST']="$2"
          shift 2
        fi
        ;;
      --follow | -f)
        options_values['FOLLOW']=1
        shift
        ;;
      --help | -h)
        debug_help "$1"
        exit
        ;;
      test_mode)
        options_values['TEST_MODE']='TEST_MODE'
        shift
        ;;
      --) # End of options, beginning of arguments
        shift
        ;;
      *)
        options_values['ERROR']="$1"
        return 22
        ;;
    esac
  done
}

function debug_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'debug'
    return
  fi
  printf '%s\n' 'kw debug:' \
    '  debug - kw debug utilities' \
    '  debug (--remote <remote>:<port> | --local | --vm) - choose target' \
    '  debug (--list | -l)[=(<ftrace> | <event>)] - List trace options' \
    '  debug (--history | -k) - Store trace logs in a file' \
    '  debug (--follow | -f) - Follow traces in real-time' \
    '  debug (--cmd | -c) "command" - Trace log while running a command in the target.' \
    '  debug (--dmesg | -g) - Collect the dmesg log' \
    '  debug (--event | -e) [--disable] "<syntax>" - Trace specific event' \
    '  debug (--ftrace | -t) [--disable] "<syntax>" - Use ftrace to identify code path' \
    '  debug (--reset) - Reset debug values in the target machine' \
    '  You can combine some of the above options'
}

load_deploy_config
load_kworkflow_config
