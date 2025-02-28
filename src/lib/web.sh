# This file handles any web access

include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

# Download a webpage.
#
# @url         Target url
# @output      Name of the output file
# @output_path Alternative output path
# @flag        Flag to control output
function download() {
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
function replace_http_by_https() {
	local url="$1"
	local new_url
	local ret=0

	grep --quiet '^http:' <<<"$url"
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
function is_html_file() {
	local file_path="$1"
	local first_line_of_file

	[[ ! -f "$file_path" ]] && return 2 # ENOENT

	first_line_of_file=$(head --lines 1 "$file_path" | tr '[:upper:]' '[:lower:]')
	if [[ "$first_line_of_file" =~ ^(<html|<\!doctype html>) ]]; then
		return 0
	fi

	grep --silent '\(<head>\|<body>\)' "$file_path"
	[[ "$?" == 0 ]] && return 0
	return 1 # EPERM
}

# This function recieves a string and converts it to contain only characters that
# are legal to be used within a URL (https://en.wikipedia.org/wiki/Percent-encoding).
# Only illegal chars are percent-encoded. A percent-encoding of an ASCII char is
# its ASCII number in hexadecimal format prefixed by a percent '%'. If the char is
# non-ASCII, each byte of its byte sequence in UTF-8 is treated as an ASCII char
# and converted accordingly.

# Note: A full URL shouldn't be passed as argument, as the function will probably
# break it (e.g., it will convert all foward slashes in the string).
#
# @string: String to be encoded
#
# Return:
# The function outputs the encoded string and returns 0 in any case. An empty `string`
# value is a valid argument.
#
# CREDITS:
# This function was adapted to follow kw's coding style, and the primary reference
# for it is https://github.com/dylanaraps/pure-bash-bible#percent-encode-a-string,
# from the book 'pure bash bible', which is licensed under the MIT license. Also,
# credits to meleu (https://github.com/meleu) who wrote a blogpost that can be
# checked at https://meleu.sh/urlencode, from which this function was first found.
function url_encode() {
	local string="$1"
	local LC_ALL
	local char
	local encoded_string

	# We create a local `LC_ALL` to not pollute the user settings.
	# The 'C' is to capture only the 26 ASCII chars from a to z in [a-z] (analogous for [A-Z]).
	LC_ALL='C'

	# In this loop, we are iterating through each char and encoding it when necessary
	for ((i = 0; i < ${#string}; i++)); do
		char="${string:i:1}"
		if [[ "$char" =~ [a-zA-Z0-9.~_-] ]]; then
			encoded_string+="$char"
		else
			# %% - Literal '%'
			# %02X - Two digit hexadecimal with 0 preceding, if necessary
			# "'$char" - ASCII number of "$char"
			encoded_string+=$(printf '%%%02X' "'$char")
		fi
	done

	printf '%s' "$encoded_string"
}
