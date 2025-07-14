# This file handles with the kernel tags feature. It allows the user to add
# tags like 'Signed-off-by', 'Reviewed-by', 'Acked-by', 'Tested-by', 'Reported-by',
# 'Co-developed-by' and 'Fixes' to either patches or commits.

include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

declare -gA options_values

# Define a constant to store all kernel tags
declare -gA KERNEL_TAGS

KERNEL_TAGS['REPORTED_BY']='Reported-by:'
KERNEL_TAGS['CO_DEVELOPED_BY']='Co-developed-by:'
KERNEL_TAGS['ACKED_BY']='Acked-by:'
KERNEL_TAGS['TESTED_BY']='Tested-by:'
KERNEL_TAGS['REVIEWED_BY']='Reviewed-by:'
KERNEL_TAGS['SIGNED_OFF_BY']='Signed-off-by:'
KERNEL_TAGS['FIXES']='Fixes:'

# This structure organizes all the parsed trailer lines by their tags.
# For example, TRAILER_BUFFERS['SIGNED_OFF_BY'] contains all trailers
# tagged with 'Signed-off-by'. It's a string where trailers are separated
# by commas like:
# "Signed-off-by: Joe Doe <joedoe@mail.xyz>,Signed-off-by: Jane Doe <janedoe@mail.xyz>"
#
# It acts as an auxiliary variable to sort the trailers that will be written later
declare -gA grouped_trailers_by_tag

# This structure groups different tags based on unique tags.
# For example, grouped_tags['blabla@mail.xyz'] is a string which contains
# trailer lines associated to this email and separated by commas like:
# "Reviewed-by: Joe Doe <joedoe@mail.xyz>,Signed-off-by: Joe Doe <joedoe@mail.xyz>"
#
# It acts as an auxiliary variable to sort the trailers that will be written later
declare -gA grouped_trailers_by_email

# This variable holds all the emails from tags. The order of such emails
# represent the order each email entry in `grouped_trailers_by_email` was created
# during this feature's execution.
declare -ga sorted_emails

# Variable to store all trailers that will be added. If `sort_all_trailers`
# function is used, then the order obeys the following general sequence:
# - Reported-by
# - Co-developed-by
# - Acked-by
# - Tested-by
# - Reviewed-by
# - Signed-off-by
# - Fixes
# As trailer lines with the same tag are grouped together. Example:
# Reviewed-by: Joe Doe <joedoe@mail.xyz>
# Signed-off-by: Joe Doe <joedoe@mail.xyz>
# Reviewed-by: Bob Doe <bobdoe@mail.xyz>
# Signed-off-by: Bob Doe <boobdoe@mail.xyz>
declare -g all_trailers

