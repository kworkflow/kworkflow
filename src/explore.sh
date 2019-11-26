# This file is the core of the explore feature. The idea behind the explore
# command it unifies the way that we search for things in the project, by
# things, you can understand from files to messages in git log.

. $src_script_path/kwio.sh --source-only
. $src_script_path/kwlib.sh --source-only

# The main entry point for the explore feature, if you want to add another
# search mechanism, you probably wish to start by this function
function explore()
{
  local ret

  explore_parser "$@"
  ret="$?"

  case "$ret" in
    1) # LOG
      shift 1 # Remove 'log' string
      explore_git_log "$@"
    ;;
    2) # Search in a git repository
      explore_files_under_git "$@"
    ;;
    *)
      complain "Invalid parameter"
      exit 22 # EINVAL
    ;;
  esac
}

# Tiny parameter parser, we try to keep this function isolate for making easy
# to expand the explore options.
#
# Returns:
# This function returns the following values:
#   1 if --log is passed
#   2 for something different from --log
#   22 for invalid operation
function explore_parser()
{
  if [[ "$#" -eq 0 ]]; then
    complain "Expected string or 'log'"
    exit 22 # EINVAL
  fi

  if [[ "$1" =~ ^--log$ ]]; then
    return 1
  fi

  return 2
}

# This function is responsible for handling the search in the log history.
#
# @search_string A string that we want to find a match in the git log
# @path This is an optional parameter for narrow down git log search
# @flag How to display a command, the default value is "SILENT". For more
#       options see `src/kwlib.sh` function `cmd_manager`
function explore_git_log()
{
  local search_string="$1"
  local path="$2"
  local flag="$3"

  flag=${flag:-"SILENT"}
  path=${path:-""}

  cmd_manager "$flag" "git log --grep=\"$search_string\" $path"
}

# This function manages the search inside files and under the git repository
# control.
#
# @regex Specifies the regex that we want to search in the files
# @path Narrow down the search
# @flag How to display a command, the default value is "SILENT". For more
#       options see `src/kwlib.sh` function `cmd_manager`
function explore_files_under_git()
{
  local regex="$1"
  local path="$2"
  local flag="$3"

  # Silent by default
  flag=${flag:-"SILENT"}

  # If user only set regex value
  path=${path:-"."}

  cmd_manager "$flag" "git grep -e \"$regex\" -nI $path"
}
