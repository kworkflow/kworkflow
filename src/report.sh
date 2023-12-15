#!/bin/bash
# kw keeps track of some data operations; at the moment kw tracks
# Pomodoro sessions (kw pomodoro) and overall statistics. This file
# intends to keep all procedures related to data fetching, processing,
# formatting and outputting to display a report to the user.

include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kw_time_and_date.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/lib/statistics.sh"
include "${KW_LIB_DIR}/lib/kw_db.sh"

declare -gA options_values
declare -g target_period

# Statistics data structures
declare -g statistics_raw_data
declare -gA statistics=(['deploy']='' ['build']='' ['list']='' ['uninstall']='' ['modules_deploy']='')

# Pomodoro data structures
declare -g pomodoro_raw_data
declare -gA pomodoro_sessions
declare -gA pomodoro_metadata

# Colors for printing
declare -g yellow_color
declare -g green_color
declare -g normal_color
yellow_color=$(tput setaf 3)
green_color=$(tput setaf 2)
normal_color=$(tput sgr0)

function report_main()
{
  local target_time
  local flag

  flag=${flag:-'SILENT'}

  if [[ "$1" =~ -h|--help ]]; then
    report_help "$1"
    exit
  fi

  parse_report_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  set_raw_data "$flag"

  if [[ -n "${options_values['STATISTICS']}" ]]; then
    if [[ "${configurations[disable_statistics_data_track]}" == 'yes' ]]; then
      say 'You have "disable_statistics_data_track" marked as "yes"'
      say 'If you want to track statistics, change this option to "no"'
    fi
    process_and_format_statistics_raw_data "$flag"
  fi

  if [[ -n "${options_values['POMODORO']}" ]]; then
    process_and_format_pomodoro_raw_data "$flag"
  fi

  if [[ -z "${options_values['OUTPUT']}" ]]; then
    show_report "flag"
  else
    save_data_to "${options_values['OUTPUT']}" "$flag"
  fi
}

# This function sets raw data for the statistics and Pomodoro report. The function
# stores the raw data in a global variable named '<statistics/pomodoro>_raw_data'.
# The format of the raw data is the same as the returned by the local database. For
# example, in the case of the 'statistics_report' table, the format will be
# <ID>|<LABEL_NAME>|<STATUS>|<START_DATE>|<START_TIME>|<ELAPSED_TIME_IN_SECS>.
function set_raw_data()
{
  local flag="$1"
  local date
  local regex_exp

  flag=${flag:-'SILENT'}

  if [[ -n "${options_values['DAY']}" ]]; then
    target_period="day ${options_values['DAY']}"
    date=$(printf '%s' "${options_values['DAY']}" | sed 's/\//-/g')
    regex_exp="'^${date}$'"
  elif [[ -n "${options_values['WEEK']}" ]]; then
    target_period='week of day '
    target_period+=$(printf '%s' "${options_values['WEEK']}" | cut -d '|' -f1)
    date=$(printf '%s' "${options_values['WEEK']}" | sed 's/\//-/g')
    regex_exp="'^${date}$'"
  elif [[ -n "${options_values['MONTH']}" ]]; then
    target_period="month ${options_values['MONTH']}"
    date=$(printf '%s' "${options_values['MONTH']}" | sed 's/\//-/g')
    regex_exp="'^${date}-[0-3][0-9]$'"
  elif [[ -n "${options_values['YEAR']}" ]]; then
    target_period="year ${options_values['YEAR']}"
    date="${options_values['YEAR']}"
    regex_exp="'^${date}-[0-1][0-9]-[0-3][0-9]$'"
  fi

  if [[ -n "${options_values['STATISTICS']}" ]]; then
    statistics_raw_data=$(get_raw_data_from_period_of_time 'statistics_report' "$regex_exp" "$flag")
  fi

  if [[ -n "${options_values['POMODORO']}" ]]; then
    pomodoro_raw_data=$(get_raw_data_from_period_of_time 'pomodoro_report' "$regex_exp" "$flag")
  fi
}

