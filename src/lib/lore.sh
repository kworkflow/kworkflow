# This file is the library that handles the "back end" of interacting with the
# kernel lore archives. it handles fecthing, listing and downloading of patches
# sent to the public mailing lists.

include "${KW_LIB_DIR}/kwlib.sh"
include "${KW_LIB_DIR}/lib/web_access.sh"

declare -gr LORE_URL='https://lore.kernel.org/'
declare -gA available_lore_mailing_lists

# This function downloads the lore archive main page and retrieves the names
# and descriptions of the mailing lists currently available in the archive, it
# then saves that information in the `available_lore_mailing_lists`
#
# @flag Flag to control function output
function retrieve_available_mailing_lists()
{
  local main_page='lore_main_page.html'
  local flag="$1"
  local index=''
  local pre_processed

  flag=${flag:-'SILENT'}

  download "$LORE_URL" "$main_page" '' "$flag" || return "$?"

  pre_processed=$(sed -nE -e 's/^href="(.*)\/?">\1<\/a>$/\1/p; s/^  (.*)$/\1/p' \
    "${KW_CACHE_DIR}/${main_page}")

  while IFS= read -r line; do
    if [[ -z "$index" ]]; then
      index="$line"
    else
      available_lore_mailing_lists["$index"]="$line"
      index=''
    fi
  done <<< "$pre_processed"
}

function get_n_newest_patches()
{
  local n_patches=${1:-'10'}
  local page='patch_page.xml'

  warning "$n_patches"
}

function test_lore()
{
  retrieve_available_mailing_lists "$@"
  for index in "${!available_lore_mailing_lists[@]}"; do
    printf '* %s\n  = %s\n' "${index}" "${available_lore_mailing_lists["$index"]}"
  done
}
