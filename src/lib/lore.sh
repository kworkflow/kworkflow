# This file is the library that handles the "back end" of interacting with the
# kernel lore archives. it handles fecthing, listing and downloading of patches
# sent to the public mailing lists.

include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/lib/web.sh"

# Lore base URL
declare -gr LORE_URL='https://lore.kernel.org'

# Lore cache directory
declare -g CACHE_LORE_DIR="${KW_CACHE_DIR}/lore"

# File name for the lore page
declare -gr MAILING_LISTS_PAGE_NAME='lore_page'

# File extension for the lore list file
declare -gr MAILING_LISTS_PAGE_EXTENSION='html'

# Directory for storing every data related to lore
declare -g LORE_DATA_DIR="${KW_DATA_DIR}/lore"

# File name for the lore bookmarked series
declare -gr LORE_BOOKMARKED_SERIES='lore_bookmarked_series'

# Path to bookmarked series file
declare -g BOOKMARKED_SERIES_PATH="${LORE_DATA_DIR}/${LORE_BOOKMARKED_SERIES}"

# List of lore mailing list tracked by the user
declare -gA available_lore_mailing_lists

# TODO: Find a better way to deal with this
# Special character used for separate data.
declare -gr SEPARATOR_CHAR='Æ'

# Indexed array of patches that represent patchsets ordered from the latest to
# the earliest. A patchset is a set of individual patches sent together to form
# a broader change and its first message in the series is elected to be the
# representative. An element of the array is a sequence of message's attributes
# separated by `SEPARATOR_CHAR` in the following order:
#   message ID, message title, author name, author email, version, number in series,
#   total in series, updated, and in reply to (optional).
declare -ag representative_patches

# Associative array with metadata of every patch that was processed during a
# fetch session of patchsets. This information is used to determine representative
# patches (see function `processed_representative_patches`). An element's general
# format is:
#   individual_patches_metadata['message_id']='<version>,<number_in_series>'
declare -Ag individual_patches_metadata

# Associative array used to check if a given representative patch was already
# processed. Each element is a boolean where a non-empty value is true and an
# empty one is false.
declare -Ag processed_representative_patches

# Total number of processed representative patches in current fetch session. Also,
# the size of the indexed array `representative_patches`.
declare -g REPRESENTATIVE_PATCHES_PROCESSED=0

# Any query to the lore servers is paginated and the maximum number of individual
# messages returned is 200. This variable represents this value.
declare -gr LORE_PAGE_SIZE=200

# Lore servers accepts a parameter `o` in the query string. This parameter defines
# the 'minimum index' of the query response. In other words, if a query matches N
# messages, say N=500, adding `o=200` to the query string results in the response
# from the server containing the messages of indexes 201 to 400, for example (if
# `o=400` the response would have messages 401 to 500). This variable stores the
# 'minimum index' of the current lore fetch session. Note that this is actually a
# minimum exclusive (minorant) as the message of index `MIN_INDEX` isn't included
# in the response (neither the message of index 0 exists).
declare -g MIN_INDEX=0

# This function creates the directory used by kw for any lore related data.
#
# Return:
# Returns 0 if the lore data directory was created successfully and the failing
# status code otherwise (probably 111 EACCESS).
function create_lore_data_dir()
{
  local ret

  [[ -d "${LORE_DATA_DIR}" ]] && return

  mkdir -p "${LORE_DATA_DIR}"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain "Could not create lore data dir in ${LORE_DATA_DIR}"
  fi

  return "$ret"
}

function setup_cache()
{
  mkdir -p "${CACHE_LORE_DIR}"
}