# This function is responsible for getting all raw data related to a given
# table from a target period of time. The table name and the period of time
# are passed as arguments. This function is the interface with the local
# database.
#
# @table_name: Name of the table in the database
# @regex_exp:  Regex expression for the target period of time
#
# Return:
# Raw output from database query related to a given table from a target period
# of time.
function get_raw_data_from_period_of_time()
{
  local table_name="$1"
  local regex_exp="$2"
  local flag="$3"
  local raw_data

  flag=${flag:-'SILENT'}

  raw_data=$(select_from "${table_name} WHERE date REGEXP ${regex_exp}")
  printf '%s' "$raw_data"
}

# This function process raw data specific from the 'statistics_report' table.
# A processed data (for a given command) consists of a string in the format
# '<NUM OF OPERATIONS> <MAX TIME> <MIN TIME> <AVG TIME>'.
# It also formats the processed data for printing.
# The processed and formatted results are stored in the 'statistics' global
# associative array in their respective command.
#
# Return:
# In case there is no statistics raw data to process, returns 2 (ENOENT) and
# sets an error message in 'options_values['ERROR']'.
function process_and_format_statistics_raw_data()
{
  local flag="$1"
  local num_of_operations
  local max_time
  local min_time
  local avg_time
  local aux

  flag=${flag:-'SILENT'}

  if [[ -z "${statistics_raw_data}" ]]; then
    options_values['ERROR']="kw doesn't have any statistics of the target period: ${target_period}"
    return 2 # ENOENT
  fi

  for command in "${!statistics[@]}"; do
    values=$(printf '%s\n' "${statistics_raw_data}" | grep "|${command}|" | cut -d '|' -f6)
    [[ -z "$values" ]] && continue

    # Calculate values
    num_of_operations=$(calculate_total_of_data "$values")
    max_time=$(max_value "$values")
    min_time=$(min_value "$values" "${max_time}")
    avg_time=$(calculate_average "$values")

    ## Format values
    max_time=$(secs_to_arbitrarily_long_hours_mins_secs "${max_time}")
    min_time=$(secs_to_arbitrarily_long_hours_mins_secs "${min_time}")
    avg_time=$(secs_to_arbitrarily_long_hours_mins_secs "${avg_time}")
    aux="${num_of_operations} ${max_time} ${min_time} ${avg_time}"
    #shellcheck disable=SC2086
    statistics["$command"]=$(printf '%-14s %5d %s %s %s\n' "${command^}" $aux)
  done
}

