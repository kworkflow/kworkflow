. "$KW_LIB_DIR/kw_config_loader.sh" --source-only
. "$KW_LIB_DIR/kwlib.sh" --source-only
. "$KW_LIB_DIR/kw_string.sh" --source-only
. "$KW_LIB_DIR/kw_time_and_date.sh" --source-only

# Hash containing command line options
declare -gA options_values
POMODORO_LOG_FILE="$KW_DATA_DIR/pomodoro_current.log"

# Pomodoro manager function.
function pomodoro()
{
  local alert

  if [[ -z "$@" ]]; then
    complain 'Please, provide an argument'
    pomodoro_help
    exit 22 # EINVAL
  fi

  pomodoro_parser "$@"

  if [[ ${options_values['TIMER']} != 0 ]]; then
    touch "$POMODORO_LOG_FILE"
    timer_thread "$alert" &
  fi

  if [[ ${options_values['SHOW_TIMER']} == 1 ]]; then
    show_active_pomodoro_timebox
  fi
}

# kw pomodoro registers timebox values in the log file used to display the
# Pomodoro section's current status. This function appends a new line to this
# file based on the timestamp passed to it.
#
# @timestamp: Timestamp to be saved in the log file
function register_timebox()
{
  local timestamp="$1"
  echo "$timestamp,${options_values['TIMER']}" >> "$POMODORO_LOG_FILE"
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
  local timestamp=$(get_timestamp_sec)
  local flag

  flag=${flag:-'SILENT'}

  register_timebox "$timestamp"
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
      time_value=$((3600 * "$time_value"))
    ;;
    m)
      time_value=$((60 * "$time_value"))
    ;;
    s)
      time_value="$time_value"
    ;;
  esac

  missing_time=$(($time_value - $elapsed_time))
  if [[ "$missing_time" -lt 0 ]]; then
    missing_time=0
  fi

  echo "$missing_time"
}

# This function inspects the Pomodoro file, and based on each line, information
# tells the user the current status of his work section.
function show_active_pomodoro_timebox()
{
  local log
  local timestamp
  local timebox
  local diff_time
  local timestamp_to_date
  local current_timestamp

  current_timestamp=$(get_timestamp_sec)

  while read line
  do
    # Get data from file
    timestamp=$(echo "$line" | cut -d',' -f1)
    timebox=$(echo "$line" | cut -d',' -f2)

    # Calculate and process output
    timestamp_to_date=$(date_to_format "@$timestamp" '+%H:%M:%S[%Y/%m/%d]')
    diff_time=$(($current_timestamp - $timestamp))

    timebox=$(calculate_missing_time "$timebox" "$diff_time")

    say "Started at: $timestamp_to_date"
    say "- Elapsed time:" $(sec_to_format "$diff_time")
    say "- You still have" $(sec_to_format "$timebox")
  done < "$POMODORO_LOG_FILE"
}

function pomodoro_parser()
{
  local raw_options="$@"
  local time_scale
  local time_value
  local timer=0
  local label=0
  local description=0

  if [[ "$1" == -h ]]; then
    pomodoro_help
    exit 0
  fi

  options_values['TIMER']=0
  options_values['SHOW_TIMER']=0
  options_values['LABEL']=0
  options_values['DESCRIPTION']=0

  IFS=' ' read -r -a options <<< "$raw_options"
  for option in "${options[@]}"; do
    if [[ "$option" =~ ^(--.*|-.*|test_mode) ]]; then
      label=0
      case "$option" in
        --set-timer|-t)
          options_values['TIMER']=1
          timer=1
          continue
        ;;
        --current|-c)
          options_values['SHOW_TIMER']=1
          continue
        ;;
        --label|-l)
          options_values['LABEL']=''
          label=1
          echo "TODO: Add label"
          continue
        ;;
        --description|-d)
          options_values['DESCRIPTION']=''
          description=1
          echo "TODO: Add description"
          continue
        ;;
        *)
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
        if ! str_is_a_number "$time_value" ; then
           complain "'$time_value' is not a number"
           exit 22 # EINVAL
        fi

        options_values['TIMER']="$option"
        timer=0
      elif [[ "$label" == 1 ]]; then
        options_values['LABEL']="${options_values['LABEL']} $option"
      elif [[ "$description" == 1 ]]; then
        options_values['DESCRIPTION']="${options_values['DESCRIPTION']} $option"
      fi
    fi
  done

  # Invalid options
  if [[ "$timer" == 1 && "${options_values['TIMER']}" != 0 ]]; then
    complain '--set-timer,t requires a parameter'
    exit 22 # EINVAL
  fi

  if [[ "${options_values['TIMER']}" != 0 && "${options_values['SHOW_TIMER']}" == 1 ]]; then
    warning '--current|-c is ignored when used with --set-timer,t'
    options_values['SHOW_TIMER']=0
  fi
}

function pomodoro_help()
{
  echo -e "kw pomodoro, p:\n" \
    "\t--set-timer,-t INTEGER[h|m|s] - Set pomodoro timer \n" \
    "\t--current,-c - Show elapsed time"
}
