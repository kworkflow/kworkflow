# kw keeps track of some data operation in daily use, and this file intends to
# process all data based on the user request. Here you going to find functions
# responsible for aggregate and calculate values such as average and total.

. "$KW_LIB_DIR/kw_config_loader.sh" --source-only

# This is a data struct that describes the main type of data collected. We use
# this in some internal loops.
declare -a statistics_opt=( "deploy" "build" "list" "uninstall" "build_failure" "Modules_deploy" )

# ATTENTION:
# This variable is shared between function, for this reason, it is NOT SAFE to
# parallelize code inside this file. We use this array a temporary data
# container to be pass through other functions.
declare -A shared_data=( ["deploy"]='' ["build"]='' ["list"]='' ["uninstall"]='' ["build_failure"]='' ["Modules_deploy"]='' )

function statistics()
{
  local info_request="$1"
  local day=$(date +%d)
  local year_month_dir=$(date +%Y/%m)
  local date_param

  if [[ "$1" == -h ]]; then
    statistics_help
    exit 0
  fi

  shift 1 # Remove the first option, i.e., --day, --week, or --year
  local date_param="$@"

  if [[ ${configurations[disable_statistics_data_track]} == 'yes' ]]; then
    say "You have disable_statistics_data_track marked as 'yes'"
    say "If you want to see the statistics, change this option to 'no'"
    return
  fi

  # Default to day
  if [[ -z "$info_request" ]]; then
    info_request="--day"
  fi

  case "$info_request" in
    --day)
      if [[ -z "$date_param" ]]; then
        target_day="$statistics_path/$year_month_dir/$day"
      else
        target_day="$statistics_path/$(date -d"$date_param" +%Y/%m/%d)"
        if [[ "$?" != 0 ]]; then
          complain "Invalid parameter: $date_param"
          return 22 # EINVAL
        fi
      fi
      day_statistics "$target_day"
    ;;
    --week)
      local week_day_num=$(date +%u)
      local first_week_day

      first_week_day=$(date --date="${date_param} -${week_day_num} day" +%Y/%m/%d)
      if [[ ! -z "$@" ]]; then
        week_day_num=$(date -d"$@" +%u)
        if [[ "$?" != 0 ]]; then
          complain "Invalid parameter: $@"
          return 22 # EINVAL
        fi
        first_week_day=$(date --date="${date_param} -${week_day_num} day" +%Y/%m/%d)
      fi
      week_statistics "$first_week_day"
    ;;
    --month)
      if [[ ! -z "$@" ]]; then
        # First month of the month
        year_month_dir=$(date -d "$@/01" +%Y/%m)
        if [[ "$?" != 0 ]]; then
          complain "Invalid parameter: $@"
          return 22 # EINVAL
        fi
      fi
      month_statistics "$year_month_dir"
    ;;
    --year)
      local year=$(date +%Y)

      if [[ ! -z "$@" ]]; then
        year=$(date -d "$@/01/01" +%Y)
        if [[ "$?" != 0 ]]; then
          complain "Invalid parameter: $@"
          return 22 # EINVAL
        fi
      fi

      year_statistics "$year"
    ;;
    *)
      complain "Invalid parameter: $info_request"
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
    sum=$(( sum + value ))
    (( count++ ))
  done

  avg=$(( sum / count ))

  echo "$avg"
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

  echo "$list_of_values" | wc -w
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

  echo "$max"
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

  echo "$min"
}

# Change seconds to H:M:S
#
# @value Value in seconds to be converted to H:M:S
#
# Return:
# Return a string in the format H:M:S
function sec_to_formatted_date()
{
  local value="$1"

  value=${value:-"0"}
  echo $(date -d@$value -u +%H:%M:%S)
}

# Print results of "Total Max Min Average" organized in columns.
#
# Note: This function relies on a global variable named shared_data.
function print_basic_data()
{
  local header_format="%20s %4s %8s %12s\n"
  local row_format="%-14s %5d %s %s %s\n"

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
  local all_data="$@"
  # Calculate build value
  local build_values
  local avg_build
  local total_build
  local max
  local min

  for option in "${statistics_opt[@]}"; do
    values=$(echo -e "$all_data" | grep "$option" | cut -d' ' -f2-)
    [[ -z "$values" ]] && continue

    # Calculate values
    avg_build=$(calculate_average "$values")
    total_build=$(calculate_total_of_data "$values")
    max=$(max_value "$values")
    min=$(min_value "$values" "$max")

    ## Format values
    max=$(sec_to_formatted_date "$max")
    min=$(sec_to_formatted_date "$min")
    avg=$(sec_to_formatted_date "$avg_build")
    shared_data["$option"]="$total_build $max $min $avg"
  done
}

# This function relies on basic_data_process to calculate the data related to a
# target day passed via parameter. At the end, it prints the result in the
# terminal.
#
# @day_path Path to the target day
function day_statistics()
{
  local day_path="$1"

  if [[ ! -f "$day_path" ]]; then
    say "Currently, kw does not have any data for the present date."
    return 0
  fi

  # Check if the day file is empty
  data=$(cat "$day_path")
  if [[ -z "$data" ]]; then
    say "There is no data in the kw records"
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
  local current_week_day_num=$(date +%u)
  local week_begin=$(date -d "$date -$current_week_day_num days" +"%d")
  local all_data=""

  first=${first:-$(date +%Y/%m/%d)}

  # 7 -> week days
  for (( i=0 ; i < 7 ; i++ )); do
    day=$(date --date="${first} +${i} day" +%Y/%m/%d)
    [[ ! -f "$statistics_path/$day" ]] && continue

    all_file_data=$(cat "$statistics_path/$day")
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
  local month_path="$statistics_path/$1"
  local all_data=""

  if [[ ! -d "$month_path" ]]; then
    say "Currently, kw does not have any data for the present month."
    return 0
  fi

  for day in $(ls $month_path); do
    all_file_data=$(cat "$month_path/$day")
    [[ -z "$all_file_data" ]] && continue

    all_data="${all_data}${all_file_data}\n"
  done

  if [[ -z "$all_data" ]]; then
    say "Sorry, kw does not have any record for $1"
    return 0
  fi

  local pretty_month=$(date -d"$1/01" +%B)
  basic_data_process "$all_data"
  say "$pretty_month summary ($1/01)"
  print_basic_data
}

function year_statistics()
{
  local year="$1"

  if [[ ! -d "$statistics_path/$year" ]]; then
    say "Currently, kw does not have any data for the requested year."
    return 0
  fi

  all_year_file=$(find "$statistics_path/$year" -follow)

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
  echo -e "kw statistics:\n" \
    "\tstatistics [--day [YEAR/MONTH/DAY]]\n" \
    "\tstatistics [--week [YEAR/MONTH/DAY]]\n" \
    "\tstatistics [--month [YEAR/MONTH]]\n" \
    "\tstatistics [--year [YEAR]]"
}
