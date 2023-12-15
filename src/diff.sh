#!/bin/bash
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kwio.sh"

declare -gA options_values

function diff_main()
{
  local target_a="$1"
  local target_b="$2"
  local flag

  flag=${flag:-'SILENT'}

  IFS=' ' read -r -a files <<< "${target_a} ${target_b}"
  for file in "${files[@]}"; do
    if [[ "$file" =~ -h|--help ]]; then
      diff_help "$file"
      return 0
    fi

    if [[ ! -e "$file" ]]; then
      complain "Invalid path: ${file}"
      diff_help
      return 2 # ENOENT
    fi
  done

  parse_diff_options "$@"
  if [[ $? -gt 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    diff_help
    exit 22 # EINVAL
  fi

  interactive="${options_values['INTERACTIVE']}"
  test_mode="${options_values['TEST_MODE']}"

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  if [[ "$test_mode" == 'TEST_MODE' ]]; then
    printf '%s %s %s\n' "$target_a" "$target_b" "$interactive"
    return 0
  fi

  if [[ -d "$target_a" && -d "$target_b" ]]; then
    diff_folders "$target_a" "$target_b" "$flag"
    return "$?"
  fi

  diff_side_by_side "$target_a" "$target_b" "$interactive" "$flag"
}

# Show the diff result between folders in two columns equally divided.
#
# @folder_1 Path to the first folder
# @folder_2 Path to the second folder
# @flag How to display a command, see `src/lib/kwlib.sh` function `cmd_manager`
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
# @flag How to display a command, see `src/lib/kwlib.sh` function `cmd_manager`
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
  diff_cmd="diff -y --color=always --width=${columns}"
  flag=${flag:-'SILENT'}

  if [[ ! -f "$file_1" || ! -f "$file_2" ]]; then
    diff_help
    return 22 # EINVAL
  fi

  diff_cmd="$diff_cmd $file_1 $file_2"
  if [[ "$interactive" == 1 ]]; then
    diff_cmd="${diff_cmd} | less --RAW-CONTROL-CHARS"
  fi

  cmd_manager "$flag" "$diff_cmd"
}

# This function gets raw data and based on that fill out the options values to
# be used in another function.
#
# Return:
# In case of successful return 0, otherwise, return 22.
function parse_diff_options()
{
  local long_options='help,no-interactive,verbose'
  local short_options='h'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw diff' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['INTERACTIVE']=1
  options_values['VERBOSE']=''
  options_values['TEST_MODE']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help | -h)
        diff_help "$1"
        exit
        ;;
      --no-interactive)
        options_values['INTERACTIVE']=0
        shift
        ;;
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      test_mode)
        options_values['TEST_MODE']='TEST_MODE'
        shift
        ;;
      --)
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
}

function diff_help()
{
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'diff'
    return
  fi

  printf '%s\n' 'kw diff:' \
    '  diff <file1> <file2>                  - interactive diff' \
    '  diff <file1> <file2> --no-interactive - static diff' \
    '  diff <file1> <file2> --verbose - show a detailed output'
}