# This function downloads lore archive pages and retrieves names and
# descriptions of the currently available mailing lists in the archive. It then
# saves that information in the `available_lore_mailing_lists` global array.
# This function takes care of the pagination from the Lore response, by fetching
# adjacent pages until there are no more mailing lists to be listed.
#
# @flag Flag to control function output
function retrieve_available_mailing_lists()
{
  local flag="$1"
  local index=''
  local pre_processed
  local entries=0
  local page_filename
  local page=0
  local offset=0

  flag=${flag:-'SILENT'}

  setup_cache

  # When there are no more mailing lists to be listed, only the `all` list is returned
  while [[ "$entries" -ne 1 ]]; do

    entries=0
    page_filename="${MAILING_LISTS_PAGE_NAME}_${page}.${MAILING_LISTS_PAGE_EXTENSION}"

    offset=$((LORE_PAGE_SIZE * page))
    page_url="${LORE_URL}/?&o=${offset}"

    download "$page_url" "$page_filename" "$CACHE_LORE_DIR" "$flag" || return "$?"
    pre_processed=$(sed -nE -e 's/^href="(.*)\/?">\1<\/a>$/\1/p; s/^  (.*)$/\1/p' "${CACHE_LORE_DIR}/${page_filename}")

    while IFS= read -r line; do
      if [[ -z "$index" ]]; then
        index="$line"
        ((entries++))
      else
        available_lore_mailing_lists["$index"]="$line"
        index=''
      fi
    done <<< "$pre_processed"

    ((page++))
  done
}

