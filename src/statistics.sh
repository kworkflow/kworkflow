# kw keeps track of some data operation in daily use, and this file intends to
# process all data based on the user request. Here you going to find functions
# responsible for aggregate and calculate values such as average and total.

include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kw_time_and_date.sh"

# This is a data struct that describes the main type of data collected. We use
# this in some internal loops.
declare -ga statistics_opt=('deploy' 'build' 'list' 'uninstall' 'build_failure' 'Modules_deploy')

# ATTENTION:
# This variable is shared between function, for this reason, it is NOT SAFE to
# parallelize code inside this file. We use this array a temporary data
# container to be pass through other functions.
declare -gA shared_data=(["deploy"]='' ["build"]='' ["list"]='' ["uninstall"]='' ["build_failure"]='' ["Modules_deploy"]='')

function statistics()
{
  local target="$1"
  local day
  local week
  local month
  local year

  if [[ "$1" =~ -h|--help ]]; then
    statistics_help "$1"
    exit 0
  fi

  shift 1 # Remove the first option, i.e., --day, --week, or --year

  if [[ "${configurations[disable_statistics_data_track]}" == 'yes' ]]; then
    say "You have disable_statistics_data_track marked as 'yes'"
    say "If you want to see the statistics, change this option to 'no'"
    return
  fi

  # Default to day
  if [[ -z "$target" ]]; then
    target='--day'
  fi

  case "$target" in
    --day)
      day=$(get_today_info '+%Y/%m/%d')
      if [[ -n "$*" ]]; then
        day=$(date_to_format "$*" '+%Y/%m/%d')
        if [[ "$?" != 0 ]]; then
          complain "Invalid parameter: $*"
          return 22 # EINVAL
        fi
      fi
      day_statistics "$day"
      ;;
    --week)
      # First day of the week
      week=$(get_week_beginning_day)
      if [[ -n "$*" ]]; then
        week=$(get_week_beginning_day "$*")
        if [[ "$?" != 0 ]]; then
          complain "Invalid parameter: $*"
          return 22 # EINVAL
        fi
      fi
      week_statistics "$week"
      ;;
    --month)
      month=$(get_today_info '+%Y/%m')
      if [[ -n "$*" ]]; then
        # First day of the month
        month=$(date_to_format "$*/01" '+%Y/%m')
        if [[ "$?" != 0 ]]; then
          complain "Invalid parameter: $*"
          return 22 # EINVAL
        fi
      fi
      month_statistics "$month"
      ;;
    --year)
      year=$(date +%Y)
      if [[ -n "$*" ]]; then
        year=$(date_to_format "$*/01/01" +%Y)
        if [[ "$?" != 0 ]]; then
          complain "Invalid parameter: $*"
          return 22 # EINVAL
        fi
      fi
      year_statistics "$year"
      ;;
    *)
      complain "Invalid parameter: $target"
      return 22 # EINVAL
      ;;
  esac

}

# Calculate average value from a list of values separated by space.
#
# @list_of_values List of values separated with space
#
# Return:
# Return list average
#
# Note: Bash only support integer, if you pass a float point value you should
# expect a syntax error.
function calculate_average()
{
  local list_of_values="$1"
  local count=0
  local sum=0
  local avg=0

  for value in $list_of_values; do
    sum=$((sum + value))
    ((count++))
  done

  avg=$((sum / count))

  printf '%s\n' "$avg"
}

# Get the total of data in a list
#
# @list_of_values List of values separated with space
#
# Return:
# Return the total of elements in a list
function calculate_total_of_data()
{
  local list_of_values="$1"

  printf '%s\n' "$list_of_values" | wc -w
}

# Find the highest value in a list of numbers.
#
# @list_of_values List of values separated with space
#
# Return:
# Return the max value from a list
function max_value()
{
  local list_of_values="$1"
  local max=0

  for value in $list_of_values; do
    [[ "$value" -gt "$max" ]] && max="$value"
  done

  printf '%s\n' "$max"
}

# Find the lowest value in a list of numbers.
#
# @list_of_values List of values separated with space
# @min Base number for finding the minimum value
#
# Return:
# Return the minimun value from a list
function min_value()
{
  local list_of_values="$1"
  local min="$2"

  for value in $list_of_values; do
    [[ "$value" -lt "$min" ]] && min="$value"
  done

  printf '%s\n' "$min"
}

# Print results of "Total Max Min Average" organized in columns.
#
# Note: This function relies on a global variable named shared_data.
#shellcheck disable=SC2059,SC2086
function print_basic_data()
{
  local header_format='%20s %4s %8s %12s\n'
  local row_format='%-14s %5d %s %s %s\n'

  printf "$header_format" Total Max Min Average
  for option in "${statistics_opt[@]}"; do
    [[ -z "${shared_data[$option]}" ]] && continue
    printf "$row_format" "${option^}" ${shared_data[$option]}
  done
}

