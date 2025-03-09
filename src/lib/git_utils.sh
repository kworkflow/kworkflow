# Git Utils Library
#
# This library consolidates common Git-related operations into a single file.
# Its primary goal is to centralize Git commands used within the KW repository,
# allowing for standardized behavior and easier maintenance.

include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/lib/kw_config_loader.sh"

# Functions from kwlib.sh

# Checks if the command is being run inside a git work-tree
#
# @flag: How to display (or not) the command used
#
# Returns:
# 0 if is inside a git work-tree root and 128 otherwise.
function git_is_inside_work_tree()
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
function git_get_all_git_config()
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
function git_get_git_config_regex()
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

# This function gets the local branches of a given git repository. The data is transmitted
# using an associative array reference passed as argument. Each key-value pair of the
# array is like:
#  `array_reference[<name_of_branch>]='<HEAD_commit_subject>'`
#
# @git_repository_path: Path to a git repository
# @_branches: Associative array reference where data will be trasmitted
# @flag Flag to control function output
#
# Return:
# Returns data regarding the repository branches through the array reference passed as
# argument.
function git_get_git_repository_branches()
{
  local git_repository_path="$1"
  local -n _branches="$2"
  local flag="$3"
  local output
  local branch
  local branch_metadata

  flag=${flag:-'SILENT'}

  output=$(cmd_manager "$flag" "git -C ${git_repository_path} branch --verbose")
  # Clean output by removing asterisks and withespaces in the beginning of each line
  output=$(printf '%s' "$output" | sed 's/\*//g')
  output=$(printf '%s' "$output" | sed 's/^[ \t]*//g')

  # Resetting associative array reference to prevent false branches
  _branches=()

  while IFS=$'\n' read -r line; do
    # Format of "$line": '<branch_name><whitespaces><HEAD_commit_SHA> <HEAD_commit_subject>'
    branch=$(printf '%s' "$line" | cut --delimiter=' ' -f1)
    # Below we are: 1) cutting the branch name; 2) removing any whitespace in the beginning; 3) cutting the commit SHA
    branch_metadata=$(printf '%s' "$line" | cut --delimiter=' ' -f2- | sed 's/^[ \t]*//' | cut --delimiter=' ' -f2-)
    _branches["$branch"]="$branch_metadata"
  done <<< "$output"
}


#From send_patch.sh 

# This function checks if any of the arguments in @args is a valid commit
# reference
#
# @args: arguments to be processed
#
# Returns:
# 125 if nor inside git work tree;
# 0 if any of the arguments is a valid reference to a commit; 22 otherwise
function git_find_commit_references()
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

function git_add_config()
{
  local option="$1"
  local value="${2:-${options_values["$option"]}}"
  local cmd_scope="${3:-${options_values['CMD_SCOPE']}}"
  local flag="$4"
  local cmd

  flag=${flag:-'SILENT'}

  cmd="git config --$cmd_scope $option '$value'"

  cmd_manager "$flag" "$cmd"
}

