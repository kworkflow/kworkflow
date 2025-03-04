include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kw_db.sh"
include "${KW_LIB_DIR}/lib/kw_time_and_date.sh"

declare -gA options_values
declare -gA set_confs

# flag that indicates if smtpuser was set based on user.email
declare -g smtpuser_autoset=0

declare -ga essential_config_options=('user.name' 'user.email'
  'sendemail.smtpuser' 'sendemail.smtpserver' 'sendemail.smtpserverport')
declare -ga optional_config_options=('sendemail.smtpencryption' 'sendemail.smtppass')

declare -gr email_regex='[A-Za-z0-9_\.-]+@[A-Za-z0-9_-]+(\.[A-Za-z0-9]+)+'

# Functions from kwlib.sh

# Checks if the command is being run inside a git work-tree
#
# @flag: How to display (or not) the command used
#
# Returns:
# 0 if is inside a git work-tree root and 128 otherwise.
function is_inside_work_tree()
{
  local flag="$1"
  local cmd='git rev-parse --is-inside-work-tree &> /dev/null'

  flag=${flag:-'SILENT'}

  cmd_manager "$flag" "$cmd"
}


# Get all instances of a given git config with their scope
#
# @config: Given configuration to get the values of
# @scope:  Limit search to given scope
# @flag:   How to display (or not) the command used
# @output: Array to store the values at a given scope
# @scp:    Used to go through all scopes
#
# Returns:
# All values of the given config with their respective scopes
function get_all_git_config()
{
  local config="$1"
  local scope="$2"
  local flag="$3"
  local cmd='git config --get-all'
  local -A output
  local scp

  flag=${flag:-'SILENT'}

  # shellcheck disable=2119
  if ! is_inside_work_tree; then
    scope='global'
  fi

  for scp in {'global','local'}; do
    if [[ -z "$scope" || "$scope" == "$scp" ]]; then
      output["$scp"]="$(cmd_manager "$flag" "$cmd --$scp $config" | sed -E "s/^/$scp\t/g")"
    fi
  done

  printf '%s\n' "${output[@]}"
}

# Get all instances of a given git config with their scope
#
# @regexp: Given regular expression to find associated values
# @scope:  Limit search to given scope
# @flag:   How to display (or not) the command used
# @output: Array to store the values at a given scope
# @scp:    Used to go through all scopes
#
# Returns:
# All config values that match the given regular expression
function get_git_config_regex()
{
  local regexp="$1"
  local scope="$2"
  local flag="$3"
  local cmd='git config --get-regexp'
  local -A output
  local scp

  flag=${flag:-'SILENT'}

  # shellcheck disable=2119
  if ! is_inside_work_tree; then
    scope='global'
  fi

  for scp in {'global','local'}; do
    if [[ -z "$scope" || "$scope" == "$scp" ]]; then
      output["$scp"]="$(cmd_manager "$flag" "$cmd --$scp '$regexp'" | sed -E "s/^/$scp\t/g")"
    fi
  done

  printf '%s\n' "${output[@]}"
}


# This function checks if any of the arguments in @args is a valid commit
# reference
#
# @args: arguments to be processed
#
# Returns:
# 125 if nor inside git work tree;
# 0 if any of the arguments is a valid reference to a commit; 22 otherwise
function find_commit_references()
{
  local args="$*"
  local arg=''
  local parsed=''
  local commit_range=''

  [[ -z "$args" ]] && return 22 # EINVAL

  if ! is_inside_work_tree; then
    return 125 # ECANCELED
  fi

  #shellcheck disable=SC2086
  while read -r arg; do
    parsed="$(git rev-parse "$arg" 2> /dev/null)"
    while read -r rev; do
      # check if the argument is a valid reference to a commit-ish object
      if git rev-parse --verify --quiet --end-of-options "$rev^{commit}" > /dev/null; then
        commit_range+="$arg "
        continue 2
      fi
    done <<< "$parsed"
    parsed=''
  done <<< "$(git rev-parse -- $args 2> /dev/null)"

  if [[ -n "$commit_range" ]]; then
    printf '%s' "$(str_strip "$commit_range")"
    return 0
  fi

  return 22 # EINVAL
}

#From send_patch.sh 

#shellcheck disable=SC2119
function send_patch_main()
{
  local flag

  flag=${flag:-'SILENT'}

  if [[ "$1" =~ -h|--help ]]; then
    send_patch_help "$1"
    exit 0
  fi

  parse_mail_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    send_patch_help
    return 22 # EINVAL
  fi

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  if [[ -n "${options_values['SEND']}" ]]; then
    mail_send "$flag"
    return 0
  fi

  get_configs

  if [[ "${options_values['VERIFY']}" == 1 ]]; then
    mail_verify
    exit
  fi

  if [[ -n "${options_values['TEMPLATE']}" ]]; then
    template_setup
  fi

  is_inside_work_tree
  if [[ "$?" -gt 0 && "${options_values['SCOPE']}" != 'global' ]]; then
    complain 'Not in a git repository, aborting setup!'
    say 'To apply settings globally rerun with "--global" flag.'
    exit 22 # EINVAL
  fi

  if [[ -n "${options_values['INTERACTIVE']}" ]]; then
    interactive_setup "$flag"
    exit
  fi

  if [[ "${options_values['SETUP']}" == 1 ]]; then
    mail_setup "$flag"
    exit
  fi

  return 0
}

