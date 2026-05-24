include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/git.sh"

# Hash containing command line options
declare -gA options_values

# This is the main function for apply-patch command
function apply_patch_main()
{
  local ret
  local flag
  local patch_content

  flag=${flag:-'SILENT'}

  if [[ -z "$*" ]]; then
    complain 'Please, provide an argument'
    apply_patch_help
    return 22 # EINVAL
  fi

  parse_apply_patch_options "$@"

  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    apply_patch_help
    return 22 # EINVAL
  fi

  if ! is_kernel_root "$PWD"; then
    complain 'Execute this command in a kernel tree.'
    return 125 # ECANCELED
  fi

  if ! kw_git_is_repo_safe; then
    return 125 # ECANCELED
  fi

  if ! validate_url "${options_values['URL']}"; then
    return 22 # EINVAL
  fi

  say "Downloading patch..."

  patch_content=$(download_patch "$flag" "${options_values['URL']}")
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain "$patch_content"
    return "$ret"
  fi

  original_head=$(kw_git_get_current_commit_hash | cut -c1-7)
  say 'Applying patch...'

  log=$(kw_git_am "$patch_content")
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain "ERROR: Failed to apply patch, git am exit code: $ret"
    say 'git am log:'
    printf '%s\n' "$log"

    say 'Attempting to rollback...'
    kw_git_am_abort
    if [[ $? -eq 0 ]]; then
      say 'Repository has been rolled back to original state, patch was NOT aplied.'
    else
      warning 'WARNING: Could not rollback automatically. Repository may be in an inconsistent state.'
    fi
    return 1
  fi

  success 'Patch successfully applied!'
  say "To undo, you can run \"git reset --hard $original_head\"."

  return "$?"
}

# Validate URL format
# @url: The URL to validate
# Return:
# - 0 if URL is valid
# - 22 (EINVAL) URL not valid.
function validate_url()
{
  local url="$1"

  if [[ -z "$url" ]]; then
    complain 'ERROR: No URL provided.'
    return 22 # EINVAL
  fi

  if ! [[ "$url" =~ ^https?:// ]]; then
    complain "ERROR: Invalid URL format. URL ($url) must start with 'http://' or 'https://'."
    return 22 # EINVAL
  fi

  return 0
}

# Download patch from URL
# @flag: The flag passed to cmd_manager
# @url: The URL to download the patch from
# Return:
# - 0 on success
# - 1 for network errors
function download_patch()
{
  local flag="$1"
  local url="$2"
  local response
  local curl_cmd
  local http_code
  local patch_content

  curl_cmd="curl --silent --write-out \"\n%{http_code}\" --user-agent \"kw\" --max-time 30 $url"
  response=$(cmd_manager "$flag" "$curl_cmd")
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    printf '%s\n' "ERROR: Failed to download patch from URL, curl exit code: $ret"
    return 1
  fi

  http_code=$(tail -n1 <<< "$response")
  patch_content=$(sed '$ d' <<< "$response")

  if [[ "$http_code" != 200 ]]; then
    printf '%s\n' "ERROR: Failed to download patch from URL, response HTTP code: $http_code"
    return 1
  fi

  printf '%s\n' "$patch_content"
}

function parse_apply_patch_options()
{
  local long_options='help'
  local short_options='h'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw apply-patch' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help | -h)
        apply_patch_help
        exit
        ;;
      *)
        options_values['URL']="$1"
        shift
        ;;
    esac
  done
}

function apply_patch_help()
{
  printf '%s\n' \
    'kw apply-patch - Apply a patch from a URL' \
    '' \
    'Usage: kw apply-patch <URL>' \
    '' \
    'This command downloads a patch from the given URL and applies it to the' \
    'current work tree using "git am". It requires the command to be executed' \
    'from within a kernel tree.' \
    '' \
    'Options:' \
    '  -h, --help    Show this help message' \
    '' \
    'Examples:' \
    '  kw apply-patch "https://lore.kernel.org/<list>/<message-id>/raw"' \
    ''
}
