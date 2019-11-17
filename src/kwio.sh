# NOTE: src/commons.sh must be included before this file

declare -r BLUECOLOR="\033[1;34;49m%s\033[m"
declare -r REDCOLOR="\033[1;31;49m%s\033[m"
declare -r YELLOWCOLOR="\033[1;33;49m%s\033[m"
declare -r GREENCOLOR="\033[1;32;49m%s\033[m"
declare -r SEPARATOR="========================================================="

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
    opts="$(echo $ALERT_OPT | sed s/--alert=// )"
  else
    opts="${configurations[alert]}"
  fi

  grep -o . <<< "$opts" | while read option;  do
    if [ "$option" == "v" ]; then
      eval "${configurations[visual_alert_command]} &"
    elif [ "$option" == "s" ]; then
      eval "${configurations[sound_alert_command]} &"
    fi
  done
}

# Print colored message. This function verifies if stdout
# is open and print it with color, otherwise print it without color.
#
# @param $1 [${@:2}] [-n ${@:3}] it receives the variable defining
# the color to be used and two optional params:
#   - the option '-n', to not output the trailing newline
#   - text message to be printed
#
function colored_print()
{
    local message="${@:2}"

    if [[ $# -ge 2 && $2 = "-n" ]]; then
        message="${@:3}"
        if [ -t 1 ]; then
            printf ${!1} "$message"
        else
            echo -n "$message"
        fi
    else
        if [ -t 1 ]; then
            printf "${!1}\n" "$message"
        else
            echo "$message"
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

# Ask for yes or no
#
# @message A string with the message to be displayed for the user.
#
# Returns:
# Return "1" if the user accept the question, otherwise, return "0"
#
# Note: ask_yN return the string '1' and '0', you have to handle it by
# yourself in the code.
function ask_yN()
{
  local message=$@

  read -r -p "$message [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    echo "1"
  else
    echo "0"
  fi
}
