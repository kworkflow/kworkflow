include "${KW_LIB_DIR}/kw_string.sh"
include "${KW_LIB_DIR}/kwio.sh"

# Returns the value of time as an integer number of seconds since the Epoch.
function get_timestamp_sec()
{
  date +%s
}

# Change seconds to H:M:S
#
# @value Value in seconds to be converted to H:M:S
#
# Return:
# Return a string in the format H:M:S
function sec_to_format()
{
  local value="$1"
  local format="$2"

  value=${value:-"0"}
  format=${format:-'+%H:%M:%S'}

  date -d@"$value" -u "$format"
}

# Convert seconds to arbitrarily long value in the format H:M:S. This means
# that values greater than 86399 seconds (23:59:59 in format) won't loop
# back around the '24-Hour Time Format'. For example, calling
#   secs_to_arbitrarily_long_hours_mins_secs 86400
# would return '24:00:00', not '00:00:00'.
#
# @value: Value in seconds to be converted to arbitrarily long value in H:M:S
#
# Return:
# Return 0 and a string with the arbitrarily long value in H:M:S format
# if @value is an integer. Return 22 (EINVAL) otherwise.
function secs_to_arbitrarily_long_hours_mins_secs()
{
  local value="$1"
  local hours
  local minutes
  local seconds

  # If value is not an integer, we can't convert it
  [[ ! "$value" =~ ^[0-9]+$ ]] && return 22 # EINVAL

  hours=$((value / 3600))
  minutes=$(((value / 60) % 60))
  seconds=$((value % 60))

  # Append leading zero if necessary
  [[ "${#hours}" -lt 2 ]] && hours="0${hours}"
  [[ "${#minutes}" -lt 2 ]] && minutes="0${minutes}"
  [[ "${#seconds}" -lt 2 ]] && seconds="0${seconds}"

  printf '%s:%s:%s' "$hours" "$minutes" "$seconds"
}

# Return present day.
#
# @format: Date format parameter, for more information about formats, use
#          `man date`.
function get_today_info()
{
  local format="$1"
  [[ -z "$format" ]] && date && return 0
  date "$format"
}

# Based on any date, this function returns the first day of the week referenced
# to the base date.
#
# @date_param: It represents the date reference used to derive the first day of
#              that week. If null, it will assumes today.
# @format: Date format parameter, for more information about formats, use
#          `man date`. If it is null, assumes YYYY/MM/DD.
#
# Return:
# The first day of the week. If format is wrong, date will return an error
# code.
function get_week_beginning_day()
{
  local date_param="$1"
  local format="$2"

  format=${format:-'+%Y/%m/%d'}
  date_param=${date_param:-$(date '+%Y/%m/%d')}
  week_day_num=$(date -d "$date_param" '+%w' 2> /dev/null)

  date --date="${date_param} - ${week_day_num} day" "$format" 2> /dev/null
}

# Based on any date, this function returns a string with all the days of a
# certain week from sunday to saturday. In the return string, the dates are
# separeted by the pipe character '|'. This function depends on the function
# 'get_week_beginning_day'.
#
# @date_param: It represents the date reference used to derive the first day of
#              that week. If null, it will assumes today.
# @format: Date format parameter, for more information about formats, use
#          `man date`. If it is null, assumes YYYY/MM/DD.
#
# Return:
# String with all days of given week. If format is wrong, the call to the
# 'get_week_beginning_day' function will return an error code that will be
# returned by this function.
function get_days_of_week()
{
  local date_param="$1"
  local format=${2:-'+%Y/%m/%d'}
  local beginning_day_of_week
  local days_of_week
  local ret

  beginning_day_of_week=$(get_week_beginning_day "${date_param}" "$format")
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain "Invalid date ${date_param}"
    return "$ret"
  fi

  days_of_week="${beginning_day_of_week}"
  for ((i = 1; i < 7; i++)); do
    day=$(date --date="${beginning_day_of_week} + ${i} day" "$format")
    days_of_week+="|${day}"
  done

  printf '%s' "${days_of_week}"
}

# Convert a value to a specific date format. If uses do not provide any format,
# this function will use YYYY/MM/DD.
#
# @value: Raw date to be formated
# @format: Date format. If it is empty, it assumes '+%Y/%m/%d'
#
# Return:
# Formated date
function date_to_format()
{
  local value="$1"
  local format="$2"

  format=${format:-'+%Y/%m/%d'}
  value=${value:-$(date "$format")}
  date -d "$value" "$format" 2> /dev/null
}

# Return the total number of days in a specific month.
#
# @month_number: The number that represents the target month. If it is null,
#                this function assumes the current month.
# @year: Target year. If it is empty, this function assumes this year.
#
# Return:
# Return an integer number that represents the total days in the specific
# month. In case of error, return 22.
function days_in_the_month()
{
  local month_number="$1"
  local year="$2"
  local days=31
  local short=(4 04 6 06 9 09 11) # list of months with 30 days

  month_number="$(printf '%s\n' "obase=10; $month_number" | bc)"

  if [[ -n "$month_number" ]] && [[ "$month_number" -lt 1 || "$month_number" -gt 12 ]]; then
    return 22 # EINVAL
  fi

  month_number=${month_number:-$(date +%m)}
  year=${year:-$(date +%Y)}

  # check if it's a leap year
  if [[ "$month_number" =~ ^0?2$ ]]; then
    if ((year % 4 != 0)); then
      days=28
    elif ((year % 100 != 0)); then
      days=29
    elif ((year % 400 != 0)); then
      days=28
    else
      days=29
    fi
  # check if it's a short month
  elif [[ "${short[*]}" =~ (^|[[:space:]])"$month_number"($|[[:space:]]) ]]; then
    days=30
  fi

  printf '%s\n' "$days"
}

# Convert a time in timebox format to the time value in seconds. Example:
# calling 'timebox_to_sec 2h' returns the string '7200'.
#
# @timebox: Timebox in the format <INTEGER>(h|m|s)
#
# Return:
# If timebox is valid, returns 0 and a string with the time value in seconds.
# Returns 22 (EINVAL) otherwise.
function timebox_to_sec()
{
  local timebox="$1"
  local time_type
  local time_value

  if [[ ! "$timebox" =~ ^[0-9]+(h|m|s)$ ]]; then
    return 22 # EINVAL
  fi

  time_type=$(last_char "$timebox")
  time_value=$(chop "$timebox")

  case "$time_type" in
    h)
      time_value=$((3600 * time_value))
      ;;
    m)
      time_value=$((60 * time_value))
      ;;
    s)
      true # Do nothing
      ;;
  esac

  printf '%s\n' "$time_value"
}