# Some people set their names like "Second name, First name", this extra comma
# is not ideal when dealing with emails. This function converts names as
# "Second name, First name" to "First name Second name"
#
# @name_str Name
#
# Return:
# Return a string name without comma
function process_name()
{
  local name_str="$1"

  IFS=',' read -r -a full_name <<< "$name_str"

  if [[ ${#full_name[@]} -eq 1 ]]; then
    printf '%s' "$name_str"
    return
  fi

  full_name[0]=$(str_strip "${full_name[0]}")
  full_name[1]=$(str_strip "${full_name[1]}")

  # We need to handle "Second_name, name"
  printf '%s' "${full_name[1]} ${full_name[0]}"
}

# This function resets all data structures that constitute the current fetch
# session. Five elements define a fetch session:
#   1. List of representative patches ordered from latest to earliest;
#   2. Table with the metadata of all individual patches processed;
#   3. Table with all representative patches processed;
#   4. Total number of representative patches processed;
#   5. Earliest page processed.
function reset_current_lore_fetch_session()
{
  representative_patches=()
  unset individual_patches_metadata
  declare -Ag individual_patches_metadata
  unset processed_representative_patches
  declare -Ag processed_representative_patches
  REPRESENTATIVE_PATCHES_PROCESSED=0
  MIN_INDEX=0
}

# This function composes a query URL to a public mailing list archived
# on lore.kernel.org and verifies if the link is valid. A request to the
# URL composed by this function returns an XML file with only patches
# ordered by their 'updated' attribute.
#
# The function allows the addition of optional filters by the `additional_filters`
# argument. This argument has to comply with the format of lore API search (see
# https://lore.kernel.org/amd-gfx/_/text/help/).
#
# @target_mailing_list: String with valid public mailing list name
# @min_index: Minimum exclusive index of patches to be contained in server response
# @additional_filters: Optional additional filters of query
#
# Return:
# Returns 22 in case the URL produced is invalid or `@target_mailing_list`
# is empty. In case the URL produced is valid, the function returns 0 and
# outputs the query URL.
function compose_lore_query_url_with_verification()
{
  local target_mailing_list="$1"
  local min_index="$2"
  local additional_filters="$3"
  local query_filter
  local query_url

  if [[ -z "$target_mailing_list" || -z "$min_index" ]]; then
    return 22 # EINVAL
  fi

  # TODO: Add verification for `@target_mailing_list`.

  # Verifying if minimum index is valid, i.e., is an integer
  if [[ ! "$min_index" =~ ^-?[0-9]+$ ]]; then
    return 22 # EINVAL
  fi

  query_filter="?x=A&o=${min_index}&q=((s:patch+OR+s:rfc)+AND+NOT+s:re:)"
  [[ -n "$additional_filters" ]] && query_filter+="+AND+${additional_filters}"
  query_url="${LORE_URL}/${target_mailing_list}/${query_filter}"
  printf '%s' "$query_url"
}

# This function pre-processes a raw XML containing a list of patches. The `xpath`
# command is used to capture the desired fields for each patch. A simplified
# example of an XML element that represents a patch is (the thr:in-reply-to field
# is optional):
#   <entry>
#     <author>
#       <name>John Smith</name>
#       <email>john@smith.com</email>
#     </author>
#     <title>[PATCH] dir/subdir: Fix bug xpto</title>
#     <updated>2023-08-09T21:27:00Z</updated>
#     <link href="http://lore.kernel.org/list/0xc0ffee-4-john@smith.com/"/>
#     <thr:in-reply-to href="http://lore.kernel.org/list/0xc0ffee-0-john@smith.com/"/>
#   </entry>
#
# The pre-processed version of this example element would be:
#   John Smith
#   john@smith.com
#   [PATCH] dir/subdir: Fix bug xpto
#   2023-08-09T21:27:00Z
#    href="http://lore.kernel.org/list/0xc0ffee-4-john@smith.com/"
#    href="http://lore.kernel.org/list/0xc0ffee-0-john@smith.com/"
#
# @raw_xml: String with raw XML.
#
# Return:
# The status code is the same as the `xpath` command and the pre-processed XML file
# is outputted to the standard output
function pre_process_raw_xml()
{
  local raw_xml="$1"
  local xpath_query
  local xpath_output
  local -r NAME_EXP='//entry/author/name/text()'
  local -r EMAIL_EXP='//entry/author/email/text()'
  local -r TITLE_EXP='//entry/title/text()'
  local -r UPDATED_EXP='//entry/updated/text()'
  local -r LINK_EXP='//entry/link/@href'
  local -r IN_REPLY_TO_EXP='//entry/thr:in-reply-to/@href'

  xpath_query="${NAME_EXP}|${EMAIL_EXP}|${TITLE_EXP}|${UPDATED_EXP}|${LINK_EXP}|${IN_REPLY_TO_EXP}"
  xpath_output=$(printf '%s' "$raw_xml" | xpath -q -e "$xpath_query")
  xpath_output+=$'\n'

  printf '%s' "$xpath_output"
}

function get_patch_tag()
{
  local message_title="$1"

  printf '%s' "$message_title" | grep --only-matching --perl-regexp '\[[^\]]*(RFC|Rfc|rfc|PATCH|Patch|patch)[^\[]*\]' | head --lines 1
}

function get_patch_version()
{
  local patch_tag="$1"
  local version=''

  # Grab pattern 'v<number>' or 'V<number>' from patch tag
  version=$(printf '%s' "$patch_tag" | grep --only-matching --perl-regexp '[v|V]+\d+')
  # Grab number from string
  version=$(printf '%s' "$version" | grep --only-matching --perl-regexp '\d+')
  # Versions 1 don't have pattern 'v<number>' nor 'V<number>' in the patch tag
  [[ -z "$version" ]] && version=1

  printf '%s' "$version"
}

function get_patch_number_in_series()
{
  local patch_tag="$1"
  local number_in_series=''

  # Grab pattern '<number>/<number>' from patch tag
  number_in_series=$(printf '%s' "$patch_tag" | grep --only-matching --perl-regexp "\d+/\d+")
  # Grab number from start of string
  number_in_series=$(printf '%s' "$number_in_series" | grep --only-matching --perl-regexp "^\d+")
  # Remove leading zeroes
  if [[ "$number_in_series" =~ ^0+$ ]]; then
    number_in_series=0
  else
    number_in_series=$(printf '%s' "$number_in_series" | sed 's/^0*//')
  fi
  # Patchsets with one patch don't have pattern '<number>/<number>' in the patch tag
  [[ -z "$number_in_series" ]] && number_in_series=1

  printf '%s' "$number_in_series"
}

function get_patch_total_in_series()
{
  local patch_tag="$1"
  local total_in_series=''

  # Grab pattern '<number>/<number>' from patch tag
  total_in_series=$(printf '%s' "$patch_tag" | grep --only-matching --perl-regexp "\d+/\d+")
  # Grab number from end of string
  total_in_series=$(printf '%s' "$total_in_series" | grep --only-matching --perl-regexp "\d+$")
  # Patchsets with one patch don't have pattern '<number>/<number>' in the patch tag
  [[ -z "$total_in_series" ]] && total_in_series=1

  printf '%s' "$total_in_series"
}

function remove_patch_tag_from_message_title()
{
  local message_title="$1"
  local patch_tag="$2"

  # This conditional prevents `sed` 'previous regular expression' error
  if [[ -n "$patch_tag" && -n "$message_title" ]]; then
    # Escape chars '[', ']', and '/' from patch tag
    patch_tag=$(printf '%s' "$patch_tag" | sed 's/\[/\\\[/' | sed 's/\]/\\\]/' | sed 's/\//\\\//')
    message_title=$(printf '%s' "$message_title" | sed "s/${patch_tag}//")
    message_title=$(str_strip "$message_title")
  fi

  printf '%s' "$message_title"
}

function process_individual_patches()
{
  local raw_xml="$1"
  local -n _individual_patches="$2"
  local pre_processed_patches
  local message_id=''
  local message_title=''
  local author_name=''
  local author_email=''
  local version=''
  local number_in_series=''
  local total_in_series=''
  local updated=''
  local in_reply_to=''
  local patch_tag=''
  local count=0
  local i=0

  pre_processed_patches=$(pre_process_raw_xml "$1")

  while IFS= read -r line; do
    if [[ "$count" == 5 ]]; then
      count=0

      patch_tag=$(get_patch_tag "$message_title")
      version=$(get_patch_version "$patch_tag")
      number_in_series=$(get_patch_number_in_series "$patch_tag")
      total_in_series=$(get_patch_total_in_series "$patch_tag")
      message_title=$(remove_patch_tag_from_message_title "$message_title" "$patch_tag")

      # Mark individual patch as processed and store metadata
      individual_patches_metadata["$message_id"]="${version},${number_in_series}"

      _individual_patches["$i"]="${message_id}${SEPARATOR_CHAR}${message_title}${SEPARATOR_CHAR}"
      _individual_patches["$i"]+="${author_name}${SEPARATOR_CHAR}${author_email}${SEPARATOR_CHAR}"
      _individual_patches["$i"]+="${version}${SEPARATOR_CHAR}${number_in_series}${SEPARATOR_CHAR}"
      _individual_patches["$i"]+="${total_in_series}${SEPARATOR_CHAR}${updated}${SEPARATOR_CHAR}"

      # In case the patch has a 'In-Reply-To' field, `line` contains this value,
      # so process it and read next line of pre processed.
      if [[ "$line" =~ ^[[:space:]]href= ]]; then
        in_reply_to=$(str_get_value_under_double_quotes "$line")
        _individual_patches["$i"]+="$in_reply_to"
        ((i++))
        continue
      fi

      ((i++))
    fi

    case "$count" in
      0) # Author's name
        author_name=$(process_name "$line")
        ;;
      1) # Author's email
        author_email="$line"
        ;;
      2) # Message title
        message_title="$line"
        ;;
      3) # Updated
        updated="$line"
        updated=$(printf '%s' "$updated" | sed 's/-/\//g' | sed 's/T/ /')
        updated="${updated:0:-4}"
        ;;
      4) # Message-ID
        message_id=$(str_get_value_under_double_quotes "$line")
        ;;
    esac

    ((count++))
  done <<< "$pre_processed_patches"
}

