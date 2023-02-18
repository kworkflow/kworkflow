include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"

# Hash containing user options
declare -gA diff_options

function diff_manager()
{
  local files_paths=${*: -2}
  local interactive
  local target_1
  local target_2

  IFS=' ' read -r -a files <<< "$files_paths"
  for file in "${files[@]}"; do
    if [[ "$file" =~ -h|--help ]]; then
      diff_help "$file"
      return 0
    fi

    if [[ ! -e "$file" ]]; then
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
    diff_help "$@"
    return 0
  fi

  interactive="${diff_options['INTERACTIVE']}"
  test_mode="${diff_options['TEST_MODE']}"

  if [[ "$test_mode" == 'TEST_MODE' ]]; then
    printf '%s\n' "$target_1 $target_2 $interactive"
    return 0
  fi

  if [[ -d "$target_1" && -d "$target_2" ]]; then
    diff_folders "$target_1" "$target_2"
    return "$?"
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
  local raw_options="$*"

  diff_options['INTERACTIVE']=1
  diff_options['HELP']=0

  IFS=' ' read -r -a options <<< "$raw_options"
  for option in "${options[@]}"; do
    case "$option" in
      --no-interactive)
        diff_options['INTERACTIVE']=0
        continue
        ;;
      --help | -h)
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

# Show the diff result between folders in two columns equally divided.
#
# @folder_1 Path to the first folder
# @folder_2 Path to the second folder
# @flag How to display a command, see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# In case of success, return 0, otherwise, return 22.
function diff_folders()
{
  local folder_1="$1"
  local folder_2="$2"
  local flag="$3"
  local diff_cmd
  local columns

  diff_cmd='diff --color=always --recursive --brief'
  flag=${flag:-'SILENT'}

  diff_cmd="${diff_cmd} ${folder_1} ${folder_2} | grep ${folder_1}"

  if [[ ! -d "$folder_1" || ! -d "$folder_2" ]]; then
    complain "Make sure that ${folder_1} and ${folder_2} are valid folders"
    return 22 # EINVAL
  fi

  cmd_manager "$flag" "$diff_cmd"
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
  local diff_cmd
  local columns

  # In case TERM is gibberish tput won't work properly
  # specify dummy terminal option to manage that
  [[ "$TERM" == '' || "$TERM" == 'dumb' ]] && TPUTTERM=' -T xterm-256color'
  columns=$(eval tput"${TPUTTERM}" cols)
  diff_cmd="diff -y --color=always --width=$columns"
  flag=${flag:-''}

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
  if [[ "$*" =~ --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'diff'
    return
  fi
  printf '%s\n' 'kw diff:' \
    '  diff <file1> <file2>                  - interactive diff' \
    '  diff --no-interactive <file1> <file2> - static diff'
}
