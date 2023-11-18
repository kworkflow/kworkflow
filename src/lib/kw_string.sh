# @@ Expect a string
#
# Return:
# Returns a new String with the last character removed. Applying chop to an
# empty string returns an empty string.
function chop()
{
  printf '%s\n' "${@%?}"
}

# @@ String that we want to get the last character
#
# Return:
# Returns the last character from the string provided in the string parameter.
function last_char()
{
  printf '%s\n' "${1: -1}"
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
  printf '%s\n' "${#1}"
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

  printf '%s\n' "${str:0:size}"
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

  printf '%s\n' "$str" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

# Remove substring on the left side. If the string whose substring should be
# removed is empty, then this function returns an empty string. If the prefix
# substring is empty, then the original string is returned unchanged.
#
# @str: Target string
# @str_remove: Substring to be removed from the left side of str
#
# Return:
# Return string str without substring str_remove on the left side.
function str_remove_prefix()
{
  local str="$1"
  local str_remove="$2"

  printf '%s\n' "${str##"$str_remove"}"
}

# Remove substring on the right side. If the string whose substring should be
# removed is empty, then this function returns an empty string. If the suffix
# substring is empty, then the original string is returned unchanged.
#
# @str: Target string
# @str_remove: Substring to be removed from the right side of str
#
# Return:
# Return string str without substring str_remove on the right side.
function str_remove_suffix()
{
  local str="$1"
  local str_remove="$2"

  printf '%s\n' "${str%%"$str_remove"}"
}

# Make string uppercase
#
# @1: Target string
#
# Return:
# Return string str with all uppercase characters
function str_uppercase()
{
  printf '%s\n' "${1^^}"
}

# Make string lowercase
#
# @1: Target string
#
# Return:
# Return string str with all lowercase characters
function str_lowercase()
{
  printf '%s\n' "${1,,}"
}

# Remove duplicates of the given character from the given string
#
# @1: Target string
# @2: Target character
#
# Return:
# Return string str with all duplicated instances of the given charater
# replaced with a single instance
function str_remove_duplicates()
{
  local str="$1"
  local char="$2"

  printf '%s\n' "$str" | tr -s "$char"
}

# This function expects a string and a character that will be used as a
# reference to count how many times the character appears in the string. Based
# on the second parameter, we can have the following behaviors:
# 1. Valid char: Count how many times char is found in the string.
# 2. Empty char: it will return the total of characters in the string.
# 3. Multiple chars: It will take only the first character and ignore the rest.
#
# @str: Target string
# @char: Character reference
#
# Return:
# Return the number of occurencies of char inside the string.
function str_count_char_repetition()
{
  local str="$1"
  local char="${2:0:1}"
  local matches

  matches="${str//[^$char]/}"
  printf '%s' "${#matches}"
}

# Drop all spaces from the string
#
# @str: Target string
#
# Return:
# Return a string without space
function str_drop_all_spaces()
{
  local str="$*"

  printf '%s' "$str" | tr --delete ' '
}

# This function takes arguments and concatenates them with commas as
# separators
#
# @@: Values to be formatted
#
# Return:
# A string of the arguments separated by commas
function concatenate_with_commas()
{
  local IFS=','

  printf '%s\n' "$*"
}

# This function check if a string has some special character associated with
# it. By special character, we refer to: !, @, #, $, %, ^, &, (, ), and +.
#
# @str: Target string
#
# Return:
# If match a special character, return 0. Otherwise retun 1.
function str_has_special_characters()
{
  local str="$*"

  [[ "$str" == *['!'@#\$%^\&*\(\)+]* ]] && return 0
  return 1
}

# Get value under double-quotes. This function only returns the first match if
# the target string has more than one quoted string. If the string does not
# have any quotes, this function will return the original string.
#
# @string String to be processed
#
# Return:
# Return data between quotes, or 22 if the string is empty.
function str_get_value_under_double_quotes()
{
  local string="$1"

  [[ -z "$string" ]] && return 22 # EINVAL

  printf '%s' "$string" | sed 's/^[^"]*"\([^"]*\)".*/\1/'
  return "$?"
}

# Escape (i.e. adds a '\' before) all single quotes. This is useful when we want
# to make sure that a single quote `'` is interpreted as a literal in character
# sequences like $'<string>'. For reference, see section 3.1.2.4 of
# https://www.gnu.org/software/bash/manual/bash.html#Shell-Syntax.
#
# @string: String to be processed
#
# Return:
# Returns the string with all single quotes escaped, if any, or 22 (EINVAL) if
# the string is empty.
function str_escape_single_quotes()
{
  local string="$1"

  [[ -z "$string" ]] && return 22 # EINVAL

  printf '%s' "$string" | sed "s/'/\\\'/g"
}

# Convert arbitrary string to Unix-friendly filename.
#
# @string: String to be processed
#
# Return:
# Returns the Unix-friendly filename version of the string, or 22 (EINVAL) if
# the string is empty, only composed of removable character, or has a net size
# greater than 255 characters.
function string_to_unix_filename()
{
  local string="$1"
  local filename

  # Replace space and forward slash in favor of underscore
  filename="${string//[ \/]/_}"

  # Remove special character
  filename="${filename//[$&*+%!?:,\'\"\`]/}"

  # Remove parenthesis, brackets and curly braces
  filename="${filename//[\[\]\(\)\{\}]/}"

  # An empty string can mean that the original one was empty or
  # that it is only composed of chars that are removed. Either way
  # we should not return an empty string as there is no such thing
  # as an empty path in Unix.
  [[ -z "$filename" ]] && return 22 # EINVAL

  # Most filesystems have a maximum filename length of 255 characters
  # For reference, see https://en.wikipedia.org/wiki/Comparison_of_file_systems#Limits
  [[ "${#filename}" -gt 255 ]] && return 22 # EINVAL

  printf '%s' "$filename"
}