# This function performs operations over trailers in
# either patches or commits. It checks if given argument
# is a valid commit reference or patch path and uses the
# correct command to perform the task.
# If that's not the case, a warning message will tell
# the user this argument was ignored.
#
# Also, if no operation option is given, then an error message
# followed by a helper message is printed to the user.
#
# @patch_or_sha_args Holds either patch paths or commit references.
function kernel_tag_main()
{
  local patch_or_sha_args
  local flag
  local ret

  if [[ "$1" =~ -h|--help ]]; then
    kernel_tag_help "$1"
    exit 0
  fi

  # Ensure all trailer arrays are empty
  reset_groups_info "grouped_trailers_by_tag"
  reset_groups_info "grouped_trailers_by_email"
  sorted_emails=()
  all_trailers=''

  # Parse all command line options
  parse_tag_options "$@"
  ret="$?"
  if [[ "$ret" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    return "$ret" # EINVAL
  fi

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'
  flag=${flag:-'SILENT'}

  read -ra patch_or_sha_args <<< "${options_values['PATCH_OR_SHA']}"

  if [[ -n "${options_values['NO_ADD_OPTION']}" ]]; then
    complain 'At least one --add option is required to use this command'
    kernel_tag_help
    return 22 # EINVAL
  fi

  sort_all_trailers

  for arg in "${patch_or_sha_args[@]}"; do
    write_all_trailers "$arg" "$flag"
  done
}

# This function validates the tag. If the passed tag
# does not follow the format 'NAME <EMAIL>' with a valid EMAIL, then
# it returns an error.
#
# @tag Holds the string that is validated
#
# Return:
# Returns 0 on success. If the email format is incorrect, returns 74.
# Otherwise, returns 22.
function is_valid_tag()
{
  local tag="$1"

  if [[ "$tag" =~ ^[^\<]+\ [^\<]+\<([^\>]+)\>$ ]]; then
    validate_email "${BASH_REMATCH[1]}"
    if [[ "$?" -gt 0 ]]; then
      return 74 # EBADMSG - Invalid email
    fi
  else
    return 22 # EINVAL - Invalid tag
  fi
}

# This functions extracts the NAME from a trailer line with a valid tag.
# Valid tags can be verified with `is_valid_tag`.
#
# @trailer A string that follows the pattern "TRAILER_TAG: NAME <EMAIL>"
function extract_name_from_trailer()
{
  local trailer="$1"
  printf '%s' "$trailer" | grep --only-matching --perl-regexp '(?<=: ).*?(?= <)'
}

# This functions extracts the EMAIL from a trailer line with a valid tag.
# Valid tags can be verified with `is_valid_tag`.
#
# @trailer A string that follows the pattern "TRAILER_TAG: NAME <EMAIL>"
function extract_email_from_trailer()
{
  local trailer="$1"
  printf '%s' "$trailer" | grep --only-matching --perl-regexp '<\K[^>]+'
}

# # TODO: To move this function to a 'gitlib' library
#
# This function validates if a commit reference is valid.
#
# @sha Holds a string that can be a commit hash or pointer.
#
# Returns:
# True if given argument is a valid commit reference and false otherwise.
function is_valid_commit_reference()
{
  local sha="$1"

  if [[ $(git cat-file -t "$sha" 2> /dev/null) != 'commit' ]]; then
    return 22 # EINVAL
  fi
}

# This function parses and adds a new trailer line into
# @all_trailers that will be properly written later, however
# the trailer isn't added if there's another identical one.
# It attempts to use the user's name and email configured
# if a tag is not passed as argument and gives
# an error if they are not properly set with git config.
#
# @keyword Holds a string that is a keyword for a specific operation.
# @tag Holds a string like 'NAME <EMAIL>' defining the tag.
#
# Return:
# In case of successful return 0 adding the parsed operation;
# It returns 61 if either user.name or user.email are not configured properly;
# It returns 74 If the email format is incorrect;
# It returns 22 if the tag does not follow 'NAME <EMAIL>' format;
function parse_and_add_trailer()
{
  local keyword="$1"
  local tag="$2"
  local formated_output
  local parsed_trailer
  local parsed_trailer_name
  local parsed_trailer_email
  local trailer_name
  local trailer_email
  local repeated_trailer=false
  local duplicated_email=false
  local ret

  parsed_trailer="${KERNEL_TAGS[$keyword]} "

  # Use default from git config if no argument was given
  if [[ ! "$tag" ]]; then
    formated_output="$(format_name_email_from_user)"
    if [[ "$?" -gt 0 ]]; then
      return 61 # ENODATA
    fi
    parsed_trailer+="$formated_output"
  else
    tag="$(str_strip "$tag")"
    if [[ "$keyword" != 'FIXES' ]]; then
      is_valid_tag "$tag"
      ret="$?"
      if [[ "$ret" -ne 0 ]]; then
        return "$ret" # Return the error code from is_valid_tag
      fi
    fi
    parsed_trailer+="$tag"
  fi

  # Check if this trailer has the same email, but a different name compared to
  # others already read and saved in `all_trailers`.
  while read -d ',' -r trailer; do
    # If it's a (Closes|Link) trailer, then there is no need to check email duplication.
    if [[ "${trailer}" =~ ^(Closes|Link) ]]; then
      continue
    fi
    parsed_trailer_name=$(extract_name_from_trailer "$parsed_trailer")
    parsed_trailer_email=$(extract_email_from_trailer "$parsed_trailer")
    trailer_name=$(extract_name_from_trailer "$trailer")
    trailer_email=$(extract_email_from_trailer "$trailer")
    if [[ "$trailer_email" == "$parsed_trailer_email" && "$trailer_name" != "$parsed_trailer_name" ]]; then
      duplicated_email=true
      warning "Same email used with different names: ${trailer_name}, ${parsed_trailer_name}, ${trailer_email}"
      warning "Skipping the following trailer line: '${parsed_trailer}'"
      break
    fi
  done <<< "$all_trailers"

  # Check for trailer duplication
  while read -d ',' -r item; do
    if [[ "$item" == "$parsed_trailer" ]]; then
      repeated_trailer=true
      warning "Skipping duplicated trailer line: '${parsed_trailer}'"
      break
    fi
  done <<< "${grouped_trailers_by_tag[$keyword]}"

  if [[ "$repeated_trailer" = false ]] && [[ "$duplicated_email" = false ]]; then
    grouped_trailers_by_tag["$keyword"]+="${parsed_trailer},"
    all_trailers+="${parsed_trailer},"
  fi
}

# This function receives a commit SHA and verifies if it's
# a valid commit reference. If it is, then it outputs the
# appropriate formatted message. Else it returns an error code.
#
# @sha Holds either a commit hash or pointer
#
# Return:
# In case of successful return 0 and prints the formatted message,
# otherwise, return 22.
function format_fixes_message()
{
  local sha="$1"
  local formatted_message

  # Check if given value is a valid commit reference
  if ! is_valid_commit_reference "$sha"; then
    return 22 # EINVAL
  fi

  # The 'Fixes:' trailer line must follow a format defined by Linux Kernel developers.
  # Fixes: e21d2170f366 ("video: remove unnecessary platform_set_drvdata()")
  commit_message=$(git log -1 "$sha" --format="%s")
  commit_message=$(printf "%s" "$commit_message" | sed 's/"/\\"/g')

  formatted_message=$(git log -1 "$sha" --oneline --abbrev-commit --abbrev=12 \
    --format="%h (\\\"$commit_message\\\")")

  printf '%s' "$formatted_message"
}

# It gets user.name and user.email from git's configuration.
# If either the name or email are not configured then this
# function will return an error code. Otherwise it will output
# the formatted name and email.
#
# Return:
# In case of successful return 0 and prints a properly formatted
# output, otherwise, return 61.
function format_name_email_from_user()
{
  local user_name
  local user_email

  user_name="$(git config user.name)"
  user_email="$(git config user.email)"

  # If user doesn't have either a name or email configured with
  # git then they must provide an argument
  if [[ -z "$user_name" || -z "$user_email" ]]; then
    return 61 # ENODATA
  fi

  printf '%s' "${user_name} <${user_email}>"
}

# This function gets all trailers saved in a `grouped_trailers_by_tag`
# entry and associates each trailer to a `grouped_trailers_by_email` entry.
#
# @specified_tag Holds the tag group that will be re-grouped by their emails.
function group_by_email()
{
  local specified_tag="$1"
  local email

  while read -d ',' -r trailer; do
    # Extract email from trailer
    email=$(extract_email_from_trailer "$trailer")
    # Save email if no tag with it was saved so far
    if [[ -z "${grouped_trailers_by_email[$email]}" ]]; then
      sorted_emails+=("$email")
    fi
    # Remove the associative email from (Closes|Link) trailer lines
    if [[ "${trailer}" =~ ^(Closes|Link) ]]; then
      trailer=$(printf '%s' "$trailer" | sed --regexp-extended 's/ <[^>]*>$//')
    fi
    # Append the tag to the associative array based on the email
    grouped_trailers_by_email["$email"]+="${trailer},"
  done <<< "${grouped_trailers_by_tag[$specified_tag]}"
}

# This function adds every parsed trailer in `grouped_trailers_by_tag`
# entries to `all_trailers`, following the general order proposed at the
# `all_trailers` declaration.
#
# The strategy to achieve that is to sort all trailers by their tags first,
# then sort them by their emails. By doing so, this function can enforce that
# general order, and additionally it forces tags from the same person
# to be together, avoiding multiple disconnected tags like 'Co-developed-by',
# 'Reviewed-by' or 'Signed-off-by' from the person in commits or patches.
function sort_all_trailers()
{
  all_trailers=''

  # Group all trailers by email. The order of this grouping process
  # follows the same order of the next `group_by_email` calls, sorting
  # the trailers by their tags.

  group_by_email 'SIGNED_OFF_BY'
  group_by_email 'TESTED_BY'
  group_by_email 'REPORTED_BY'
  group_by_email 'CO_DEVELOPED_BY'
  group_by_email 'ACKED_BY'
  group_by_email 'REVIEWED_BY'

  # Concatanate all email groups following the order in `sorted_emails`,
  # sorting the trailers by their emails.
  for email in "${sorted_emails[@]}"; do
    all_trailers+="${grouped_trailers_by_email[$email]}"
  done

  # Concatanate every 'Fixes' tag at the end of `all_trailers`, which means
  # they will be the last written trailers when `write_all_trailers` is called.
  while read -d ',' -r trailer; do
    all_trailers+="${trailer},"
  done <<< "${grouped_trailers_by_tag['FIXES']}"
}

# This function writes all the trailer lines stored in `all_trailers`
# into either a patch file or commit.
#
# @patch_or_sha Holds either a patch path or commit SHA
# @flag Used to specify how `cmd_manager` will be executed
function write_all_trailers()
{
  local patch_or_sha="$1"
  local flag="$2"
  local cmd

  while read -d ',' -r trailer; do
    # Check if given argument is either a patch or valid commit reference,
    # then build the correct command.
    if is_valid_commit_reference "$patch_or_sha"; then
      cmd="git commit --quiet --amend --no-edit --trailer \"${trailer}\""
      # Only call 'git rebase' if user is trying to write multiple commits
      if [[ "$(git rev-parse "$patch_or_sha")" != "$(git rev-parse HEAD)" ]]; then
        cmd="git rebase -r ${patch_or_sha} --exec '${cmd}' 2> /dev/null"
      fi
    else
      cmd="git interpret-trailers ${patch_or_sha} --in-place --trailer \"${trailer}\""
    fi
    cmd_manager "$flag" "$cmd"
  done <<< "$all_trailers"
}

# This function gets raw data and based on that fill out the options values to
# be used in another function.
#
# Return:
# Returns 0 on success. If the email format is incorrect, returns 74.
# Otherwise, returns 22.
function parse_tag_options()
{
  local long_options='add-signed-off-by::,add-reviewed-by::,add-acked-by::,add-fixes::'
  long_options+=',add-tested-by::,add-reported-by::,add-co-developed-by::,verbose'
  local short_options='s::,r::,a::,f::,t::,R::,C::'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" -gt 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw tag' \
      "$short_options" "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['PATCH_OR_SHA']='HEAD'

  options_values['VERBOSE']=''
  options_values['NO_ADD_OPTION']=1

  eval "set -- ${options}"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --add-signed-off-by | -s)
        options_values['NO_ADD_OPTION']=''

        while read -d ',' -r tag; do
          parse_and_add_trailer 'SIGNED_OFF_BY' "$tag"
          return_status="$?"

          if [[ "$return_status" -eq 61 ]]; then
            options_values['ERROR']='You must configure your user.name and user.email with git '
            options_values['ERROR']+='to use --add-signed-off-by | -s without an argument'
            return 22 # EINVAL
          elif [[ "$return_status" -eq 22 ]]; then
            options_values['ERROR']="Invalid tag format: ${tag}"
            return 22 # EINVAL
          elif [[ "$return_status" -eq 74 ]]; then
            options_values['ERROR']="Invalid email format: ${tag}"
            return 74 # EBADMSG
          fi
        done <<< "${2},"

        [[ ! "$2" ]] || shift
        shift
        ;;

      --add-reviewed-by | -r)
        options_values['NO_ADD_OPTION']=''

        while read -d ',' -r tag; do
          parse_and_add_trailer 'REVIEWED_BY' "$tag"
          return_status="$?"

          if [[ "$return_status" -eq 61 ]]; then
            options_values['ERROR']='You must configure your user.name and user.email with git '
            options_values['ERROR']+='to use --add-reviewed-by | -r without an argument'
            return 22 # EINVAL
          elif [[ "$return_status" -eq 22 ]]; then
            options_values['ERROR']="Invalid tag format: ${tag}"
            return 22 # EINVAL
          elif [[ "$return_status" -eq 74 ]]; then
            options_values['ERROR']="Invalid email format: ${tag}"
            return 74 # EBADMSG
          fi
        done <<< "${2},"

        [[ ! "$2" ]] || shift
        shift
        ;;

      --add-acked-by | -a)
        options_values['NO_ADD_OPTION']=''

        while read -d ',' -r tag; do
          parse_and_add_trailer 'ACKED_BY' "$tag"
          return_status="$?"

          if [[ "$return_status" -eq 61 ]]; then
            options_values['ERROR']='You must configure your user.name and user.email with git '
            options_values['ERROR']+='to use --add-acked-by | -a without an argument'
            return 22 # EINVAL
          elif [[ "$return_status" -eq 22 ]]; then
            options_values['ERROR']="Invalid tag format: ${tag}"
            return 22 # EINVAL
          elif [[ "$return_status" -eq 74 ]]; then
            options_values['ERROR']="Invalid email format: ${tag}"
            return 74 # EBADMSG
          fi
        done <<< "${2},"

        [[ ! "$2" ]] || shift
        shift
        ;;

      --add-tested-by | -t)
        options_values['NO_ADD_OPTION']=''

        while read -d ',' -r tag; do
          parse_and_add_trailer 'TESTED_BY' "$tag"
          return_status="$?"

          if [[ "$return_status" -eq 61 ]]; then
            options_values['ERROR']='You must configure your user.name and user.email with git '
            options_values['ERROR']+='to use --add-tested-by | -t without an argument'
            return 22 # EINVAL
          elif [[ "$return_status" -eq 22 ]]; then
            options_values['ERROR']="Invalid tag format: ${tag}"
            return 22 # EINVAL
          elif [[ "$return_status" -eq 74 ]]; then
            options_values['ERROR']="Invalid email format: ${tag}"
            return 74 # EBADMSG
          fi
        done <<< "${2},"

        [[ ! "$2" ]] || shift
        shift
        ;;

      --add-co-developed-by | -C)
        options_values['NO_ADD_OPTION']=''

        while read -d ',' -r tag; do
          parse_and_add_trailer 'CO_DEVELOPED_BY' "$tag"
          return_status="$?"

          if [[ "$return_status" -eq 61 ]]; then
            options_values['ERROR']='You must configure your user.name and user.email with git '
            options_values['ERROR']+='to use --add-co-developed-by | -C without an argument'
            return 22 # EINVAL
          elif [[ "$return_status" -eq 22 ]]; then
            options_values['ERROR']="Invalid tag format: ${tag}"
            return 22 # EINVAL
          elif [[ "$return_status" -eq 74 ]]; then
            options_values['ERROR']="Invalid email format: ${tag}"
            return 74 # EBADMSG
          fi

          parse_and_add_trailer 'SIGNED_OFF_BY' "$tag"
        done <<< "${2},"

        [[ ! "$2" ]] || shift
        shift
        ;;

      --add-reported-by | -R)
        options_values['NO_ADD_OPTION']=''

        while read -d ',' -r arg; do
          IFS=';' read -r tag tag_and_link <<< "$arg"

          parse_and_add_trailer 'REPORTED_BY' "$tag"
          return_status="$?"

          if [[ "$return_status" -eq 61 ]]; then
            options_values['ERROR']='You must configure your user.name and user.email with git '
            options_values['ERROR']+='to use --add-reported-by | -R without an argument'
            return 22 # EINVAL
          elif [[ "$return_status" -eq 22 ]]; then
            options_values['ERROR']="Invalid tag format: ${tag}"
            return 22 # EINVAL
          elif [[ "$return_status" -eq 74 ]]; then
            options_values['ERROR']="Invalid email format: ${tag}"
            return 74 # EBADMSG
          fi

          if [[ -n "$tag_and_link" ]]; then
            if ! [[ "$tag_and_link" =~ ^(Closes|Link)=[^[:space:]]+$ ]]; then
              options_values['ERROR']="Bad REPORTED_BY argument: ${tag_and_link}"
              return 22 # EINVAL
            fi
            # Extract the last email in `grouped_trailers_by_tag` and add it to the
            # (Closes|Link) trailer line. This is important to associate this trailer
            # line with the correct Reported-by tag when all trailers get sorted.
            # This email is removed from this (Closes|Link) line before writting it.
            IFS='=' read -r tag link <<< "$tag_and_link"
            email=$(extract_email_from_trailer "${grouped_trailers_by_tag['REPORTED_BY']}" |
              awk 'END {print}')
            grouped_trailers_by_tag['REPORTED_BY']+="${tag}: ${link} <$email>,"
            all_trailers+="${tag}: ${link} <$email>,"
          fi
        done <<< "${2},"

        [[ ! "$2" ]] || shift
        shift
        ;;

      --add-fixes | -f)
        options_values['NO_ADD_OPTION']=''

        if [[ ! "$2" ]]; then
          options_values['ERROR']='The option --add-fixes | -f demands an argument'
          return 22 # EINVAL
        fi

        formatted_message="$(format_fixes_message "$(str_strip "$2")")"
        if [[ "$?" -gt 0 ]]; then
          options_values['ERROR']="Invalid commit reference with --add-fixes | -f: ${2}"
          return 22 # EINVAL
        elif [[ "$return_status" -eq 74 ]]; then
          options_values['ERROR']="Invalid email format: ${tag}"
          return 74 # EBADMSG
        fi

        parse_and_add_trailer 'FIXES' "$formatted_message"
        shift 2
        ;;

      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;

      --)
        # End of options, beginning of arguments.
        # Overwrite default value if at least one argument is given.
        [[ -n "$2" ]] && options_values['PATCH_OR_SHA']=''
        shift
        ;;
      *)
        # Ignore empty argument. No need to validate it.
        if [[ -z "$1" ]]; then
          shift
          continue
        fi

        # Get all passed arguments each loop
        if [[ "$1" == *"*"* ]]; then
          # Expand the glob and loop through each resulting file
          for arg in $1; do
            if ! is_valid_commit_reference "$arg" && ! is_a_patch "$arg"; then
              options_values['ERROR']="Neither a patch nor a valid commit reference: ${arg}"
              return 22 # EINVAL
            fi
            options_values['PATCH_OR_SHA']+=" ${arg}"
          done
        else
          if ! is_valid_commit_reference "$1" && ! is_a_patch "$1"; then
            options_values['ERROR']="Neither a patch nor a valid commit reference: ${1}"
            return 22 # EINVAL
          fi
          options_values['PATCH_OR_SHA']+=" ${1}"
        fi
        shift
        ;;
    esac
  done
}

