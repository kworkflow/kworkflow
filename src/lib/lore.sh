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

# Number of patchsets processed current lore fetch session.
# Also, the size of `list_of_mailinglist_patches`.
declare -g PATCHSETS_PROCESSED=0

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

# This is a global array that kw uses to store the list of new patches from a
# target mailing list. After kw parses the data from lore, we will have a list
# that follows this pattern:
#
#  Author, email, version, total patches, patch title, link
#
# Note: To separate those elements, we use the variable SEPARATOR_CHAR, which
# can be a ',' but by default, we use 'Æ'. We used ',' in the example for make
# it easy to undertand.
declare -ag list_of_mailinglist_patches

# This associative array stores the current processed patchsets and it is used
# to check if a given patchset was already processed.
declare -Ag processed_patchsets

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

# This function parser the message-id link for trying to find if the target
# patch is the first one from the series (in the case of a patchset, the first
# patch is the cover-letter) or not. This is useful for identifying cover
# letters or patches from a sequence.
#
# @message_id_link String with the message id link
#
# Return
# If it is the first patch, return 0; otherwise, return 1.
function is_introduction_patch()
{
  local message_id_link="$1"
  local sequence

  sequence=$(grep --only-matching --perl-regexp '\-[0-9]+\-' <<< "$message_id_link")
  sequence=$(printf '%s' "$sequence" | tr -d '-')

  [[ "$sequence" == 1 ]] && return 0
  return 1
}

# Verify if the target URL is accessible or not.
#
# @url Target url
#
# Return:
# If the URL is accessible, return 0. Otherwise, return 22.
function is_the_link_valid()
{
  local url="$1"
  local curl_cmd='curl --insecure --silent --fail --silent --head'
  local raw_curl_output
  local url_status_code

  [[ -z "$url" ]] && return 22 # EINVAL

  curl_cmd+=" $url"
  raw_curl_output=$(eval "$curl_cmd")

  url_status_code=$(printf '%s' "$raw_curl_output" | grep --extended-regexp '^HTTP' | cut -d ' ' -f2)
  [[ "$url_status_code" == 200 ]] && return 0
  return 22 # EINVAL
}

# Lore URL has a pattern that looks like this:
#
# https://lore.kernel.org/[LIST]/[MESSAGE-ID]-[PATCH NUMBER]-[AUTHOR EMAIL]/T/#u
#
# With this idea in mind, this function checks for '-[PATCH NUMBER]-' in the
# URL. Based on that, it increments the PATCH Number by one until we reach an
# invalid URL and figure out the total of patches in the series.
#
# @url Target url
#
# Return:
# Return the total of patches.
function total_patches_in_the_series()
{
  local url="$1"
  local total=0
  local link_ref=1
  local ret

  url=$(replace_http_by_https "$url")

  until ! is_the_link_valid "$url"; do
    ((total++))
    ((link_ref++))
    url="${url/-[0-9]*-/-$link_ref-}"
  done

  printf '%d' "$total"
}

# Usually, the Linux kernel patch title has a lot of helpful information, and
# this function is responsible for extracting patch information from the patch
# title. This function extracts:
#
#  Patch version, Total of patches, Patch title, URL
#
# @patch_title Raw patch title to be parsed
#
# Return: Return a string with patch version, total patches, and patch title
# separated by SEPARATOR_CHAR.
#
# FIXME: In this function, we collect metadata from the patch title; this is
# useful but fragile since we rely on developers following the right approach.
# Ideally, we should use this approach as a last resource to collect the
# information; we should always favor the lore API. For sure, we can get the
# total patches by parsing "-NUMBER-" in the message-id, but for the patch
# version, this is not so straightforward.
function extract_metadata_from_patch_title()
{
  local patch_title="$1"
  local url="$2"
  local patch_prefix
  local patch_version="1${SEPARATOR_CHAR}"
  local total_patches="X${SEPARATOR_CHAR}"
  local patch_title="${patch_title}"

  patch_prefix=$(printf '%s' "$patch_title" | grep --only-matching --perl-regexp '^\[(RFC|PATCH).*\]')
  if [[ "$?" == 0 ]]; then
    # Patch version
    patch_version=$(printf '%s' "$patch_prefix" | grep --only-matching --perl-regexp '[v|V]+\d+' | grep --only-matching --perl-regexp '\d+')
    [[ "$?" != 0 ]] && patch_version=1
    patch_version+="${SEPARATOR_CHAR}"

    # How many patches
    total_patches=$(total_patches_in_the_series "$url")
    if [[ "$total_patches" == 0 ]]; then
      total_patches=$(printf '%s' "$patch_prefix" | grep --only-matching --perl-regexp "\d+/\d+" | grep --only-matching --perl-regexp "\d+$")
      [[ "$?" != 0 ]] && total_patches=1
    fi
    total_patches+="${SEPARATOR_CHAR}"

    # Get patch title
    patch_title=$(printf '%s' "$patch_title" | cut -d ']' -f2)
    patch_title=$(str_strip "$patch_title")
  fi

  patch_title+="${SEPARATOR_CHAR}"

  printf '%s%s%s%s' "$patch_version" "$total_patches" "$patch_title" "$url"
}

