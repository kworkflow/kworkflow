LORE_URL='https://lore.kernel.org/'
CACHE='./cache'

declare -gr SEPARATOR_CHAR='Æ'

# This is a global array that we use to store the list of new patches from a
# target mailing list. After we parse the data from lore, we will have a list
# that follows this pattern:
#
#  Author, email, version, total patches, patch title, link
#
#Note: To separate those elements, we use the variable SEPARATOR_CHAR, which
#can be a ',' but by default, we use 'Æ'. We used ',' in the example for make
#it easy to undertand.
declare -ag list_of_mailinglist_patches

declare -r BASE_PATH_MBOX_DOWNLOAD="$PWD/mbox_download"

function reset_list_of_mailinglist_patches()
{
  list_of_mailinglist_patches=()
}

# Download a page.
#
# @url Target url
# @cache_path Save downloaded page to a specific path
function download()
{
  local url="$1"
  local cache_path="$2"

  mkdir -p "$CACHE"

  curl --silent "$url" --output "$cache_path"
}

function url_update_patch_number()
{
  local url="$1"
  local new_number="$2"

  url="${url/-[0-9]*-/-$link_ref-}"

  printf '%s' "$url"
}

function download_series()
{
  local total_patches="$1"
  local first_message_id="$2"
  local save_to="$3"
  local title="$4"
  local total
  local link_ref
  local url
  local patch_file_name

  save_to="${BASE_PATH_MBOX_DOWNLOAD}/${save_to}"

  mkdir -p "$save_to"

  url=$(replace_http_by_https "$first_message_id")

  until ! is_the_link_valid "$url"; do
    ((total++))
    ((link_ref++))

    url=$(url_update_patch_number "$url" "$link_ref")
    patch_file_name=$(convert_title_to_patch_name "$title" "$link_ref")
    download "${url}raw" "${save_to}/$patch_file_name" &
  done
  wait
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

  printf '%s' "$processed_line" > "$base_dir/$id"
}

# Usually, the Linux kernel patch title has a lot of helpful information, and
# this function is responsible for extracting patch information from the patch
# title.
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

  patch_prefix=$(printf '%s' "$patch_title" | grep -oP "^\[PATCH.*\]")
  if [[ "$?" == 0 ]]; then
    # Patch version
    patch_version=$(printf '%s' "$patch_prefix" | grep -oP '[v|V]+\d+' | grep -oP '\d+')
    [[ "$?" != 0 ]] && patch_version=1
    patch_version+="${SEPARATOR_CHAR}"

    # How many patches
    total_patches=$(total_patches_in_the_series "$url")
    if [[ "$total_patches" == 0 ]]; then
      total_patches=$(printf '%s' "$patch_prefix" | grep -oP "\d+/\d+" | grep -oP "\d+$")
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

# Get value under double-quotes
#
# @string String to be processed
#
# Return:
# Return data between quotes
function str_get_value_under_double_quotes()
{
  local string="$1"

  printf '%s' "$string" | sed 's/^[^"]*"\([^"]*\)".*/\1/'
}

# TODO: We already have it on kw
function str_strip()
{
  local str
  str="$*"
  printf '%s\n' "$str" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
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

  if [[ ${#full_name[@]} -eq 0 ]]; then
    printf '%s' "$name_str"
    return
  fi

  # We need to handle "Second_name, name"
  printf '%s' "${full_name[1]} ${full_name[0]}"
}

# This function parser the message-id link for trying to find if the target
# patch is the first one from the series or not. This is useful for identifying
# cover letters or patches from a sequence.
#
# @message_id_link String with the message id link
#
# Return
# If it is the first patch, return 0; otherwise, return 1.
function is_introduction_patch()
{
  local message_id_link="$1"
  local sequence

  sequence=$(grep -Eo '\-[0-9]+\-'  <<< "$message_id_link")
  sequence=$(printf '%s' "$sequence" | tr -d '-')

  [[ "$sequence" == 1 ]] && return 0
  return 1
}

function replace_http_by_https()
{
  local url="$1"
  local new_url

  new_url="${url/http:\/\//https:\/\/}"
  printf '%s' "$new_url"
}

function is_the_link_valid()
{
  local url="$1"
  local curl_cmd='curl --insecure --silent --fail --silent --head'
  local raw_curl_output
  local url_status_code

  curl_cmd+=" $url"
  raw_curl_output=$(eval "$curl_cmd")

  url_status_code=$(printf '%s' "$raw_curl_output" | grep -E '^HTTP' | cut -d ' ' -f2)
  [[ "$url_status_code" == 200 ]] && return 0
  return 22 # ENVAL
}

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
# @lore_target_filter Filter used to get the patches
#
# TODO:
# - Can we make it easier to read?
# - Can we simplify it?
# - Can we make this function more reliable?
# - Can we consider this function as our Model?
function processing_new_patches()
{
  local target_mailing_list="$1"
  local lore_target_filter="$2"
  local raw_list_path="$CACHE/list-patches.xml"
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
  local default_url="https://lore.kernel.org/$target_mailing_list/$url_filter"
  local shared_dir_for_parallelism

  download "$default_url" "$raw_list_path"

  xpath_query="$NAME_EXP|$EMAIL_EXP|$TITLE_EXP|$LINK_EXP"

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
    list_of_mailinglist_patches["$i"]=$(< "$shared_dir_for_parallelism/$i")
  done
}

function title_to_path()
{
  local title="$1"
  local file_name

  # Replace space in favor of _
  file_name="${title// /_}"

  # Replace .
  file_name="${file_name//./_}"

  # Replace special character
  file_name="${file_name//[&*+%!:,]/}"

  # Replace /
  file_name="${file_name//[\/\\]/-}"

  printf '%s' "$file_name"
}

function convert_title_to_patch_name()
{
  local title="$1"
  local index="$2"
  local file_name

  file_name=$(title_to_path "$title")

  if [[ -n "$index" ]]; then
    printf '%04d-%s\n' "$index" "${file_name}.mbox"
    return
  fi

  printf '%s\n' "${file_name}.mbox"
}

function convert_title_to_folder_name()
{
  local title="$1"
  local folder_name

  folder_name="$(date +"%m-%d-%y-%H-%M-%s-")"
  folder_name+=$(title_to_path "$title")

  printf '%s' "${folder_name}"
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
  for element in "${list_of_mailinglist_patches[@]}"; do
    IFS="${SEPARATOR_CHAR}" read -r -a columns <<< "$element"
    patch_version="${columns[2]}"
    total_patches="${columns[3]}"
    patch_title="${columns[4]}"

    convert_title_to_patch_name "$patch_title"

    tmp_data=$(printf 'V%-2s |#%-3s| %-100s' "$patch_version" "$total_patches" "$patch_title")

    _dialog_array["$index"]="$count"
    ((index++))
    _dialog_array["$index"]="$tmp_data"
    ((index++))
    ((count++))
  done
}

# Test functions
# echo "$raw_list_name"
#processing_new_patches 'dri-devel'
#printf '%s\n' "${list_of_mailinglist_patches[@]}"
#download_series 5 "http://lore.kernel.org/dri-devel/20220204163711.439403-1-michael.cheng@intel.com/" 'del_me'
# 3 patches
#ref_patch='http://lore.kernel.org/amd-gfx/20220128200825.8623-1-alex.sierra@amd.com/'
#total_patches_in_the_series "$ref_patch"

#convert_title_to_patch_name "drm/selftests: Move i915 & buddy ! selftests into drm" 1
