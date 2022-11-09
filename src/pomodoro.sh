include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kw_string.sh"
include "$KW_LIB_DIR/kw_time_and_date.sh"

# Hash containing command line options
declare -gA options_values
POMODORO_LOG_FILE="$KW_DATA_DIR/pomodoro_current.log"

declare -g KW_POMODORO_DATA="$KW_DATA_DIR/pomodoro"
declare -g KW_POMODORO_TAG_LIST="$KW_POMODORO_DATA/tags"

MAX_TAG_LENGTH=32
MAX_DESCRIPTION_LENGTH=512

# Pomodoro manager function.
function pomodoro()
{
  local alert

  if [[ -z "$*" ]]; then
    complain 'Please, provide an argument'
    pomodoro_help
    exit 22 # EINVAL
  fi

  pomodoro_parser "$@"

  if [[ -n "${options_values['TAG']}" ]]; then
    if str_is_a_number "${options_values['TAG']}"; then
      local id="${options_values['TAG']}"

      options_values['TAG']=$(translate_id_to_tag "$id")
      if [[ "$?" != 0 ]]; then
        complain "It looks like that $id is not valid"
        complain 'Use kw p --tag to see all registered tags'
        exit 22 # EINVAL
      fi

      # Check id
      if [[ "${options_values['TIMER']}" == 0 ]]; then
        show_tags
      fi
    else
      register_tag "${options_values['TAG']}"
    fi
  fi

  if [[ "${options_values['TIMER']}" != 0 ]]; then
    touch "$POMODORO_LOG_FILE"
    timer_thread "$alert" &
  fi

  if [[ "${options_values['SHOW_TIMER']}" == 1 ]]; then
    show_active_pomodoro_timebox
  fi
}

# Create the required folders and files to record Pomodoro data. To define
# where to save data, we use the current date as a reference. In other words,
# this function creates folders following YYYY/MM pattern and a file with the
# present day.
#
# Return:
# For simplicity's sake, it returns the path for saving today's data.
function setup_pomodoro()
{
  local year_month_dir
  local today

  year_month_dir=$(get_today_info '+%Y/%m')
  today=$(get_today_info '+%d')

  mkdir -p "$KW_POMODORO_DATA/$year_month_dir"
  touch "$KW_POMODORO_DATA/$year_month_dir/$today"
  touch "$KW_POMODORO_TAG_LIST"

  printf '%s\n' "$KW_POMODORO_DATA/$year_month_dir/$today"
}

# tag,timebox,start,description
function register_data_for_report()
{
  local save_to
  local time_now
  local data_line

  save_to=$(setup_pomodoro)
  time_now=$(date +%T)

  data_line="${options_values['TAG']},${options_values['TIMER']},$time_now"

  if [[ -n "${options_values['DESCRIPTION']}" ]]; then
    data_line="$data_line,${options_values['DESCRIPTION']}"
  fi

  printf '%s\n' "$data_line" >> "$save_to"
}

# Register a new tag if it is not yet defined.
#
# @tag: tag name
function register_tag()
{
  local tag

  tag="$*"

  setup_pomodoro > /dev/null

  if ! is_tag_already_registered "$tag"; then
    printf '%s\n' "$tag" >> "$KW_POMODORO_TAG_LIST"
  fi
}

# Search in a file for a specific tag name. If it finds, it returns 0;
# otherwise, return a positive number.
#
# @tag: Tag name
#
# Return:
# Return 0 if it finds a match, or a value greater than 0 if it does not find
# anything.
function is_tag_already_registered()
{
  local tag

  tag="$*"

  tag="\<$tag\>" # \<STRING\> forces the exact match
  grep -q "$tag" "$KW_POMODORO_TAG_LIST"
  return "$?"
}

# Show registered tags with number identification.
function show_tags()
{
  if [[ ! -s "$KW_POMODORO_TAG_LIST" ]]; then
    say 'You did not register any new tag yet'
    pomodoro_help
    exit 0
  fi

  # Show line numbers
  nl -n rn -s . "$KW_POMODORO_TAG_LIST"
}