# This function was tailored to run in a subshell because we want to run this
# sort of data processing in parallel to avoid blocking users for a long time.
#
# @id: Id used to retrieve the data processed by this function
# @base_dir: Where this function will save the data
# @processed_line: Pre-filled data
# @message_id_link: Message id to be composed in the final result
# @title: Patch title
function thread_for_process_patch()
{
  local id="$1"
  local base_dir="$2"
  local processed_line="$3"
  local message_id_link="$4"
  local title="$5"

  processed_line+=$(extract_metadata_from_patch_title "$title" "$message_id_link")

  printf '%s' "${processed_line}" > "${base_dir}/${id}"
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

# This function resets all data structures that represent the current lore
# fetch session. A lore fetch session is constituted by an array with the
# latest patchsets of a lore public mailing list ordered, the number of patchsets
# processed (the size of the array), and the minimum exclusive index of the
# response (see `MIN_INDEX` declaration).
function reset_current_lore_fetch_session()
{
  list_of_mailinglist_patches=()
  PATCHSETS_PROCESSED=0
  MIN_INDEX=0
  unset processed_patchsets
  declare -Ag processed_patchsets
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

  # TODO: We need to use the query prefix 's:Re:' to filter out replies and match
  # only real patches. Are we filtering possible patches? If no, can we filter more
  # messages to obtain a lighter response file?
  query_filter="?x=A&o=${min_index}&q=rt:..+AND+NOT+s:Re"
  [[ -n "$additional_filters" ]] && query_filter+="+AND+${additional_filters}"
  query_url="${LORE_URL}/${target_mailing_list}/${query_filter}"
  printf '%s' "$query_url"
}

# This function pre-processes an XML file containing a list of patches, extracting
# just the metadata needed to process an XML element representing a patch. The `xpath`
# command is used to capture the desired fields for each patch. A simplified example
# of an XML element representing a patch is:
#   <entry>
#     <author>
#       <name>David Tadokoro</name>
#       <email>davidbtadokoro@usp.br</email>
#     </author>
#     <title>[PATCH] drm/amdkfd: Fix memory allocation</title>
#     <updated>2023-08-09T21:27:00Z</updated>
#     <link href="http://lore.kernel.org/amd-gfx/20230809212615.137674-1-davidbtadokoro@usp.br/"/>
#   </entry>
#
# The pre-processed version of this example element would be:
#   David Tadokoro
#   davidbtadokoro@usp.br
#   [PATCH] drm/amdkfd: Fix memory allocation
#    href="http://lore.kernel.org/amd-gfx/20230809212615.137674-1-davidbtadokoro@usp.br/"
#
# @xml_file_path: Path to XML file
#
# Return:
# The status code is the same as the `xpath` command and the pre-processed XML file
# is outputted to the standard output
function pre_process_xml_result()
{
  local xml_file_path="$1"
  local xpath_query
  local raw_xml
  local -r NAME_EXP='//entry/author/name/text()'
  local -r EMAIL_EXP='//entry/author/email/text()'
  local -r TITLE_EXP='//entry/title/text()'
  local -r LINK_EXP='//entry/link/@href'

  raw_xml=$(< "$xml_file_path")
  xpath_query="${NAME_EXP}|${EMAIL_EXP}|${TITLE_EXP}|${LINK_EXP}"
  printf '%s' "$raw_xml" | xpath -q -e "$xpath_query"
}

# This function converts a list of patches into a list of patchsets stored
# in the `list_of_mailinglist_patches` array. A patchset differs from a
# single patch, because the first includes all patches in a series of patches
# which can have different version. For each multipart patchset, the first patch
# is either a cover letter or a actual patch and is the representative of the
# patchset. This patch metadata is the one stored in `list_of_mailinglist_patches`.
#
# @pre_processed_patches: String containing a list of pre-processed patches
# TODO:
# - The function `is_introduction_patch` basically filters which patch is a
#   representative of the patchset by the message-ID. Some valid representatives
#   are wrongly filtered out, because of what the function considers a message-ID
#   from a representative.
# - The function `extract_metadata_from_patch_title` called by `thread_for_process_patch`
#   counts the cover letter as a patch which results in patchsets with cover letters
#   having one more patch than in reality.
function process_patchsets()
{
  local pre_processed_patches="$1"
  local shared_dir_for_parallelism
  local processed_patchset
  local starting_index
  local patch_title
  local patch_url
  local count
  local line
  local pids
  local i

  shared_dir_for_parallelism=$(create_shared_memory_dir)

  starting_index="$PATCHSETS_PROCESSED"
  count=0
  i=0

  while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]href= ]]; then
      patch_url=$(str_get_value_under_double_quotes "$line")

      if [[ "${processed_patchsets["$patch_url"]}" != 1 ]] && is_introduction_patch "$patch_url"; then
        # Processes each patch in parallel
        thread_for_process_patch "$PATCHSETS_PROCESSED" "$shared_dir_for_parallelism" \
          "$processed_patchset" "$patch_url" "$patch_title" &
        pids[i]="$!"
        ((i++))
        ((PATCHSETS_PROCESSED++))
        processed_patchsets["$patch_url"]=1
      fi

      processed_patchset=''
      count=0
      continue
    fi

    # Based on the way that we build our xpath expression, we can rely on this sequence:
    # Name, Email, Title, Link
    # Since we have a dedicated function to extract title metadata, we want to
    # save the title in a separated variable for later processing.
    case "$count" in
      0) # NAME
        processed_patchset="$(process_name "$line")${SEPARATOR_CHAR}"
        ;;
      1) # EMAIL
        processed_patchset+="${line}${SEPARATOR_CHAR}"
        ;;
      2) # TITLE
        patch_title="$line"
        ;;
    esac

    ((count++))
  done <<< "$pre_processed_patches"

  # Wait for specific PID to avoid interfering in other functionalities.
  for pid in "${pids[@]}"; do
    wait "$pid"
  done

  for i in $(seq "$starting_index" "$((PATCHSETS_PROCESSED - 1))"); do
    list_of_mailinglist_patches["$i"]=$(< "${shared_dir_for_parallelism}/${i}")
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
#     `list_of_mailinglist_patches` array.
#
# In case the number of patchsets in `list_of_mailinglist_patches` is less than
# `page` times `patchsets_per_page`, update `MIN_INDEX` and repeat steps 1 to 3.
#
# This function considers the totality of ordered patchsets in chunks of the same
# size named pages. The `page` argument indicates until which page of the latest
# patchsets should the fetch occur.
#
# Each entry in `list_of_mailinglist_patches` has the following patchset metadata
# separated by `SEPARATOR_CHAR`:
#   author name, author email, patchset version, number of patches, patch title, message-ID
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
  local raw_xml
  local lore_query_url
  local xml_result_file_name
  local pre_processed_patches
  local xml_result_file_name
  local lore_query_url
  local raw_xml
  local ret

  flag=${flag:-'SILENT'}
  xml_result_file_name="${target_mailing_list}-patches.xml"

  while [[ "$PATCHSETS_PROCESSED" -lt "$((page * patchsets_per_page))" ]]; do
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

    # Processing patches into patchsets that will be stored in `list_of_mailinglist_patches`.
    pre_processed_patches=$(pre_process_xml_result "${CACHE_LORE_DIR}/${xml_result_file_name}")
    # TODO: Is passing `pre_processed_patches` (huge string) as argument a possible bottleneck?
    process_patchsets "$pre_processed_patches"

    # Update minimum exclusive index.
    MIN_INDEX=$((MIN_INDEX + LORE_PAGE_SIZE))
  done
}

