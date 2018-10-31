declare -r BLUECOLOR="\033[1;34;49m%s\033[m"
declare -r REDCOLOR="\033[1;31;49m%s\033[m"
declare -r YELLOWCOLOR="\033[1;33;49m%s\033[m"
declare -r GREENCOLOR="\033[1;32;49m%s\033[m"
declare -r SEPARATOR="========================================================="

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
