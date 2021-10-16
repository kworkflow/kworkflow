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

declare -gr TRACING_BASE_PATH='/sys/kernel/debug/tracing'
declare -gr TRACING_ON="$TRACING_BASE_PATH/tracing_on"
declare -gr EVENT_BASE_PATH="$TRACING_BASE_PATH/events"
declare -gr TRACE_PIPE="$TRACING_BASE_PATH/trace_pipe"

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
  local dmesg=''
  local user_cmd=''
  local keep_history=''
  local disable=''
  local list=''
  local follow=''
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
  dmesg="${options_values['DMESG']}"
  user_cmd="${options_values['CMD']}"
  keep_history="${options_values['HISTORY']}"
  disable="${options_values['DISABLE']}"
  list="${options_values['LIST']}"
  follow="${options_values['FOLLOW']}"

  # Base path for saving log files
  base_log_path=$(prepare_log_database "$keep_history")

  if [[ -n "$event" ]]; then
    event_trace "$target" "$flag" "$event" "$base_log_path" "$follow" "$user_cmd" "$list"
    return "$?"
  fi

  if [[ -n "$dmesg" ]]; then
    dmesg_debug "$target" "$flag" "$base_log_path" "$follow" "$user_cmd"
    return "$?"
  fi

  if [[ "$test_mode" == 'TEST_MODE' ]]; then
    echo "${remote_parameters['REMOTE_IP']} ${remote_parameters['REMOTE_PORT']} $target $event $user_cmd"
    return 0
  fi
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
  local redirect_mode=''
  local save_following_log=''
  local cmd='dmesg --human --color=always'

  if [[ -n "$follow" ]]; then
    cmd="$cmd --follow"
  else
    cmd="$cmd --nopager"
  fi

  # Capture data
  if [[ -n "$base_log_path" ]]; then
    touch "$base_log_path/dmesg"
    echo > "$base_log_path/dmesg"
    save_following_log="$base_log_path/dmesg"
  fi

  case "$target" in
    2) # LOCAL
      [[ -n "$save_following_log" ]] && redirect_mode='KW_REDIRECT_MODE'

      cmd_manager "$flag" "$cmd" "$redirect_mode" "$save_following_log"
      ;;
    3 | 1) # REMOTE && VM
      local remote="${remote_parameters['REMOTE_IP']}"
      local port="${remote_parameters['REMOTE_PORT']}"
      local user="${remote_parameters['REMOTE_USER']}"

      if [[ "$target" == 1 ]]; then
        say 'Target is a VM'
        # TODO: We should check if the VM is up and running
      fi

      cmd_remotely "$cmd" "$flag" "$remote" "$port" "$user" '' "$save_following_log"
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
function event_trace()
{
  local target="$1"
  local flag="$2"
  local event="$3"
  local base_log_path="$4"
  local follow="$5"
  local user_cmd="$6"
  local list="$7"
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
    echo > "$base_log_path/event"
    save_following_log="$base_log_path/event"
  fi

  if [[ "$follow" == 1 ]]; then
    command="$command && cat $TRACE_PIPE"
  fi

  if [[ -n "$user_cmd" ]]; then
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

  signal_manager 'stop_tracer' || warning 'Was not able to set signal handler'

  case "$target" in
    2) # LOCAL
      if [[ "$list" == "$LIST_OPTION" ]]; then
        list_output=$(cmd_manager "SILENT" "$save_following_log" "sudo bash -c \"$command\"")
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
        command="scp -P $port $user@$remote:~/$screen_nick $save_following_log"
        cmd_manager "$flag" "$command"
      fi
      ;;
  esac

  return 0
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
    echo ''
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

  echo "$log_path"
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
  global_trace="echo $enable > $TRACING_ON"

  # Enable events
  for event in "${!events_hash[@]}"; do
    local current_event_enable="echo $enable > $event/enable"
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
      filter="echo '$filter' > $event/filter"
      set_filters+="$filter;"
    fi

    # If disable, clean filters
    if [[ "$enable" != 1 ]]; then
      filter="echo '0' > $event/filter"
      set_filters+="$filter;"
    fi

    if [[ -z "$enable_events" ]]; then
      enable_events="$current_event_enable"
      continue
    fi
    enable_events="$enable_events; $current_event_enable"
  done

  if [[ -n "$list" ]]; then
    echo "$list_events"
  else
    if [[ "$enable" != 1 ]]; then
      echo "$global_trace && $set_filters $enable_events"
    else
      echo "$set_filters $enable_events && $global_trace"
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

function stop_tracer()
{
  if [[ -v options_values['FOLLOW'] ]]; then
    if [[ -v options_values['EVENT'] ]]; then
      say "Disabling events in the target machine : ${options_values['EVENT']}"
      disable_cmd=$(build_event_command_string '' 0)

      case "${options_values['TARGET']}" in
        2) # LOCAL
          cmd_manager 'SILENT' "sudo bash -c \"$disable_cmd\""
          ;;
        3 | 1) # REMOTE && VM
          local remote="${remote_parameters['REMOTE_IP']}"
          local port="${remote_parameters['REMOTE_PORT']}"
          local user="${remote_parameters['REMOTE_USER']}"

          cmd_remotely "$disable_cmd" 'SILENT' "$remote" "$port" "$user"
          ;;
      esac
    fi
  fi
}

function parser_debug_options()
{
  local options
  local short_options
  local long_options
  local transition_variables

  long_options='remote:,event:,dmesg,cmd:,local,history,disable,list,follow,help'
  short_options='f,e,g,c,h,d,l,k'

  options=$(kw_parse "$short_options" "$long_options" "$@")

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw debug' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['TARGET']=''
  options_values['EVENT']=''
  options_values['DMESG']=0
  options_values['CMD']=''
  options_values['HISTORY']=''
  options_values['DISABLE']=0
  options_values['LIST']=''
  options_values['FOLLOW']=''

  # Set default values
  if [[ -n ${configurations[default_deploy_target]} ]]; then
    transition_variables=${configurations[default_deploy_target]}
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
      --remote)
        options_values['TARGET']="$REMOTE_TARGET"
        populate_remote_info "$2"
        if [[ "$?" == 22 ]]; then
          options_values['ERROR']="$option"
          return 22
        fi
        shift
        ;;
      --local)
        options_values['TARGET']="$LOCAL_TARGET"
        shift
        ;;
      --event | -e)
        options_values['EVENT']+="$2"
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
      --list | -l)
        options_values['LIST']=1
        shift
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
    '  debug (--list | -l) - List trace options' \
    '  debug (--history | -k) - Store trace logs in a file' \
    '  debug (--follow | -f) - Follow traces in real-time' \
    '  debug (--cmd | -c) "command" - Trace log while running a command in the target.' \
    '  debug (--dmesg | -g) - Collect the dmesg log' \
    '  debug (--event | -e) "<syntax>" - Trace specific event' \
    '  You can combine some of the above options'
}
