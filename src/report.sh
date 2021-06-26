# kw keeps track of some data operations; the most prominent example is the
# Pomodoro feature. This file intends to keep all procedures related to data
# processing that will end up as a report for the user.

include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kw_time_and_date.sh"
include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kw_string.sh"

declare -g KW_POMODORO_DATA="$KW_DATA_DIR/pomodoro"
declare -gA options_values
declare -gA tags_details
declare -gA tags_metadata

function report()
{
  local target_time
  local ret

  report_parse "$@"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    return "$ret"
  fi

  if [[ -n "${options_values['DAY']}" ]]; then
    grouping_day_data "${options_values['DAY']}"
    target_time="${options_values['DAY']}"
  elif [[ -n "${options_values['WEEK']}" ]]; then
    target_time="${options_values['WEEK']}"
  elif [[ -n "${options_values['MONTH']}" ]]; then
    target_time="${options_values['MONTH']}"
  elif [[ -n "${options_values['YEAR']}" ]]; then
    target_time="${options_values['YEAR']}"
  fi
}

# Convert time labels in the format INTEGER[s|m|h] to an entire label that can
# be used inside the command date.
#
# @timebox Time box in the format INTEGER[s|m|h]
#
# Return:
# Expanded label in the format INTEGER [seconds|minutes|hours].
function expand_time_labels()
{
  local timebox="$1"
  local time_type
  local time_value
  local time_label

  timebox=$(str_strip "$timebox")

  [[ -z "$timebox" ]] && return 22 # EINVAL

  time_type=$(last_char "$timebox")
  if [[ ! "$time_type" =~ h|m|s ]]; then
    time_type='s'
    timebox="$timebox$time_type"
  fi

  time_value=$(chop "$timebox")
  if ! str_is_a_number "$time_value"; then
    return 22 # EINVAL
  fi

  case "$time_type" in
    h)
      time_label="$time_value hours"
      ;;
    m)
      time_label="$time_value minutes"
      ;;
    s)
      time_label="$time_value seconds"
      ;;
  esac

  echo "$time_label"
}

# Group day data in the tags_details and tags_metadata. Part of the process
# includes pre-processing raw data in something good to be displayed for users.
#
# @day: Day in the format YYYY/MM/DD
function grouping_day_data()
{
  local day="$*"
  local day_path
  local details
  local metadata
  local start_time
  local end_time
  local timebox
  local time_label

  day_path=$(join_path "$KW_POMODORO_DATA" "$day")
  if [[ ! -f "$day_path" ]]; then
    return 2 # ENOENT
  fi

  # details, total focus time
  while read -r line; do
    tag=$(echo "$line" | cut -d ',' -f1)
    timebox=$(echo "$line" | cut -d ',' -f2)
    start_time=$(echo "$line" | cut -d ',' -f3)
    details=$(echo "$line" | cut -d ',' -f4)
    metadata=$(echo "$line" | cut -d ',' -f 2-)

    time_label=$(expand_time_labels "$timebox")
    [[ "$?" != 0 ]] && continue

    end_time=$(date --date="$start_time $time_label" +%H:%M:%S)

    [[ -n "$details" ]] && details=": $details"
    tags_details["$tag"]+=" * [$start_time-$end_time][$timebox]$details\n"

    tags_metadata["$tag"]+="$metadata"
  done < "$day_path"
}

function report_parse()
{
  local raw_options="$*"
  local day
  local week
  local month
  local year
  local reference=0

  if [[ "$1" == -h ]]; then
    report_help
    exit 0
  fi

  options_values['DAY']=''
  options_values['WEEK']=''
  options_values['MONTH']=''
  options_values['YEAR']=''

  IFS=' ' read -r -a options <<< "$raw_options"
  for option in "${options[@]}"; do
    if [[ "$option" =~ ^(--.*|-.*|test_mode) ]]; then
      case "$option" in
        --day)
          options_values['DAY']=$(get_today_info '+%Y/%m/%d')
          day=1
          reference+=1
          continue
          ;;
        --week)
          options_values['WEEK']=$(get_week_beginning_day)
          week=1
          reference+=1
          continue
          ;;
        --month)
          options_values['MONTH']=$(get_today_info '+%Y/%m')
          month=1
          reference+=1
          continue
          ;;
        --year)
          options_values['YEAR']=$(date +%Y)
          year=1
          reference+=1
          continue
          ;;
        *)
          complain "Invalid option: $option"
          report_help
          return 22 # EINVAL
          ;;
      esac
    else
      if [[ "$day" == 1 ]]; then
        day=0
        if [[ -n "$option" ]]; then
          options_values['DAY']=$(date_to_format "$option" '+%Y/%m/%d')
          if [[ "$?" != 0 ]]; then
            complain "Invalid parameter: $option"
            return 22 # EINVAL
          fi
        fi
      elif [[ "$week" == 1 ]]; then
        # First day of the week
        week=0
        if [[ -n "$option" ]]; then
          options_values['WEEK']=$(get_week_beginning_day "$option")
          if [[ "$?" != 0 ]]; then
            complain "Invalid parameter: $option"
            return 22 # EINVAL
          fi
        fi
      elif [[ "$month" == 1 ]]; then
        month=0
        if [[ -n "$option" ]]; then
          # First day of the month
          options_values['MONTH']=$(date_to_format "$option/01" '+%Y/%m')
          if [[ "$?" != 0 ]]; then
            complain "Invalid parameter: $option"
            return 22 # EINVAL
          fi
        fi
      elif [[ "$year" == 1 ]]; then
        year=0
        if [[ -n "$option" ]]; then
          options_values['YEAR']=$(date_to_format "$option/01/01" +%Y)
          if [[ "$?" != 0 ]]; then
            complain "Invalid parameter: $option"
            return 22 # EINVAL
          fi
        fi
      fi
    fi
  done

  if [[ "$reference" -gt 1 ]]; then
    complain 'Please, only use a single time reference'
    return 22
  fi
}

function report_help()
{
  echo -e "kw report, r:\n" \
    "\treport [--day [YEAR/MONTH/DAY]]\n" \
    "\treport [--week [YEAR/MONTH/DAY]]\n" \
    "\treport [--month [YEAR/MONTH]]\n" \
    "\treport [--year [YEAR]]"
}
