# kw keeps track of some data operations; the most prominent example is the
# Pomodoro feature. This file intends to keep all procedures related to data
# processing that will end up as a report for the user.

include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kw_time_and_date.sh"

declare -gA options_values

function report()
{
  local ret

  report_parse "$@"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    return "$ret"
  fi
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
