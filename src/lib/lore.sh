# This file is the library that handles the "back end" of interacting with the
# kernel lore archives. it handles fecthing, listing and downloading of patches
# sent to the public mailing lists.

include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/lib/web.sh"

# Lore base URL
declare -gr LORE_URL='https://lore.kernel.org/'

# Lore cache directory
declare -g CACHE_LORE_DIR="${KW_CACHE_DIR}/lore"

# File name for the lore list
declare -gr MAILING_LISTS_PAGE='lore_main_page.html'

# Path to mailing list file to be parsed
declare -g LIST_PAGE_PATH="${CACHE_LORE_DIR}/${MAILING_LISTS_PAGE}"

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

# This function downloads the lore archive main page and retrieves the names
# and descriptions of the mailing lists currently available in the archive, it
# then saves that information in the `available_lore_mailing_lists`
#
# @flag Flag to control function output
function retrieve_available_mailing_lists()
{
  local flag="$1"
  local index=''
  local pre_processed

  flag=${flag:-'SILENT'}

  setup_cache

  download "$LORE_URL" "$MAILING_LISTS_PAGE" "$CACHE_LORE_DIR" "$flag" || return "$?"

  pre_processed=$(sed -nE -e 's/^href="(.*)\/?">\1<\/a>$/\1/p; s/^  (.*)$/\1/p' "${LIST_PAGE_PATH}")

  while IFS= read -r line; do
    if [[ -z "$index" ]]; then
      index="$line"
    else
      available_lore_mailing_lists["$index"]="$line"
      index=''
    fi
  done <<< "$pre_processed"
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

function reset_list_of_mailinglist_patches()
{
  list_of_mailinglist_patches=()
}

# This is the core function responsible for parsing the XML file containing the
# new patches to be converted to the internal format used by kw. Basically, we
# want to convert the XML file to this format:
#
#  name, email, patch version, total patches, patch title, message-id
#
# Notice that this function only cares about new patches; for this reason, we
# only register the first patch as part of the list. Finally, it is worth
# highlighting the parse steps used in this function:
#
#  1. Use xpath to extract: name, email, title, and message-id.
#  2. The xpath output will keep the HTML attribute href for the message-id. By
#     using this approach, we can know the end of the patch data.
#  3. When we find the end of the data, we compress everything in a single line
#     separated by SEPARATOR_CHAR and add it to the array list.
#
# @target_mailing_list A string name that matches the mailing list name
#   registered to lore
#
# TODO:
# - Can we make it easier to read?
# - Can we simplify it?
# - Can we make this function more reliable?
# - Can we consider this function as our Model?
function processing_new_patches()
{
  local target_mailing_list="$1"
  local raw_list_path
  local pre_processed
  local -r NAME_EXP='//entry/author/name/text()'
  local -r EMAIL_EXP='//entry/author/email/text()'
  local -r TITLE_EXP='//entry/title/text()'
  local -r LINK_EXP='//entry/link/@href'
  local xpath_query
  local count=0
  local index=0
  local title
  local url_filter='?q=d:2.day.ago..+AND+NOT+s:Re&x=A'
  local default_url="${LORE_URL}${target_mailing_list}/${url_filter}"
  local shared_dir_for_parallelism
  local list_patches_file_name="list-patches-${target_mailing_list}.xml"

  download "$default_url" "$list_patches_file_name" "$CACHE_LORE_DIR" "$flag" || return "$?"

  raw_list_path="${CACHE_LORE_DIR}/${list_patches_file_name}"

  xpath_query="${NAME_EXP}|${EMAIL_EXP}|${TITLE_EXP}|${LINK_EXP}"

  pre_processed=$(< "$raw_list_path")
  pre_processed=$(printf '%s' "$pre_processed" | xpath -q -e "$xpath_query")

  # Converting to:
  #  Author, email, version, total patches, patch title, link
  shared_dir_for_parallelism=$(mktemp -d)
  while IFS= read -r line; do
    if [[ "$line" =~ href ]]; then
      message_id_link=$(str_get_value_under_double_quotes "$line")

      if is_introduction_patch "$message_id_link"; then
        # Process each patch in parallel
        thread_for_process_patch "$index" "$shared_dir_for_parallelism" \
          "$processed_line" "$message_id_link" "$title" &
        ((index++))
      fi

      processed_line=''
      count=0
      continue
    fi

    # Based on the way that we build our xpath expression, we can rely on this sequence:
    # Name, Email, Title, Link
    # Since we have a dedicated function to extract title metadata, we want to
    # save the title in a separated variable for later processing.
    case "$count" in
      0) # NAME
        processed_line="$(process_name "$line")${SEPARATOR_CHAR}"
        ;;
      1) # EMAIL
        processed_line+="${line}${SEPARATOR_CHAR}"
        ;;
      2) # TITLE
        title="$line"
        ;;
    esac

    ((count++))

  done <<< "$pre_processed"
  wait

  # From the last interaction, we have one extra index that does not exist
  ((index--))

  for i in $(seq 0 "$index"); do
    list_of_mailinglist_patches["$i"]=$(< "${shared_dir_for_parallelism}/${i}")
  done
}

# This function is the bridge between the parsed data and the dialog interface
# since it invokes the function responsible for handling lore data and
# converting it to something that dialog can handle.
#
# @target_mailing_list A string name that matches the mailing list name
#   registered to lore
# @_dialog_array An array reference to be populated inside this function
#
# TODO:
# - Is this the equivalent to a controller?
function get_patches_from_mailing_list()
{
  local target_mailing_list="$1"
  local -n _dialog_array="$2"
  declare -A series
  local raw_string
  local count=1
  local index=0
  local patch_version
  local total_patches
  local patch_title
  local tmp_data

  reset_list_of_mailinglist_patches

  processing_new_patches "$target_mailing_list"

  # Format data for printing
  for raw_patchset in "${list_of_mailinglist_patches[@]}"; do
    parse_raw_patchset_data "${raw_patchset}" 'series'
    tmp_data=$(printf 'V%-2s |#%-3s| %-100s' "${series['patchset_version']}" "${series['total_patches']}" "${series['patchset_title']}")
    _dialog_array["$index"]="$tmp_data"
    ((index++))
  done
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

# This function is a predicate about the existence of given patchset in the local
# bookmark database.
#
# @raw_patchset: Raw data of patchset in the same format as list_of_mailinglist_patches
#
# Return:
# Returns 0 if given patchset is present in local database, 1 if it is not and 2 if
# there is no local database.
#
# TODO:
# - Revise the return value of 1.
function is_bookmarked()
{
  local raw_patchset="$1"
  local count

  if [[ ! -f "${BOOKMARKED_SERIES_PATH}" ]]; then
    return 2 # ENOENT
  fi

  count=$(grep --count "$raw_patchset" "${BOOKMARKED_SERIES_PATH}")
  if [[ "$count" != 0 ]]; then
    return 0
  fi

  return 1
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