function process_representative_patches()
{
  local -n _individual_patches_array="$1"
  local message_id
  local in_reply_to_message_id
  local -a patch_metadata
  local -a in_reply_to_metadata
  local is_representative_patch

  for patch in "${_individual_patches_array[@]}"; do
    is_representative_patch=''
    unset patch_dict
    declare -A patch_dict

    read_patch_into_dict "$patch" 'patch_dict'

    # To avoid duplication, check if patch has been processed as representative
    message_id="${patch_dict['message_id']}"
    [[ -n "${processed_representative_patches["$message_id"]}" ]] && continue

    # Assume that patch number 0 is always the representative as the cover letter
    if [[ "${patch_dict['number_in_series']}" == 0 ]]; then
      is_representative_patch=1
    # Assume that, when there is no patch number 0, number 1 is the representative
    elif [[ "${patch_dict['number_in_series']}" == 1 ]]; then
      # Assume that patch number 1 without 'In-Reply-To' means no number 0
      if [[ "${patch_dict['total_in_series']}" == 1 ||
        -z "${patch_dict['in_reply_to']}" ]]; then
        is_representative_patch=1
      else
        patch_metadata=()
        in_reply_to_metadata=()
        in_reply_to_message_id="${patch_dict['in_reply_to']}"
        IFS=',' read -ra patch_metadata <<< "${individual_patches_metadata["$message_id"]}"
        IFS=',' read -ra in_reply_to_metadata <<< "${individual_patches_metadata["$in_reply_to_message_id"]}"

        # Assume that, if 'In-Reply-To' is not patch number 0 from the same
        # version, number 1 is the representative
        if [[ "${patch_metadata[0]}" != "${in_reply_to_metadata[0]}" || "${in_reply_to_metadata[1]}" != 0 ]]; then
          is_representative_patch=1
        fi
      fi
    fi

    if [[ -n "$is_representative_patch" ]]; then
      representative_patches["$REPRESENTATIVE_PATCHES_PROCESSED"]="$patch"
      ((REPRESENTATIVE_PATCHES_PROCESSED++))
      processed_representative_patches["${patch_dict['message_id']}"]=1
    fi
  done
}

