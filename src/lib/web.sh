# This file handles any web access

include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

# Download a webpage.
#
# @url         Target url
# @output      Name of the output file
# @output_path Alternative output path
# @flag        Flag to control output
function download()
{
  local url="$1"
  local output=${2:-'page.xml'}
  local output_path="$3"
  local flag="$4"

  if [[ -z "$url" ]]; then
    complain 'URL must not be empty.'
    return 22 # EINVAL
  fi

  flag=${flag:-'SILENT'}

  output_path="${output_path:-${KW_CACHE_DIR}}"

  cmd_manager "$flag" "curl --silent '$url' --output '${output_path}/${output}'"
}

# Replace URL strings that use HTTP with HTTPS.
#
# @url Target url
#
# Return:
# Return a string that had http replaced by https. If there is no occurrence
# of HTTP, it returns the same string and return status is 1.
function replace_http_by_https()
{
  local url="$1"
  local new_url
  local ret=0

  grep --quiet '^http:' <<< "$url"
  [[ "$?" != 0 ]] && ret=1

  new_url="${url/http:\/\//https:\/\/}"
  printf '%s' "$new_url"

  return "$ret"
}

# This function is a predicate to determine if a file is an HTML file. The function
# tries to do this efficiently by first checking only the first line of the file. In
# case further checking is needed, we look for other tokens in the whole file to
# determine if it is an HTML.
#
# @file_path: Path to the file to be checked.
#
# Return:
# Returns 0 if the function decided that the file is an HTML file, 1 if the function
# decided it isn't, and 2 (ENOENT) if `@file_path` doesn't correspond to a file.
function is_html_file()
{
  local file_path="$1"
  local first_line_of_file

  [[ ! -f "$file_path" ]] && return 2 # ENOENT

  first_line_of_file=$(head --lines 1 "$file_path" | tr '[:upper:]' '[:lower:]')
  if [[ "$first_line_of_file" =~ ^(<html|<\!doctype html>) ]]; then
    return 0
  fi

  grep --silent '\(<head>\|<body>\)' "$file_path"
  [[ "$?" == 0 ]] && return 0
  return 1
}