# Translate an ID number to a tag identifier.
#
# @id: An integer number
#
# Return:
# If ID is valid, this function prints the tag name and returns 0, otherwise
# return 22 (EINVAL).
function translate_id_to_tag()
{
  local id="$1"
  local total_lines

  # Basic check
  [[ -z "$id" ]] && return 22 # EINVAL

  total_lines=$(wc -l "$KW_POMODORO_TAG_LIST" | cut -d' ' -f1)
  if [[ "$id" -le 0 || "$id" -gt "$total_lines" ]]; then
    return 22 # EINVAL
  fi

  result=$(sed "$id"'q;d' "$KW_POMODORO_TAG_LIST")
  [[ -z "$result" ]] && return 22 # EINVAL
  printf '%s\n' "$result"
  return 0
}

# kw pomodoro registers timebox values in the log file used to display the
# Pomodoro section's current status. This function appends a new line to this
# file based on the timestamp passed to it.
#
# @timestamp: Timestamp to be saved in the log file
function register_timebox()
{
  local timestamp="$1"
  printf '%s\n' "$timestamp,${options_values['TIMER']}" >> "$POMODORO_LOG_FILE"
}

# When a timebox finishes, this function removes the section-time from the log
# file by using the timestamp as a reference.
#
# @timestamp: Timestamp to be removed from the file
function remove_completed_timebox()
{
  local timestamp="$1"
  sed -i "/$timestamp/d" "$POMODORO_LOG_FILE"
}

# This is the thread function that will be used to notify when the Pomodoro
# section achieves its end. Do not add anything that can print a character
# here; otherwise, it can be visible to users. This function captures the
# current timestamp and uses it to register itself in the Pomodoro log file.
function timer_thread()
{
  local timestamp
  local flag

  timestamp=$(get_timestamp_sec)

  flag=${flag:-'SILENT'}

  register_timebox "$timestamp"

  if [[ -n "${options_values['TAG']}" ]]; then
    register_data_for_report
  fi

  cmd_manager "$flag" "sleep ${options_values['TIMER']}"
  alert_completion "Pomodoro: Your ${options_values['TIMER']} timebox ended" '--alert=vs'

  remove_completed_timebox "$timestamp"
  exit 0
}

# Based on the timebox requested by the user and the elapsed time, this
# function calculates how much time the user still left before the end of its
# timebox.
#
# @timebox: User timebox requested (it must end with h, m, or s)
# @elapsed_time: Elapsed time since the beginning of the Pomodoro section
#
# Return:
# Return how many seconds the user still has before his section ends. If it
# already over, it will return 0.
function calculate_missing_time()
{
  local timebox="$1"
  local elapsed_time="$2"
  local time_type
  local time_value

  time_type=$(last_char "$timebox")
  if [[ ! "$time_type" =~ h|m|s ]]; then
    time_type='s'
    timebox="$timebox$time_type"
  fi

  time_value=$(chop "$timebox")

  case "$time_type" in
    h)
      time_value=$((3600 * time_value))
      ;;
    m)
      time_value=$((60 * time_value))
      ;;
  esac

  missing_time=$((time_value - elapsed_time))
  if [[ "$missing_time" -lt 0 ]]; then
    missing_time=0
  fi

  printf '%s\n' "$missing_time"
}

# This function inspects the Pomodoro file, and based on each line, information
# tells the user the current status of his work section.
function show_active_pomodoro_timebox()
{
  local timestamp
  local timebox
  local diff_time
  local timestamp_to_date
  local current_timestamp

  current_timestamp=$(get_timestamp_sec)

  if [[ -f "$POMODORO_LOG_FILE" ]]; then
    while read -r line; do
      # Get data from file
      timestamp=$(printf '%s\n' "$line" | cut -d',' -f1)
      timebox=$(printf '%s\n' "$line" | cut -d',' -f2)

      # Calculate and process output
      timestamp_to_date=$(date_to_format "@$timestamp" '+%H:%M:%S[%Y/%m/%d]')
      diff_time=$((current_timestamp - timestamp))

      timebox=$(calculate_missing_time "$timebox" "$diff_time")

      say "Started at: $timestamp_to_date"
      say '- Elapsed time:' "$(sec_to_format "$diff_time")"
      say '- You still have' "$(sec_to_format "$timebox")"
    done < "$POMODORO_LOG_FILE"
  fi
}