# This function process raw data specific from the 'pomodoro_report' table.
# For every tag, the function processes a list of sessions with the values
# start date, start time, end time, duration in format and description (if
# present). It also formats the information for printing and stores it in
# in the 'pomodoro_sessions[<tag>]' global associative array.
# Total focus time and number of sessions is also processed and formatted.
# These are stored in the 'pomodoro_metadata[<tag>]' global associative array,
# including an all tag summary.
#
# Return:
# In case there is no statistics raw data to process, returns 2 (ENOENT) and
# sets an error message in 'options_values['ERROR']'.
function process_and_format_pomodoro_raw_data()
{
  local flag="$1"
  local tag
  local start_date
  local start_time
  local end_time
  local duration
  local duration_in_format
  local description
  local total_time_in_secs
  local total_time_in_format
  local number_of_sessions
  local total_time_in_secs_all_tags
  local total_time_in_format_all_tags
  local number_of_sessions_all_tags
  local aux

  flag=${flag:-'SILENT'}

  if [[ -z "${pomodoro_raw_data}" ]]; then
    options_values['ERROR']="kw doesn't have any Pomodoro data of the target period: ${target_period}"
    return 2 # ENOENT
  fi

  while read -r entry; do
    tag=$(printf '%s' "$entry" | cut -d '|' -f3)
    start_date=$(printf '%s' "$entry" | cut -d '|' -f4)
    start_time=$(printf '%s' "$entry" | cut -d '|' -f5)
    duration=$(printf '%s' "$entry" | cut -d '|' -f6)
    description=$(printf '%s' "$entry" | cut -d '|' -f7)

    # Process end time and duration in HH:MM:SS format
    end_time=$(date --date="${start_time} ${duration} seconds" '+%H:%M:%S')
    duration_in_format=$(secs_to_arbitrarily_long_hours_mins_secs "$duration")

    # Add formatted entry to tag sessions
    # TODO: See if there aren't better formattings/colorings
    aux="    (${yellow_color}${start_date} ${green_color}${start_time}->${end_time}${normal_color}) "
    aux+="[Duration ${duration_in_format}]: ${description}"$'\n'
    pomodoro_sessions["$tag"]+="$aux"

    # Increment tag sessions number and add to net focus time
    total_time_in_secs=$(printf '%s' "${pomodoro_metadata["$tag"]}" | cut -d ',' -f1)
    number_of_sessions=$(printf '%s' "${pomodoro_metadata["$tag"]}" | cut -d ',' -f2)
    total_time_in_secs=$((total_time_in_secs + duration))
    number_of_sessions=$((number_of_sessions + 1))
    pomodoro_metadata["$tag"]="${total_time_in_secs},${number_of_sessions}"
  done <<< "${pomodoro_raw_data}"

  for tag in "${!pomodoro_metadata[@]}"; do
    # Add this tag sessions number and net focus time to all tags summary
    total_time_in_secs=$(printf '%s' "${pomodoro_metadata["$tag"]}" | cut -d ',' -f1)
    number_of_sessions=$(printf '%s' "${pomodoro_metadata["$tag"]}" | cut -d ',' -f2)
    total_time_in_secs_all_tags=$(printf '%s' "${pomodoro_metadata['ALL_TAGS']}" | cut -d ',' -f1)
    number_of_sessions_all_tags=$(printf '%s' "${pomodoro_metadata['ALL_TAGS']}" | cut -d ',' -f2)
    total_time_in_secs_all_tags=$((total_time_in_secs_all_tags + total_time_in_secs))
    number_of_sessions_all_tags=$((number_of_sessions_all_tags + number_of_sessions))
    pomodoro_metadata['ALL_TAGS']="${total_time_in_secs_all_tags},${number_of_sessions_all_tags}"

    # Format and update metadata for this individual tag
    total_time_in_format=$(secs_to_arbitrarily_long_hours_mins_secs "${total_time_in_secs}")
    pomodoro_metadata["$tag"]="- Total focus time: ${total_time_in_format}"$'\n'
    pomodoro_metadata["$tag"]+="- Number of sessions: ${number_of_sessions}"
  done

  # Format and update metadata for all tags summary
  total_time_in_format_all_tags=$(secs_to_arbitrarily_long_hours_mins_secs "${total_time_in_secs_all_tags}")
  pomodoro_metadata['ALL_TAGS']="- Total focus time from all tags: ${total_time_in_format_all_tags}"$'\n'
  pomodoro_metadata['ALL_TAGS']+="- Number of sessions from all tags: ${number_of_sessions_all_tags}"
}

# The processed and formatted information that composes the report for
# both statistics and Pomodoro sessions is printed using this function.
#
# Return:
# Prints the statistics report, the Pomodoro sessions report or both.
function show_report()
{
  local flag="$1"

  flag=${flag:-'SILENT'}

  if [[ -n "${options_values['STATISTICS']}" && -n "${statistics_raw_data}" ]]; then
    say "# Statistics Report: ${target_period}"
    printf '%20s %4s %8s %12s\n' 'Total' 'Max' 'Min' 'Average'
    for command in "${!statistics[@]}"; do
      [[ -n "${statistics["$command"]}" ]] && printf '%s\n' "${statistics["$command"]}"
    done
    printf '\n'
  elif [[ -n "${options_values['STATISTICS']}" ]]; then
    warning "${options_values['ERROR']}"
  fi

  if [[ -n "${options_values['POMODORO']}" && -n "${pomodoro_raw_data}" ]]; then
    say "# Pomodoro Report: ${target_period}"
    printf '%s\n\n' "${pomodoro_metadata['ALL_TAGS']}"
    for tag in "${!pomodoro_sessions[@]}"; do
      say "## ${tag}"
      printf '%s\n' "${pomodoro_metadata["$tag"]}"
      printf '%s\n%s\n' '- Sessions:' "${pomodoro_sessions["$tag"]}"
    done
  elif [[ -n "${options_values['POMODORO']}" ]]; then
    warning "${options_values['ERROR']}"
  fi
}