# This function prepares the appropriate options to send patches using
# `git send-email`.
#
# @flag: Flag to control the behavior of 'cmd_manager'
#
# Return:
# returns 0 if successful, non-zero otherwise
function mail_send()
{
  local flag="$1"
  local opts="${send_patch_config[send_opts]}"
  local to_recipients="${options_values['TO']}"
  local cc_recipients="${options_values['CC']}"
  local dryrun="${options_values['SIMULATE']}"
  local commit_range="${options_values['COMMIT_RANGE']}"
  local version="${options_values['PATCH_VERSION']}"
  local extra_opts="${options_values['PASS_OPTION_TO_SEND_EMAIL']}"
  local private="${options_values['PRIVATE']}"
  local rfc="${options_values['RFC']}"
  local kernel_root
  local patch_count=0
  local cmd='git send-email'

  flag=${flag:-'SILENT'}

  [[ -n "$dryrun" ]] && cmd+=" $dryrun"

  if [[ -n "$to_recipients" ]]; then
    validate_email_list "$to_recipients" || exit_msg 'Please review your `--to` list.'
    cmd+=" --to=\"$to_recipients\""
  fi

  if [[ -n "$cc_recipients" ]]; then
    validate_email_list "$cc_recipients" || exit_msg 'Please review your `--cc` list.'
    cmd+=" --cc=\"$cc_recipients\""
  fi

  # Don't generate a cover letter when sending only one patch
  patch_count="$(pre_generate_patches "$commit_range" "$version")"
  if [[ "$patch_count" -eq 1 ]]; then
    opts="$(sed 's/--cover-letter//g' <<< "$opts")"
  fi

  kernel_root="$(find_kernel_root "$PWD")"
  # if inside a kernel repo use get_maintainer to populate recipients
  if [[ -z "$private" && -n "$kernel_root" ]]; then
    generate_kernel_recipients "$kernel_root"
    cmd+=" --to-cmd='bash ${KW_PLUGINS_DIR}/kw_mail/to_cc_cmd.sh ${KW_CACHE_DIR} to'"
    cmd+=" --cc-cmd='bash ${KW_PLUGINS_DIR}/kw_mail/to_cc_cmd.sh ${KW_CACHE_DIR} cc'"
  fi

  [[ -n "$opts" ]] && cmd+=" $opts"
  [[ -n "$private" ]] && cmd+=" $private"
  [[ -n "$rfc" ]] && cmd+=" $rfc"
  [[ -n "$extra_opts" ]] && cmd+=" $extra_opts"

  cmd_manager "$flag" "$cmd"
}

# Validates the recipient list given by the user to the options `--to` and
# `--cc` to make sure the all the recipients are valid.
#
# @raw: The list of email recipients to be validated
#
# Return:
# 22 if there are invalid entries; 0 otherwise
function validate_email_list()
{
  local raw="$1"
  local -a list
  local value
  local error=0

  IFS=',' read -ra list <<< "$raw"

  for value in "${list[@]}"; do
    if [[ ! "$value" =~ ${email_regex} ]]; then
      warning -n 'The given recipient: '
      printf '%s' "$value"
      warning ' does not contain a valid e-mail.'
      error=1
    fi
  done

  [[ "$error" == 1 ]] && return 22 # EINVAL
  return 0
}

# This function generates the patches beforehand, these are used to count the
# number of patches and later to generate the appropriate recipients
#
# @commit_range: The list of revisions used to generate the patches
# @version:      The version of the patches
#
# Returns:
# The count of how many patches were created
function pre_generate_patches()
{
  local commit_range="$1"
  local version="$2"
  local patch_cache="${KW_CACHE_DIR}/patches"
  local count=0

  if [[ -d "$patch_cache" && ! "$patch_cache" =~ ^(~|/|"$HOME")$ ]]; then
    rm -rf "$patch_cache"
  fi
  mkdir -p "$patch_cache"

  cmd_manager 'SILENT' "git format-patch --quiet --output-directory $patch_cache $version $commit_range"

  for patch_path in "${patch_cache}/"*; do
    if is_a_patch "$patch_path"; then
      ((count++))
    fi
  done

  printf '%s\n' "$count"
}

# This function checks if any of the arguments in @args is a valid commit
# reference
#
# @args: arguments to be processed
#
# Returns:
# 125 if nor inside git work tree;
# 0 if any of the arguments is a valid reference to a commit; 22 otherwise
function find_commit_references()
{
  local args="$*"
  local arg=''
  local parsed=''
  local commit_range=''

  [[ -z "$args" ]] && return 22 # EINVAL

  if ! is_inside_work_tree; then
    return 125 # ECANCELED
  fi

  #shellcheck disable=SC2086
  while read -r arg; do
    parsed="$(git rev-parse "$arg" 2> /dev/null)"
    while read -r rev; do
      # check if the argument is a valid reference to a commit-ish object
      if git rev-parse --verify --quiet --end-of-options "$rev^{commit}" > /dev/null; then
        commit_range+="$arg "
        continue 2
      fi
    done <<< "$parsed"
    parsed=''
  done <<< "$(git rev-parse -- $args 2> /dev/null)"

  if [[ -n "$commit_range" ]]; then
    printf '%s' "$(str_strip "$commit_range")"
    return 0
  fi

  return 22 # EINVAL
}