function pomodoro_parser()
{
  local raw_options="$*"
  local time_scale
  local time_value
  local timer=0
  local build_tag=0
  local build_description=0
  local tag_dash=0
  local description_dash=0

  if [[ "$1" =~ -h|--help ]]; then
    pomodoro_help "$1"
    exit 0
  fi

  options_values['TIMER']=0
  options_values['SHOW_TIMER']=0
  options_values['TAG']=''
  options_values['DESCRIPTION']=''

  IFS=' ' read -r -a options <<< "$raw_options"
  for option in "${options[@]}"; do
    if [[ "$option" =~ ^(--.*|-.*|test_mode) ]]; then
      [[ "$build_tag" == 1 ]] && tag_dash=1
      [[ "$build_description" == 1 ]] && description_dash=1
      build_tag=0
      build_description=0

      case "$option" in
        --set-timer | -t)
          options_values['TIMER']=1
          timer=1
          continue
          ;;
        --list | -l)
          options_values['SHOW_TIMER']=1
          continue
          ;;
        --tag | -g)
          options_values['TAG']=''
          build_tag=1
          tag_dash=0
          description_dash=0
          continue
          ;;
        --description | -d)
          options_values['DESCRIPTION']=''
          build_description=1
          tag_dash=0
          description_dash=0
          continue
          ;;
        *)
          if [[ "$tag_dash" == 1 ]]; then
            options_values['TAG']="${options_values['TAG']} $option"
            build_tag=1
            continue
          fi
          if [[ "$description_dash" == 1 ]]; then
            options_values['DESCRIPTION']="${options_values['DESCRIPTION']} $option"
            build_description=1
            continue
          fi
          complain "Invalid option: $option"
          pomodoro_help
          exit 22 # EINVAL
          ;;
      esac
    else
      if [[ "$timer" == 1 ]]; then
        time_scale=$(last_char "$option")
        if [[ ! "$time_scale" =~ h|m|s ]]; then
          complain 'Invalid time suffix'
          pomodoro_help
          exit 22 # EINVAL
        fi

        time_value=$(chop "$option")
        if ! str_is_a_number "$time_value"; then
          complain "'$time_value' is not a number"
          exit 22 # EINVAL
        fi

        options_values['TIMER']="$option"
        timer=0
      elif [[ "$build_tag" == 1 ]]; then
        options_values['TAG']="${options_values['TAG']} $option"
        tag_length=$(str_length "${options_values['TAG']}")

        # Let's trim the string size
        if [[ "$tag_length" -ge "$MAX_TAG_LENGTH" ]]; then
          options_values['TAG']=$(str_trim "${options_values['TAG']}" "$MAX_TAG_LENGTH")
          warning "Max tag size is $MAX_TAG_LENGTH"
        fi
      elif [[ "$build_description" == 1 ]]; then
        options_values['DESCRIPTION']="${options_values['DESCRIPTION']} $option"
        description_length=$(str_length "${options_values['DESCRIPTION']}")

        # Let's trim the string size
        if [[ "$description_length" -ge "$MAX_DESCRIPTION_LENGTH" ]]; then
          options_values['DESCRIPTION']=$(str_trim "${options_values['DESCRIPTION']}" "$MAX_DESCRIPTION_LENGTH")
          warning "Max description size is $MAX_DESCRIPTION_LENGTH"
        fi
      fi
    fi
  done

  # Invalid options
  if [[ "$timer" == 1 && "${options_values['TIMER']}" != 0 ]]; then
    complain '--set-timer,t requires a parameter'
    exit 22 # EINVAL
  fi

  # If user provide a description, let's enforce a tag
  if [[ -n "${options_values['DESCRIPTION']}" ]]; then
    if [[ -z "${options_values['TAG']}" ]]; then
      complain 'If you use description, you must provide a tag'
      exit 22 # EINVAL
    fi
  fi

  options_values['TAG']=$(str_strip "${options_values['TAG']}")
  options_values['DESCRIPTION']=$(str_strip "${options_values['DESCRIPTION']}")

  # If user only pass --tag|-g, we list available tags
  if [[ "$build_tag" == 1 && -z "${options_values['TAG']}" ]]; then
    show_tags
    return 0
  fi

  if [[ "${options_values['TIMER']}" != 0 && "${options_values['SHOW_TIMER']}" == 1 ]]; then
    warning '--list|-l is ignored when used with --set-timer,t'
    options_values['SHOW_TIMER']=0
  fi
}

function pomodoro_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'pomodoro'
    return
  fi
  printf '%s\n' 'kw pomodoro:' \
    '  pomodoro (-t|--set-timer) <integer>(h|m|s) - Set pomodoro timer' \
    '  pomodoro (-g|--tag) <string> - Associate a tag to a timebox' \
    '  pomodoro (-d|--description) <string> - Add a description to a timebox with a tag' \
    '  pomodoro (-l|--list) - Show elapsed time'
}

load_notification_config
