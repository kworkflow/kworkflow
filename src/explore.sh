# This file is the core of the explore feature. The idea behind the explore
# command it unifies the way that we search for things in the project, by
# things, you can understand from files to messages in git log.

. "$KW_LIB_DIR/kwio.sh" --source-only
. "$KW_LIB_DIR/kwlib.sh" --source-only

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
    2) # Use GNU GREP
      shift 1 # Remove 'grep' string
      explore_files_gnu_grep "$@"
    ;;
    3) # Search in directories controlled or not by git
      shift 1
      explore_all_files_git "$@"
    ;;
    4) # Search in files under git control
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
#   2 if --grep is passed
#   3 if --all is passed
#   4 for something different from --log or --grep
#   22 for invalid operation
function explore_parser()
{
  local option="$1"

  if [[ "$#" -eq 0 ]]; then
    complain "Expected string or parameter. See man for detail."
    exit 22 # EINVAL
  fi

  if [[ -z "$2" ]]; then
    return 4
  fi

  case "$option" in
    --log|-l)
      return 1
    ;;
    --grep|-g)
      return 2
    ;;
    --all|-a)
      return 3
    ;;
    *)
      return 4
    ;;
  esac
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

# This function searches string in files under git control.
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

# This function uses git grep tool to search string in files under or not git
# control. This only covers files into .git if the user runs the command
# inside the directory
#
# @regex Specifies the regex that we want to search in the files
# @path Narrow down the search
# @flag How to display a command, the default value is "SILENT". For more
#       options see `src/kwlib.sh` function `cmd_manager`
function explore_all_files_git()
{
  local regex="$1"
  local path="$2"
  local flag="$3"

  # Silent by default
  flag=${flag:-"SILENT"}

  # If user only set regex value
  path=${path:-"."}

  cmd_manager "$flag" "git grep --no-index -e \"$regex\" -nI $path"
}

# This function allows the use of gnu grep utility to manages the search for
# regex regardless if the files is or not under git control.
#
# @regex Specifies the regex that we want to search in the files
# @path Narrow down the search
# @flag How to display a command, the default value is "SILENT". For more
#       options see `src/kwlib.sh` function `cmd_manager`
function explore_files_gnu_grep()
{
  local regex="$1"
  local path="$2"
  local flag="$3"

  # Silent by default
  flag=${flag:-"SILENT"}

  # If user only set regex value
  path=${path:-"."}

  cmd_manager "$flag" "grep --color -nrI $path -e \"$regex\""
}