# This function expect a list of values organized as "<LABEL> <VALUE>", it will
# calculate the total of elements, maximum, minimum, and average per label.
# Each value calculated in this function is converted to "H:M:S" format and
# concatenated per element label in the shared array named `shared_data`.
#
# @all_data List of elements organized as "<LABEL> <VALUE>\n", notice the
# requirement of newline character.
#
# Return:
# This function fill out the shared array `shared_data`
function basic_data_process()
{
  local all_data="$*"
  # Calculate values from each operation
  local avg_operation
  local total_operation
  local max
  local min

  for option in "${statistics_opt[@]}"; do
    values=$(echo -e "$all_data" | grep "$option" | cut -d' ' -f2-) # TODO
    [[ -z "$values" ]] && continue

    # Calculate values
    avg_operation=$(calculate_average "$values")
    total_operation=$(calculate_total_of_data "$values")
    max=$(max_value "$values")
    min=$(min_value "$values" "$max")

    ## Format values
    max=$(sec_to_format "$max")
    min=$(sec_to_format "$min")
    avg=$(sec_to_format "$avg_operation")
    shared_data["$option"]="$total_operation $max $min $avg"
  done
}

# This function relies on basic_data_process to calculate the data related to a
# target day passed via parameter. At the end, it prints the result in the
# terminal.
#
# @date Target day
# @day_path Path to the target day
function day_statistics()
{
  local date="$1"
  local day_path="$KW_DATA_DIR/statistics/$date"

  if [[ ! -f "$day_path" ]]; then
    say 'Currently, kw does not have any data for the present date.'
    return 0
  fi

  # Check if the day file is empty
  data=$(cat "$day_path")
  if [[ -z "$data" ]]; then
    say 'There is no data in the kw records'
    return 0
  fi

  say "$date summary"
  basic_data_process "$data"
  print_basic_data
}

# This function relies on basic_data_process to calculate the data related to a
# target week passed via parameter. At the end, it prints the result in the
# terminal.
#
# @first First day of the week
function week_statistics()
{
  local first="$1"
  local all_data=""

  first=${first:-$(get_today_info '+%Y/%m/%d')}

  # 7 -> week days
  for ((i = 0; i < 7; i++)); do
    day=$(date --date="${first} +${i} day" +%Y/%m/%d)
    [[ ! -f "$KW_DATA_DIR/statistics/$day" ]] && continue

    all_file_data=$(cat "$KW_DATA_DIR/statistics/$day")
    [[ -z "$all_file_data" ]] && continue

    all_data="${all_data}${all_file_data}\n"
  done

  if [[ -z "$all_data" ]]; then
    say "Sorry, kw does not have any data from $first to $day"
    return 0
  fi

  basic_data_process "$all_data"
  say "Week summary: From $first to $day"
  print_basic_data
}

function month_statistics()
{
  local month="$1"
  local month_path="$KW_DATA_DIR/statistics/$month"
  local all_data=""
  local pretty_month
  local current_path

  if [[ ! -d "$month_path" ]]; then
    say 'Currently, kw does not have any data for the present month.'
    return 0
  fi

  current_path=$(pwd)
  cd "$month_path" || exit_msg 'It was not possible to move to month dir'
  shopt -s nullglob
  for day in *; do
    all_file_data=$(cat "$day")
    [[ -z "$all_file_data" ]] && continue

    all_data="${all_data}${all_file_data}\n"
  done
  cd "$current_path" || exit_msg 'It was not possible to move back from month dir'

  if [[ -z "$all_data" ]]; then
    say "Sorry, kw does not have any record for $month"
    return 0
  fi

  pretty_month=$(date_to_format "$1/01" '+%B')
  basic_data_process "$all_data"
  say "$pretty_month summary ($month/01)"
  print_basic_data
}

function year_statistics()
{
  local year="$1"
  local year_path="$KW_DATA_DIR/statistics/$year"
  local all_year_file

  if [[ ! -d "$year_path" ]]; then
    say 'Currently, kw does not have any data for the requested year.'
    return 0
  fi

  all_year_file=$(find "$KW_DATA_DIR/statistics/$year" -follow)

  # We did not add "" around all_year_file on purpose
  for day_full_path in $all_year_file; do
    [[ -d "$day_full_path" ]] && continue

    all_file_data=$(cat "$day_full_path")
    [[ -z "$all_file_data" ]] && continue

    all_data="${all_data}${all_file_data}\n"
  done

  basic_data_process "$all_data"
  say "$year summary"
  print_basic_data
}

function statistics_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'statistics'
    return
  fi
  printf '%s\n' 'kw statistics:' \
    '  statistics - Statistics for current date' \
    '  statistics --day [<year>/<month>/<day>] - Statistics of given day' \
    '  statistics --week [<year>/<month>/<day>] - Statistics of given week' \
    '  statistics --month [<year>/<month>] - Statistics of given month' \
    '  statistics --year [<year>] - Statistics of given year'
}
