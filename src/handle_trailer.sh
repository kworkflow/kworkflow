include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

declare -gA options_values

# This fnuction performs operations over trailers in
# either patches or commits. It checks if given argument
# is a valid commit reference or patch path and uses the
# correct command to perform the task.
# If that's not the case, a warning message will tell
# the user this argument was ignored.
#
# Also, if no operation option is given, then an error message
# followed by a helper message is printed to the user.
#
# @PATCH_OR_SHA Holds a patch path or commit reference.
# @TRAILER_TAG Holds the key of the operation's trailer.
# @TRAILER_VALUE Holds the value of the operation's trailer.
# @flag Defines the type of output this function will have.
# @cmd Holds the command used to perform the trailer operation.
function handle_trailer_main()
{
  local PATCH_OR_SHA
  local TRAILER_TAG
  local TRAILER_VALUE
  local flag
  local cmd

  if [[ "$1" =~ -h|--help ]]; then
    handle_trailer_help "$1"
    exit 0
  fi

  parse_handle_trailer_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'
  flag=${flag:-'SILENT'}

  read -ra PATCH_OR_SHA <<< "${options_values['PATCH_OR_SHA']}"
  TRAILER_TAG=${options_values['TRAILER_TAG']}
  TRAILER_VALUE=${options_values['TRAILER_VALUE']}

  if [[ -z "$TRAILER_TAG" ]]; then
    complain 'An option is required to use this command.'
    handle_trailer_help
    return 22 # EINVAL
  fi

  for arg in "${PATCH_OR_SHA[@]}"; do
    # Check if given argument is either a patch or valid commit reference,
    # then build the correct command.
    if [[ $(git cat-file -t "$arg" 2> /dev/null) == 'commit' ]]; then
      cmd="git commit --quiet --amend --no-edit --trailer \"${TRAILER_TAG} ${TRAILER_VALUE}\""
      # Only call 'git rebase' if user is trying to handle multiple commits
      if [[ "$(git rev-parse "$arg")" != "$(git rev-parse HEAD)" ]]; then
        cmd="git rebase ${arg} --exec '${cmd}' 2> /dev/null"
      fi
    elif is_a_patch "$arg"; then
      cmd="git interpret-trailers ${arg} --in-place --trailer"
      cmd+=" \"${TRAILER_TAG} ${TRAILER_VALUE}\""
    else
      warning "Neither a patch nor a valid commit. Ignoring ${arg}"
      continue
    fi
    cmd_manager "$flag" "$cmd"
  done
}

# This function gets raw data and based on that fill out the options values to
# be used in another function.
#
# Return:
# In case of successful return 0, otherwise, return 22.
function parse_handle_trailer_options()
{
  local long_options='add-reviewed-by:,add-acked-by:,add-fixes:,verbose'
  local short_options='r:,a:,f:'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw commit-trailer' \
      "$short_options" "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['TRAILER_TAG']=''
  options_values['TRAILER_VALUE']=''
  options_values['PATCH_OR_SHA']='HEAD'
  options_values['VERBOSE']=''

  eval "set -- ${options}"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --add-reviewed-by | -r)
        options_values['TRAILER_TAG']='Reviewed-by:'
        options_values['TRAILER_VALUE']="$(str_strip "$2")"
        shift 2
        ;;
      --add-acked-by | -a)
        options_values['TRAILER_TAG']='Acked-by:'
        options_values['TRAILER_VALUE']="$(str_strip "$2")"
        shift 2
        ;;
      --add-fixes | -f)
        options_values['TRAILER_TAG']='Fixes:'
        options_values['TRAILER_VALUE']="$(str_strip "$2")"

        # Check if given value is a valid commit reference
        if [[ $(git cat-file -t "${options_values['TRAILER_VALUE']}" 2> /dev/null) != 'commit' ]]; then
          options_values['ERROR']='Invalid commit reference with --add-fixes option: '
          options_values['ERROR']+="${options_values['TRAILER_VALUE']}"
          return 22 # EINVAL
        fi

        # The 'Fixes:' trailer line must follow a format defined by
        # Linux Kernel developers. Example:
        # Fixes: e21d2170f366 ("video: remove unnecessary platform_set_drvdata()")
        options_values['TRAILER_VALUE']=$(git log -1 "${options_values['TRAILER_VALUE']}" \
          --oneline --format="%h (\\\"%s\\\")" \
          --abbrev-commit --abbrev=12)
        shift 2
        ;;
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      --)
        # End of options, beginning of arguments
        if [[ -n "$2" ]]; then
          # Overwrite default value
          options_values['PATCH_OR_SHA']="$2"
          shift
        fi
        shift
        ;;
      *)
        # Get all passed arguments each loop
        options_values['PATCH_OR_SHA']+=" $1"
        shift
        ;;
    esac
  done
}

function handle_trailer_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'handle-trailer'
    return
  fi
  printf '%s\n' 'kw handle-trailer:' \
    'Every (--add-*) option adds trailer to a single <patch> or <sha> and its successors' \
    '  handle-trailer (--add-reviewed-by | -r) [<name>] [<patch> | <sha>] - Add Reviewed-by' \
    '  handle-trailer (--add-acked-by | -a) [<name>] [<patch> | <sha>] - Add Acked-by' \
    '  handle-trailer (--add-fixes | -f) [<fixed-sha>] [<patch> | <sha>] - Add Fixes' \
    '  handle-trailer (--verbose) - Show a detailed output'
}

load_kworkflow_config