# Save report output to a file.
#
# @path: Where to save
#
# Return:
# In case of error, return an error code.
function save_data_to()
{
  local path="$1"
  local flag="$2"
  local ret

  flag=${flag:-'SILENT'}

  if [[ -d "$path" ]]; then
    path="${path}/report_output"
  fi

  cmd_manager "$flag" "touch ${path} 2> /dev/null"

  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain "Failed to create ${path}, please check if this is a valid path"
    exit "$ret"
  fi

  show_report >> "$path"
  success -n "The report output was saved in: "
  success "${path}" | tr -s '/'
}

function parse_report_options()
{
  local reference_count=0
  local long_options='day::,week::,month::,year::,output:,statistics,pomodoro,all,verbose'
  local short_options='o:,s,p,a'
  local options

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw report' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['DAY']=''
  options_values['WEEK']=''
  options_values['MONTH']=''
  options_values['YEAR']=''
  options_values['OUTPUT']=''
  options_values['STATISTICS']=''
  options_values['POMODORO']=''
  options_values['VERBOSE']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --day)
        if [[ -n "$2" ]]; then
          options_values['DAY']=$(date_to_format "$2" '+%Y/%m/%d')
          if [[ "$?" != 0 ]]; then
            complain "$2 is an invalid date"
            return 22 # EINVAL
          fi
        else
          options_values['DAY']=$(get_today_info '+%Y/%m/%d')
        fi

        reference_count+=1
        shift 2
        ;;
      --week)
        if [[ -n "$2" ]]; then
          date --date "$2" > /dev/null 2>&1
          if [[ "$?" != 0 ]]; then
            complain "$2 is an invalid date"
            return 22 # EINVAL
          fi
          options_values['WEEK']=$(get_days_of_week "$2")
        else
          options_values['WEEK']=$(get_days_of_week)
        fi

        reference_count+=1
        shift 2
        ;;
      --month)
        if [[ -n "$2" ]]; then
          options_values['MONTH']=$(date_to_format "$2/01" '+%Y/%m')
          if [[ "$?" != 0 ]]; then
            complain "$2 is an invalid date"
            return 22 # EINVAL
          fi
        else
          options_values['MONTH']=$(get_today_info '+%Y/%m')
        fi

        reference_count+=1
        shift 2
        ;;
      --year)
        if [[ -n "$2" ]]; then
          options_values['YEAR']=$(date_to_format "$2/01/01" +%Y)
          if [[ "$?" != 0 ]]; then
            complain "$2 is an invalid date"
            return 22 # EINVAL
          fi
        else
          options_values['YEAR']=$(date +%Y)
        fi

        reference_count+=1
        shift 2
        ;;
      --output | -o)
        options_values['OUTPUT']="$2"
        shift 2
        ;;
      --statistics | -s)
        options_values['STATISTICS']=1
        shift
        ;;
      --pomodoro | -p)
        options_values['POMODORO']=1
        shift
        ;;
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      --all | -a)
        options_values['STATISTICS']=1
        options_values['POMODORO']=1
        shift
        ;;
      --)
        shift
        ;;
      *)
        options_values['ERROR']="Unrecognized argument: $1"
        shift
        return 22 # EINVAL
        ;;
    esac
  done

  if [[ -z "${options_values['STATISTICS']}" && -z "${options_values['POMODORO']}" ]]; then
    options_values['STATISTICS']=1
    options_values['POMODORO']=1
  fi

  if [[ "$reference_count" -gt 1 ]]; then
    complain 'Please, only use a single time reference'
    return 22
  elif [[ "$reference_count" == 0 ]]; then
    # If no option, set day as a default
    options_values['DAY']=$(get_today_info '+%Y/%m/%d')
  fi
}

function report_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'report'
    return
  fi
  printf '%s\n' 'kw report:' \
    '  report (-p | --pomodoro) [--day | --week | --month | --year] - Pomodoro report for current date' \
    '  report (-s | --statistics) [--day | --week | --month | --year] - Statistics for current date' \
    '  report (-a | --all) [--day | --week | --month | --year] - Display all the information for the current date' \
    '  report [--day[=<year>/<month>/<day>]] - Display all the information for the specified day' \
    '  report [--week[=<year>/<month>/<day>]] - Display all the information for the specified week' \
    '  report [--month[=<year>/<month>]] - Display all the information for the specified month' \
    '  report [--year[=<year>]] - Display all the information for the specified year' \
    '  report [--output <path>] - Save report to <path>' \
    '  report [--verbose] - Show a detailed output'
}

load_kworkflow_config
