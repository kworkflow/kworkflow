# NOTE: src/kw_config_loader.sh must be included before this file
declare -gr BLUECOLOR='\033[1;34;49m%s\033[m'
declare -gr REDCOLOR='\033[1;31;49m%s\033[m'
declare -gr YELLOWCOLOR='\033[1;33;49m%s\033[m'
declare -gr GREENCOLOR='\033[1;32;49m%s\033[m'
declare -gr SEPARATOR='========================================================='

# Alerts command completion to the user.
#
# @COMMAND First argument should be the kw command string which the user wants
#          to get notified about. It can be printed in visual notification if
#          ${configurations[visual_alert_command]} uses it.
# @ALERT_OPT Second argument is the string with the "--alert=" option or "" if
#            no alert option was given by the user.
function alert_completion()
{

  local COMMAND=$1
  local ALERT_OPT=$2
  local opts

  if [[ $# -gt 1 && "$ALERT_OPT" =~ ^--alert= ]]; then
    opts="$(printf '%s\n' "$ALERT_OPT" | sed s/--alert=//)"
  else
    opts="${configurations[alert]}"
  fi

  while read -rN 1 option; do
    if [ "$option" == 'v' ]; then
      if command_exists "${configurations[visual_alert_command]}"; then
        eval "${configurations[visual_alert_command]} &"
      else
        warning 'The following command set in the visual_alert_command variable could not be run:'
        warning "${configurations[visual_alert_command]}"
        warning 'Check if the necessary packages are installed.'
      fi
    elif [ "$option" == 's' ]; then
      if command_exists "${configurations[sound_alert_command]}"; then
        eval "${configurations[sound_alert_command]} &"
      else
        warning 'The following command set in the sound_alert_command variable could not be run:'
        warning "${configurations[sound_alert_command]}"
        warning 'Check if the necessary packages are installed.'
      fi
    fi
  done <<< "$opts"
}

# Print colored message. This function verifies if stdout
# is open and print it with color, otherwise print it without color.
#
# @param $1 [${@:2}] [-n ${@:3}] it receives the variable defining
# the color to be used and two optional params:
#   - the option '-n', to not output the trailing newline
#   - text message to be printed
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
      printf '%s' "$message"
    fi
  else
    if [ -t 1 ]; then
      printf "$colored_format\n" "$message"
    else
      printf '%s\n' "$message"
    fi
  fi
}

# Print normal message (e.g info messages).
function say()
{
  colored_print BLUECOLOR "$@"
}

# Print error message.
function complain()
{
  colored_print REDCOLOR "$@"
}

# Warning error message.
function warning()
{
  colored_print YELLOWCOLOR "$@"
}

# Print success message.
function success()
{
  colored_print GREENCOLOR "$@"
}

# Allows the user to select a given question with yes or no answers. Shows a
# default option (as a capitalized letter). If the user inserts anything
# different from a "y" or a "yes" (capitalization doesn't matter here) it will
# be treated as a "no".
#
# @message A string with the message to be displayed for the user.
# @default_option A string (simply y or n) to set the default answer for the
#                 user. If this parameter is not given, or if it is invalid, 'n'
#                 will be used.
#
# Return:
# Return "1" if the user accept the question, otherwise, return "0"
# Note: ask_yN return the string '1' and '0', you have to handle it by
# yourself in the code.
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

# Asks for user input
#
# @message A string with the message to be displayed to the user.
# @default_option String with default answer to be used if no input is given.
# @show_default A string that defines if the default value will be printed to
#               the user. Any non-empty value causes this behavior to be false.
# @flag String to mark special conditions in this function. To activate the test
#       mode, set this to 'TEST_MODE'.
#
# Return:
# The user answer, guaranteed not to be empty.
# Note: this function does not verify the given answer. You have to handle this
# somewhere else.
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

# Load text from a file into a dictionary. The file that
# will be read must have a key before a body of text to
# name that particular body of text, as in this example:
#
# [KEY]:
# text
#
# @path  the full path of the text file to be loaded
#        as the first argument.
#
# KEY must be non-empty, alphanumeric and between square brackets followed by a
# colon. The global array string_file can then be queried by key as in
# ${string_file[KEY]} to obtain the string. KEY should be named according
# to its respective module for compatibility. That is, if we have modules A and B,
# name A's keys as [KEY_A] and B's keys as [KEY_B]. This makes it so the modules
# keys will be compatible with each other
#
# Return:
# SUCCESS      : In case of success.
# EKEYREJECTED : If an invalid key is found, prints the line with a bad key.
# ENOKEY       : If a key is not found.
# ENOENT       : If @path is invalid, or is not a text file.
# ENODATA      : If the file given in @path is empty.
function load_module_text()
{
  local path="$1"
  local key=''
  local line_counter=0
  local error=0 # SUCCESS
  local key_set=0

  # Associative array to read strings from files
  unset module_text_dictionary
  declare -gA module_text_dictionary

  if [[ ! -f "$path" ]]; then
    complain "[ERROR]:$path: Does not exist or is not a text file."
    return 2 # ENOENT
  fi

  if [[ ! -s "$path" ]]; then
    complain "[ERROR]:$path: File is empty."
    return 61 # ENODATA
  fi

  while read -r line; do
    ((line_counter++))
    if [[ "$line" =~ ^\[(.*)\]:$ ]]; then
      key=$(printf '%s' "$line" | grep -o -E '\w+')
      if [[ -z "$key" ]]; then
        error=129 # EKEYREJECTED
        complain "[ERROR]:$path:$line_counter: keys should be alphanum chars"
        continue
      fi

      if [[ -n "${module_text_dictionary[$key]}" ]]; then
        warning "[WARNING]:$path:$line_counter: overwriting '$key' key."
      fi

      key_set=1
      module_text_dictionary["$key"]=''
    elif [[ -n "$key" ]]; then
      module_text_dictionary["$key"]+=$'\n'"$line"
    fi
  done < "$path"

  if [[ "$key_set" -eq 0 ]]; then
    error=126 # ENOKEY
    complain "[ERROR]:$path: no key found"
  fi

  return "$error"
}