# This function clears all entries of an associative array
# passed by reference, removing all its keys and values.
function reset_groups_info()
{
  local -n array_name="$1"
  for key in "${!array_name[@]}"; do
    unset "array_name[$key]"
  done
}

function kernel_tag_help()
{
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'kernel-tag'
    return
  fi
  printf '%s\n' 'kw kernel-tag:' \
    '  kernel-tag (--add-signed-off-by | -s) (<name>,...) [<patchset> | <sha>] - Add Signed-off-by' \
    '  kernel-tag (--add-reviewed-by | -r) (<name>,...) [<patchset> | <sha>] - Add Reviewed-by' \
    '  kernel-tag (--add-acked-by | -a) (<name>,...) [<patchset> | <sha>] - Add Acked-by' \
    '  kernel-tag (--add-tested-by | -t) (<name>,...) [<patchset> | <sha>] - Add Tested-by' \
    '  kernel-tag (--add-co-developed-by | -C) (<name>,...) [<patchset> | <sha>] - Add Co-developed-by and Signed-off-by' \
    '  kernel-tag (--add-reported-by | -R) (<name>;Closes|Link=<link>,...) [<patchset> | <sha>] - Add Reported-by' \
    '  kernel-tag (--add-fixes | -f) [<fixed-sha>] [<patchset> | <sha>] - Add Fixes' \
    '  kernel-tag (--verbose) - Show a detailed output'
}

load_kworkflow_config
