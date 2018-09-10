declare -r BLUECOLOR="\033[1;34;49m%s\033[m\n"
declare -r REDCOLOR="\033[1;31;49m%s\033[m\n"
declare -r YELLOWCOLOR="\033[1;33;49m%s\033[m\n"
declare -r SEPARATOR="========================================================="

# Print normal message (e.g info messages). This function verifies if stdout
# is open and print it with color, otherwise print it without color.
# @param $@ it receives text message to be printed.
function kw::say()
{
  message="$@"
  if [ -t 1 ]; then
    printf $BLUECOLOR "$message"
  else
    echo "$message"
  fi
}

# Print error message. This function verifies if stdout is open and print it
# with color, otherwise print it without color.
# @param $@ it receives text message to be printed.
function kw::complain()
{
  message="$@"
  if [ -t 1 ]; then
    printf $REDCOLOR "$message"
  else
    echo "$message"
  fi
}

# Warning error message. This function verifies if stdout is open and print it
# with color, otherwise print it without color.
# @param $@ it receives text message to be printed.
function kw::warning()
{
  message="$@"
  if [ -t 1 ]; then
    printf $YELLOWCOLOR "$message"
  else
    echo "$message"
  fi
}
