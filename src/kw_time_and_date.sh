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
  week_day_num=$(date -d "$date_param" '+%u')

  date --date="${date_param} - ${week_day_num} day" "$format"
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
  date -d "$value" "$format"
}
