. $src_script_path/kwio.sh --source-only
. $src_script_path/kwlib.sh --source-only

# Hash containing user options
declare -A diff_options

function diff_manager()
{
  local files_paths=${@: -2}
  local interactive
  local target_1
  local target_2

  IFS=' ' read -r -a files <<< "$files_paths"
  for file in "${files[@]}"; do
    if [[ '--help' == "$file" || '-h' == "$file" ]]; then
      diff_help
      return 0
    fi

    if [[ ! -f "$file" ]]; then
      complain "Invalid path: $file"
      diff_help
      return 2 # ENOENT
    fi
  done

  target_1="${files[0]}"
  target_2="${files[1]}"

  # Drop files
  set -- "${@:1:$#-2}"

  diff_parser_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${diff_options['ERROR']}"
    return 22
  fi

  if [[ "${diff_options['HELP']}" == 1 ]]; then
    diff_help
    return 0
  fi

  interactive="${diff_options['INTERACTIVE']}"
  test_mode="${diff_options['TEST_MODE']}"

  if [[ "$test_mode" == "TEST_MODE" ]]; then
    echo "$target_1 $target_2 $interactive"
    return 0
  fi

  diff_side_by_side "$target_1" "$target_2" "$interactive"
}

# This function gets raw data and based on that fill out the options values to
# be used in another function.
#
# @raw_options String with all user options
#
# Return:
# In case of successful return 0, otherwise, return 22.
function diff_parser_options()
{
  local raw_options="$@"

  diff_options["INTERACTIVE"]=1
  diff_options["HELP"]=0

  IFS=' ' read -r -a options <<< "$raw_options"
  for option in "${options[@]}"; do
      case "$option" in
        --no-interactive)
          diff_options['INTERACTIVE']=0
          continue
        ;;
        --help|-h|help)
          diff_options['HELP']=1
          continue
        ;;
        test_mode)
          diff_options['TEST_MODE']='TEST_MODE'
        ;;
        *)
          diff_options['ERROR']="$option"
          return 22
          ;;
      esac
  done

}

# Show the diff result in two columns equally divided.
#
# @file_1 Path to the first file
# @file_2 Path to the second file
# @interactive If set to 1, it interactively displays the diff, otherwise, it
#              just prints all diff at once.
# @flag How to display a command, see `src/kwlib.sh` function `cmd_manager`
function diff_side_by_side()
{
  local file_1="$1"
  local file_2="$2"
  local interactive="$3"
  local flag="$4"
  local columns=$(tput cols)
  local diff_cmd="diff -y --color=always --width=$columns"

  flag=${flag:-""}

  if [[ ! -f "$file_1" || ! -f "$file_2" ]]; then
    complain "Make sure that $file_1 and $file_2 are a valid files"
    return 22 # EINVAL
  fi

  diff_cmd="$diff_cmd $file_1 $file_2"
  if [[ "$interactive" == 1 ]]; then
    diff_cmd="$diff_cmd | less -R"
  fi

  cmd_manager "$flag" "$diff_cmd"
}

function diff_help()
{
  echo -e "Usage: kw diff [options] FILES:\n" \
    "\tdiff FILE1 FILE2"
    "\tdiff --no-interactive FILE1 FILE2"
}
