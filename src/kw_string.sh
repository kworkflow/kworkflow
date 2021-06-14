# @@ Expect a string
#
# Return:
# Returns a new String with the last character removed. Applying chop to an
# empty string returns an empty string.
function chop()
{
  echo "${@%?}"
}

# @@ String that we want to get the last character
#
# Return:
# Returns the last character from the string provided in the string parameter.
function last_char()
{
  echo "${1: -1}"
}

# Check if a string is a number (it ignores spaces after and before the number)
#
# @1 Target string for validation
#
# Return
# Returns 0 if the string is a number, otherwise, return 1.
function str_is_a_number()
{
  local value="$1"

  value=$(str_strip "$value")
  [[ "$value" =~ ^[-]?[0-9]+$ ]] && return 0
  return 1
}

# Calculate the length of a string
#
# @1 Target string
#
# Return:
# String length
function str_length()
{
  echo "${#1}"
}

# Trim string based on string lenght.
#
# @str: Target string
# @size: Sting size
#
# Return:
# Return a string limited by @size
function str_trim()
{
  local str="$1"
  local size="$2"

  echo "${str:0:size}"
}

# Remove extra spaces from the beginning and end of the string
#
# @1: Target string
#
# Return:
# Return string without spaces in the beginning and the end.
function str_strip()
{
  local str

  str="$*"

  echo "$str" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}
