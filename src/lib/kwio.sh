# NOTE: src/lib/kw_config_loader.sh must be included before this file
declare -gr BLUECOLOR='\033[1;34;49m%s\033[m'
declare -gr REDCOLOR='\033[1;31;49m%s\033[m'
declare -gr YELLOWCOLOR='\033[1;33;49m%s\033[m'
declare -gr GREENCOLOR='\033[1;32;49m%s\033[m'
declare -gr SEPARATOR='========================================================='

# Alerts command completion to the user.
function alert_completion()
{
  local COMMAND=$1
  local ALERT_OPT=$2
  local opts

  if [[ $# -gt 1 && "$ALERT_OPT" =~ ^--alert= ]]; then
    opts="$(printf '%s\n' "$ALERT_OPT" | sed s/--alert=//)"
  else
    opts="${notification_config[alert]}"
  fi

  while read -rN 1 option; do
    if [ "$option" == 'v' ]; then
      if command_exists "${notification_config[visual_alert_command]}"; then
        eval "${notification_config[visual_alert_command]} &"
      else
        warning 'The following command set in the visual_alert_command variable could not be run:'
        warning "${notification_config[visual_alert_command]}"
        warning 'Check if the necessary packages are installed.'
      fi
    elif [ "$option" == 's' ]; then
      if command_exists "${notification_config[sound_alert_command]}"; then
        eval "${notification_config[sound_alert_command]} &"
      else
        warning 'The following command set in the sound_alert_command variable could not be run:'
        warning "${notification_config[sound_alert_command]}"
        warning 'Check if the necessary packages are installed.'
      fi
    fi
  done <<< "$opts"
}

# Print colored message safely (EPIPE-protected)
#shellcheck disable=SC2059
function colored_print()
{
  local message="${*:2}"
  local colored_format="${!1}"

  if [[ $# -ge 2 && $2 = '-n' ]]; then
    message="${*:3}"
    if [ -t 1 ]; then
      printf "$colored_format" "$message"
    else
      printf '%s' "$message" 2> /dev/null || true
    fi
  else
    if [ -t 1 ]; then
      printf "$colored_format\n" "$message"
    else
      printf '%s\n' "$message" 2> /dev/null || true
    fi
  fi
}

function say()
{
  colored_print BLUECOLOR "$@"
}
function complain()
{
  colored_print REDCOLOR "$@"
}
function warning()
{
  colored_print YELLOWCOLOR "$@"
}
function success()
{
  colored_print GREENCOLOR "$@"
}

# Yes/No helper
function ask_yN()
{
  local message="$1"
  local default_option="${2:-'n'}"
  local yes='y'
  local no='N'

  if [[ "$default_option" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    yes='Y'
    no='n'
  fi

  message="$message [$yes/$no]"
  response=$(ask_with_default "$message" "$default_option" false)

  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    printf '%s\n' '1'
  else
    printf '%s\n' '0'
  fi
}

# asks via ssh
function ask_yN_ssh()
{
  local message="$*"

  printf '\n%s [y/N]: ' "$message"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    return 1
  else
    return 0
  fi
}

# ask with default
function ask_with_default()
{
  local message="$1"
  local default_option="$2"
  local show_default="$3"
  local flag="$4"
  local value

  if [[ -z "$show_default" ]]; then
    message+=" ($default_option)"
  fi
  message+=': '

  [[ "$flag" == 'TEST_MODE' ]] && printf '%s\n' "$message"

  read -r -p "$message" response

  if [[ "$?" -ne 0 || -z "$response" ]]; then
    printf '%s\n' "$default_option"
    return
  fi

  printf '%s\n' "$response"
}

# Load text blocks from file
function load_module_text()
{
  local text_file_to_be_loaded_path="$1"
  local key=''
  local line_counter=0
  local error=0
  local key_set=0
  local first_line=0

  unset module_text_dictionary
  declare -gA module_text_dictionary

  if [[ ! -f "$text_file_to_be_loaded_path" ]]; then
    complain "[ERROR]:$text_file_to_be_loaded_path: Does not exist or is not a text file."
    return 2
  fi

  if [[ ! -s "$text_file_to_be_loaded_path" ]]; then
    complain "[ERROR]:$text_file_to_be_loaded_path: File is empty."
    return 61
  fi

  while read -r line; do
    ((line_counter++))

    if [[ "$line" =~ ^\[(.*)\]:$ ]]; then
      key=''
      [[ "${BASH_REMATCH[1]}" =~ (^[A-Za-z0-9_][A-Za-z0-9_]*$) ]] && key="${BASH_REMATCH[1]}"

      if [[ -z "$key" ]]; then
        error=129
        complain "[ERROR]:$text_file_to_be_loaded_path:$line_counter: Keys should be alphanum chars."
        continue
      fi

      if [[ -n "${module_text_dictionary[$key]}" ]]; then
        warning "[WARNING]:$text_file_to_be_loaded_path:$line_counter: Overwriting '$key' key."
      fi

      key_set=1
      first_line=1
      module_text_dictionary["$key"]=''
    elif [[ -n "$key" ]]; then
      if [[ "$first_line" -eq 1 ]]; then
        first_line=0
      else
        module_text_dictionary["$key"]+=$'\n'
      fi
      module_text_dictionary["$key"]+="$line"
    fi
  done < "$text_file_to_be_loaded_path"

  if [[ "$key_set" -eq 0 ]]; then
    error=126
    complain "[ERROR]:$text_file_to_be_loaded_path: No key found."
  fi

  return "$error"
}