# This function is primarily a mediator to manage the complex action of fetching
# the lastest patchsets from a public mailing list archived on lore.kernel.org.
# The fetching of patchsets has 3 steps:
#  1. Build a lore query URL to match only messages that are patches from a given
#     list from `MIN_INDEX` onward.
#  2. Make a request to the URL built in step 1 to obtain a list of patches ordered
#     by the recieved time on the lore.kernel.org servers.
#  3. Process the list of patches to a list of patchsets stored in the
#     `representative_patches` array.
#
# In case the number of patchsets in `representative_patches` is less than
# `page` times `patchsets_per_page`, update `MIN_INDEX` and repeat steps 1 to 3.
#
# This function considers the totality of ordered patchsets in chunks of the same
# size named pages. The `page` argument indicates until which page of the latest
# patchsets should the fetch occur.
#
# @target_mailing_list: A string name that matches the mailing list name
#   registered to lore
# @page: Positive integer that represents until what page of latest patchsets the fetch
#   should occur
# @patchsets_per_page: Number of patchsets per page
# @additional_filters: Optional additional filters of query
# @flag: Flag to control function output
#
# Return:
# If either step 1 or 2 fails, returns the error code from these steps, and 0, otherwise.
# If the fetch has failed (i.e. the returned file is an HTML), return 22 (ENOENT).
function fetch_latest_patchsets_from()
{
  local target_mailing_list="$1"
  local page="$2"
  local patchsets_per_page="$3"
  local additional_filters="$4"
  local flag="$5"
  local xml_result_file_name
  local lore_query_url
  local raw_xml
  local ret

  flag=${flag:-'SILENT'}
  xml_result_file_name="${target_mailing_list}-patches.xml"

  while [[ "$REPRESENTATIVE_PATCHES_PROCESSED" -lt "$((page * patchsets_per_page))" ]]; do
    # Building URL for querying lore servers for a xml file with patches.
    lore_query_url=$(compose_lore_query_url_with_verification "$target_mailing_list" "$MIN_INDEX" "$additional_filters")
    ret="$?"
    [[ "$ret" != 0 ]] && return "$ret"

    # Request xml file with patches.
    download "$lore_query_url" "$xml_result_file_name" "$CACHE_LORE_DIR" "$flag"
    ret="$?"
    [[ "$ret" != 0 ]] && return "$ret"

    # If the returned file is an HTML, then the fetch has failed and we should signal the caller.
    if is_html_file "${CACHE_LORE_DIR}/${xml_result_file_name}"; then
      return 22 # ENOENT
    fi

    raw_xml=$(< "${CACHE_LORE_DIR}/${xml_result_file_name}")

    # If the resulting file doesn't contain any patches, it will be an "empty" XML with
    # just '</feed>' and we can stop the fetch. This is different from a failed fetch
    # and can be considered a heuristic.
    if [[ "$raw_xml" == '</feed>' ]]; then
      break
    fi

    process_individual_patches "$raw_xml" 'individual_patches'
    process_representative_patches 'individual_patches'

    # Update minimum exclusive index.
    MIN_INDEX=$((MIN_INDEX + LORE_PAGE_SIZE))
  done
}

# This function formats a range of patchsets metadata from `representative_patches`
# into an array reference passed as argument. The format of the metadata follows the
# pattern:
#
#  V <version_of_patchset> | #<number_of_patches> | <patchset_title>
#
# @_formatted_patchsets_list: Array reference to output formatted range of patchsets metadata
# @starting_index: Starting index of range from `representative_patches`
# @ending_index: Ending index of range `representative_patches`
function format_patchsets()
{
  local -n _formatted_patchsets_list="$1"
  local starting_index="$2"
  local ending_index="$3"
  declare -A patchset

  for i in $(seq "$starting_index" "$ending_index"); do
    read_patch_into_dict "${representative_patches["$i"]}" 'patchset'
    _formatted_patchsets_list["$i"]=$(printf 'V%-2s |#%-3s| ' "${patchset['version']}" "${patchset['total_in_series']}")
    _formatted_patchsets_list["$i"]+=$(printf ' %-100s' "${patchset['message_title']}")
  done
}