# This function formats a range of patchsets metadata from `list_of_mailinglist_patches`
# into an array reference passed as argument. The format of the metadata follows the
# pattern:
#
#  V <version_of_patchset> | #<number_of_patches> | <patchset_title>
#
# @_formatted_patchsets_list: Array reference to output formatted range of patchsets metadata
# @starting_index: Starting index of range from `list_of_mailinglist_patches`
# @ending_index: Ending index of range `list_of_mailinglist_patches`
function format_patchsets()
{
  local -n _formatted_patchsets_list="$1"
  local starting_index="$2"
  local ending_index="$3"
  declare -A patchset

  for i in $(seq "$starting_index" "$ending_index"); do
    parse_raw_patchset_data "${list_of_mailinglist_patches["$i"]}" 'patchset'
    _formatted_patchsets_list["$i"]=$(printf 'V%-2s |#%-3s|' "${patchset['patchset_version']}" "${patchset['total_patches']}")
    _formatted_patchsets_list["$i"]+=$(printf ' %-100s' "${patchset['patchset_title']}")
  done
}

# This function outputs the starting index in the `list_of_mailinglist_patches` array of a given
# page, i.e., if the patchsets of the page 2 are from `list_of_mailinglist_patches[30]` until
# `list_of_mailinglist_patches[59]`, this function outputs '30'.
#
# @page: Number of the target page.
# @patchsets_per_page: Number of patchsets per page
function get_page_starting_index()
{
  local page="$1"
  local patchsets_per_page="$2"
  local starting_index

  starting_index=$(((page - 1) * patchsets_per_page))
  # Avoid an starting index greater than the max index of `list_of_mailinglist_patches`
  if [[ "$starting_index" -gt "$((${#list_of_mailinglist_patches[@]} - 1))" ]]; then
    starting_index=$((${#list_of_mailinglist_patches[@]} - 1))
  fi
  printf '%s' "$starting_index"
}

# This function outputs the ending index in the `list_of_mailinglist_patches` array of a given
# page, i.e., if the patchsets of the page 2 are from `list_of_mailinglist_patches[30]` until
# `list_of_mailinglist_patches[59]`, this function outputs '59'.
#
# @page: Number of the target page
# @patchsets_per_page: Number of patchsets per page
function get_page_ending_index()
{
  local page="$1"
  local patchsets_per_page="$2"
  local ending_index

  ending_index=$(((page * patchsets_per_page) - 1))
  # Avoid an ending index greater than the max index of `list_of_mailinglist_patches`
  if [[ "$ending_index" -gt "$((${#list_of_mailinglist_patches[@]} - 1))" ]]; then
    ending_index=$((${#list_of_mailinglist_patches[@]} - 1))
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
# @raw_patchset: Raw data of patchset in the same format as list_of_mailinglist_patches
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
  local patch_title
  local patch_author
  local tmp_data

  if [[ ! -f "${BOOKMARKED_SERIES_PATH}" ]]; then
    return 2 # ENOENT
  fi

  _bookmarked_series=()

  while IFS='' read -r raw_patchset; do
    parse_raw_patchset_data "${raw_patchset}" 'series'
    tmp_data=$(printf ' %s | %-70s | %s' "${series['timestamp']}" "${series['patchset_title']}" "${series['patchset_author']}")
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

# This function parses raw data that represents a patchset instance into
# an associative array passed as reference. This function assumes that the
# raw data has attributes in the following order:
#   patchset_author, author_email, patchset_version, total_patches, patchset_title,
#   patchset_url, download_dir_path, timestamp.
#
# Note that the function doesn't verifies if the attributes are non-empty or
# valid (i.e. represent a valid patchset instance), passing the responsability to
# the caller.
#
# @raw_patchset: Raw data of patchset in the same format as list_of_mailinglist_patches
function parse_raw_patchset_data()
{
  local raw_patchset="$1"
  local -n _patchset="$2"
  local columns

  IFS="${SEPARATOR_CHAR}" read -ra columns <<< "${raw_patchset}"
  _patchset['patchset_author']="${columns[0]}"
  _patchset['author_email']="${columns[1]}"
  _patchset['patchset_version']="${columns[2]}"
  _patchset['total_patches']="${columns[3]}"
  _patchset['patchset_title']="${columns[4]}"
  _patchset['patchset_url']="${columns[5]}"
  _patchset['download_dir_path']="${columns[6]}"
  _patchset['timestamp']="${columns[7]}"
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