# This function outputs the starting index in the `representative_patches` array of a given
# page, i.e., if the patchsets of the page 2 are from `representative_patches[30]` until
# `representative_patches[59]`, this function outputs '30'.
#
# @page: Number of the target page.
# @patchsets_per_page: Number of patchsets per page
function get_page_starting_index()
{
  local page="$1"
  local patchsets_per_page="$2"
  local starting_index

  starting_index=$(((page - 1) * patchsets_per_page))
  # Avoid an starting index greater than the max index of `representative_patches`
  if [[ "$starting_index" -gt "$((${#representative_patches[@]} - 1))" ]]; then
    starting_index=$((${#representative_patches[@]} - 1))
  fi
  printf '%s' "$starting_index"
}

# This function outputs the ending index in the `representative_patches` array of a given
# page, i.e., if the patchsets of the page 2 are from `representative_patches[30]` until
# `representative_patches[59]`, this function outputs '59'.
#
# @page: Number of the target page
# @patchsets_per_page: Number of patchsets per page
function get_page_ending_index()
{
  local page="$1"
  local patchsets_per_page="$2"
  local ending_index

  ending_index=$(((page * patchsets_per_page) - 1))
  # Avoid an ending index greater than the max index of `representative_patches`
  if [[ "$ending_index" -gt "$((${#representative_patches[@]} - 1))" ]]; then
    ending_index=$((${#representative_patches[@]} - 1))
  fi
  printf '%s' "$ending_index"
}

# This function downloads a patch series in a .mbx format to a given directory
# using a series URL. The series URL should be the concatenation of the lore URL, the
# target mailing list, and the message ID. Below is an example of such a URL:
#   https://lore.kernel.org/some-list/2367462342.4535535-1-email@email.com/
# The output filename is '<message ID>.mbx'. This function uses the `b4` tool underneath
# to delegate the process of fetching and downloading the series. The file generated is
# ready to be applied into a git tree, containing just the patches in the right order,
# without the cover letter.
#
# @series_url: The URL of the series
# @save_to: Path to the target output directory
# @flag: Flag to control function output
#
# Return:
# Return 0 if the thread was successfully downloaded, 22 if the series URL or the output
# directory passed as arguments is empty and the error code of `b4` in case it fails.
function download_series()
{
  local series_url="$1"
  local save_to="$2"
  local flag="$3"
  local series_filename
  local cmd
  local ret

  flag=${flag:-'SILENT'}

  # Safety checking
  if [[ -z "$series_url" || -z "$save_to" ]]; then
    return 22 # EINVAL
  fi

  # Create the output directory if it doesn't exists
  cmd_manager "$flag" "mkdir --parents '${save_to}'"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain "Couldn't create directory in ${save_to}"
    return "$ret"
  fi

  # Although, by default, b4 uses the message-ID as the output name, we should assure it
  series_filename=$(extract_message_id_from_url "$series_url")

  # For safe-keeping, check the protocol used
  series_url=$(replace_http_by_https "$series_url")

  # Issue the command to download the series
  cmd="b4 --quiet am '${series_url}' --no-cover --outdir '${save_to}' --mbox-name '${series_filename}.mbx'"
  cmd_manager "$flag" "$cmd"
  ret="$?"
  if [[ "$ret" == 1 ]]; then
    # Unfortunately, unknown message-ID and invalid outdir errors are the same (errno #1)
    complain 'An error occurred during the execution of b4'
    complain "b4 command: ${cmd}"
  elif [[ "$ret" == 2 ]]; then
    complain 'b4 unrecognized arguments'
    complain "b4 command: ${cmd}"
  else
    printf '%s/%s.mbx' "$save_to" "$series_filename"
  fi

  return "$ret"
}

# This function deletes a patch series from the local storage
#
# @download_dir_path: The path to the directory where the series was stored
# @series_url: The URL of the series
# @flag: Flag to control function output
#
# Return:
# Return 0 if the target file was found and deleted succesfully and 2 (ENOENT),
# otherwise.
function delete_series_from_local_storage()
{
  local download_dir_path="$1"
  local series_url="$2"
  local flag="$3"
  local series_filename

  flag=${flag:-'SILENT'}

  series_filename=$(extract_message_id_from_url "$series_url")

  if [[ -f "${download_dir_path}/${series_filename}.mbx" ]]; then
    cmd_manager "$flag" "rm ${download_dir_path}/${series_filename}.mbx"
  else
    return 2 # ENOENT
  fi
}

# This function creates the lore bookmarked series file if it doesn't
# already exists
#
# Return:
# Returns 0 if the file is created successfully, and the return value of
# create_lore_data_dir in case it isn't 0.
function create_lore_bookmarked_file()
{
  local ret

  create_lore_data_dir
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    return "$ret"
  fi

  [[ -f "${BOOKMARKED_SERIES_PATH}" ]] && return
  touch "${BOOKMARKED_SERIES_PATH}"
}

# This function adds an entry of a patchset instance to the local bookmarked database managed
# by kw. An entry of a patchset on the database represents an instance of the patchset entity
# that also has a timestamp indicating when the patchset was bookmarked and, optionally, a path
# to a directory where the .mbx file of the instance is stored. The ID (primary key) of an entry
# is its lore.kernel.org URL, which uniquely identifies a patchset in the public inbox.
#
# Note that the function assumes that the `@raw_patchset` passed as argument contains the
# necessary attributes and is correctly formatted, leaving this responsability to the caller.
#
# @raw_patchset: Raw data of patchset in the same format as representative_patches
#   to be added to the local bookmarked database
# @download_dir_path: The directory where the patchset .mbx was saved
function add_patchset_to_bookmarked_database()
{
  local raw_patchset="$1"
  local download_dir_path="$2"
  local timestamp
  local count

  create_lore_bookmarked_file

  timestamp=$(date '+%Y/%m/%d %H:%M')

  count=$(grep --count "${raw_patchset}" "${BOOKMARKED_SERIES_PATH}")
  if [[ "$count" == 0 ]]; then
    {
      printf '%s%s' "${raw_patchset}" "${SEPARATOR_CHAR}"
      printf '%s%s' "${download_dir_path}" "${SEPARATOR_CHAR}"
      printf '%s\n' "$timestamp"
    } >> "${BOOKMARKED_SERIES_PATH}"
  fi
}

# This function removes a patchset from the local bookmark database by its URL.
#
# @patchset_url: The URL of the patchset that identifies the entry in the local
#   bookmarked database
#
# Return:
# Returns 2 (ENOENT) if there is no local bookmark database file and the status
# code of the last command (sed), otherwise.
function remove_patchset_from_bookmark_by_url()
{
  local patchset_url="$1"

  if [[ ! -f "${BOOKMARKED_SERIES_PATH}" ]]; then
    return 2 # ENOENT
  fi

  # Escape forward slashes in the URL
  patchset_url=$(printf '%s' "$patchset_url" | sed 's/\//\\\//g')

  # Remove patchset entry
  sed --in-place "/${patchset_url}/d" "${BOOKMARKED_SERIES_PATH}"
}

# This function removes a series from the local bookmark database by its index
# in the database.
#
# @series_index: The index in the local bookmark database
#
# Return:
# Returns 2 (ENOENT) if there is no local bookmark database file and the status
# code of the last command (sed), otherwise.
function remove_series_from_bookmark_by_index()
{
  local series_index="$1"

  if [[ ! -f "${BOOKMARKED_SERIES_PATH}" ]]; then
    return 2 # ENOENT
  fi

  sed --in-place "${series_index}d" "${BOOKMARKED_SERIES_PATH}"
}

# This function populates an array passed as argument with all the bookmarked
# series. Each element will detain the information to be displayed in the bookmarked
# patches screen.
#
# @_bookmarked_series: An array reference to be populated with all the bookmarked
#   series.
#
# TODO:
# - Better decide which information will be shown in the bookmarked patches screen
function get_bookmarked_series()
{
  local -n _bookmarked_series="$1"
  declare -A series
  local index=0
  local timestamp
  local tmp_data

  if [[ ! -f "${BOOKMARKED_SERIES_PATH}" ]]; then
    return 2 # ENOENT
  fi

  _bookmarked_series=()

  while IFS='' read -r raw_patchset; do
    read_patch_into_dict "${raw_patchset}" 'series'
    tmp_data=$(printf ' %s | %-70s | %s' "${series['timestamp']}" "${series['message_title']}" "${series['author_name']}")
    _bookmarked_series["$index"]="${tmp_data}"
    ((index++))
  done < "${BOOKMARKED_SERIES_PATH}"
}

# This function gets a series from the local bookmark database by its index
# in the database.
#
# @series_index: The index in the local bookmark database
#
# Return:
# Return the bookmarked series raw data.
#
# TODO:
# - Find an alternative way to identify a series, this one may not be the most
#   reliable.
function get_bookmarked_series_by_index()
{
  local series_index="$1"
  local target_patch

  if [[ ! -f "${BOOKMARKED_SERIES_PATH}" ]]; then
    return 2 # ENOENT
  fi

  target_patch=$(sed "${series_index}!d" "${BOOKMARKED_SERIES_PATH}")

  printf '%s' "${target_patch}"
}

# This function parses raw data that represents a patch instance into an
# associative array passed as reference. This function assumes that the
# raw data has attributes in the following order:
#   message ID, message title, author name, author email, version,
#   patch number in series, total in series, updated time, in reply to (optional),
#   download directory path (bookmark exclusive), and timestamp (bookmark exclusive)
#
# Note that the function doesn't verifies if the attributes are non-empty or
# valid (i.e. represent a valid patch instance), passing the responsability to
# the caller.
#
# @raw_patch: Raw data of patch in the same format as in `representative_patches`
function read_patch_into_dict()
{
  local raw_patch="$1"
  local -n _dict="$2"
  local columns

  IFS="${SEPARATOR_CHAR}" read -ra columns <<< "$raw_patch"
  _dict['message_id']="${columns[0]}"
  _dict['message_title']="${columns[1]}"
  _dict['author_name']="${columns[2]}"
  _dict['author_email']="${columns[3]}"
  _dict['version']="${columns[4]}"
  _dict['number_in_series']="${columns[5]}"
  _dict['total_in_series']="${columns[6]}"
  _dict['updated']="${columns[7]}"
  _dict['in_reply_to']="${columns[8]}"
  _dict['download_dir_path']="${columns[9]}"
  _dict['timestamp']="${columns[10]}"
}

# This function gets the bookmark status of a patchset, 0 being not in the local
# bookmarked database and 1 being in the local bookmarked database.
#
# @message_id: The URL of the patchset that identifies the entry in the local
#   bookmarked database
#
# Return:
# Returns 22 (EINVAL)
function get_patchset_bookmark_status()
{
  local message_id="$1"
  local count

  [[ -z "$message_id" ]] && return 22 # EINVAL

  if [[ ! -f "${BOOKMARKED_SERIES_PATH}" ]]; then
    create_lore_bookmarked_file
  fi

  count=$(grep --count "$message_id" "${BOOKMARKED_SERIES_PATH}")
  if [[ "$count" == 0 ]]; then
    printf '%s' 0
  else
    printf '%s' 1
  fi
}

# Every patch series has a message-ID that identifies it in a given public
# mailing list. This function extracts the message-ID of an URL passed as
# arguments. The function assumes that the URL passed follows the pattern:
#   https://lore.kernel.org/<public-mailing-list>/<message-ID>
#
# @series_url: The URL of the series
#
# Return:
# Returns 22 (EINVAL) in case the URL passed as argument is empty and 0,
# otherwise.
function extract_message_id_from_url()
{
  local series_url="$1"
  local message_id

  if [[ -z "$series_url" ]]; then
    return 22 # EINVAL
  fi

  message_id=$(printf '%s' "$series_url" | cut --delimiter '/' -f5)
  printf '%s' "$message_id"
}

# This function sets a configuration in a 'lore.config' file.
#
# @setting: Name of the setting to be updated
# @new_value: New value to be set
# @lore_config_path: Path to the target 'lore.config' file
#
# Return:
# Returns 2 (ENOENT) if `@lore_config_path` doesn't exist and 0, otherwise.
function save_new_lore_config()
{
  local setting="$1"
  local new_value="$2"
  local lore_config_path="$3"

  if [[ ! -f "$lore_config_path" ]]; then
    complain "${lore_config_path}: file doesn't exists"
    return 2 # ENOENT
  fi

  sed --in-place --regexp-extended "s<(${setting}=).*<\1${new_value}<" "$lore_config_path"
}
