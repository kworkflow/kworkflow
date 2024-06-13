# Checkpatch is a useful tool provided by Linux, and the main goal of the code
# in this file is to handle this script in a way to make this tool easier for
# users.

include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

declare -gA options_values

# Runs checkpatch in the given path, which might be a file or directory.
#
# @FILE_OR_DIR_CHECK Target path for running checkpatch script
function codestyle_main()
{
  local path
  local flag
  local checkpatch_options="${configurations[checkpatch_opts]}"
  local -r original_working_dir="$PWD"
  local kernel_root
  local checkpatch
  local cmd_script

  parse_codestyle_options "$@"
  if [[ "$?" != 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  flag=${options_values['TEST_MODE']}
  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  flag=${flag:-'SILENT'}
  # TODO: Note that codespell file is not specified yet because of the poluted
  # output. It could be nice if we can add another option just for this sort
  # of check.

  path="${options_values['PATH']}"
  path=${path:-'.'}
  if [[ ! -d "$path" && ! -f "$path" ]]; then
    complain "Invalid path: ${path}"
    return 2 # ENOENT
  fi

  # Get realpath for using inside checkpatch
  path="$(realpath "$path")"

  # Try to find kernel root at given path
  kernel_root="$(find_kernel_root "$path")"
  if [[ -z "$kernel_root" ]]; then
    # Fallback: try to find kernel root at working path
    kernel_root="$(find_kernel_root "$original_working_dir")"
  fi

  # Check if kernel root was found
  if [[ -z "$kernel_root" ]]; then
    complain 'Neither the given path nor the working path is in a kernel tree.'
    return 22 # EINVAL
  fi

  # Build a list of file to apply check patch
  FLIST=$(find "$path" -type f ! -name '*\.mod\.c' | grep "\.[ch]$")

  say "Running checkpatch.pl on: ${path}"
  say "$SEPARATOR"

  # Define different rules for patch and files
  if is_a_patch "$path"; then
    FLIST="$path"
  else
    checkpatch_options="--terse ${checkpatch_options} --file"
  fi

  checkpatch=$(join_path "$kernel_root" 'scripts/checkpatch.pl')
  cmd_script="perl ${checkpatch} ${checkpatch_options}"

  [[ -n "${options_values['START_LINE']}" ]] && start_line=${options_values['START_LINE']}
  [[ -n "${options_values['END_LINE']}" ]] && end_line=${options_values['END_LINE']}

  [[ -n "${options_values['FUNCTION']}" ]] && function=${options_values['FUNCTION']}

  if [[ -n "$start_line" || -n "$end_line" ]]; then
    range_option_flag='true'
  fi

  # Check if --start-line --end-line and --function options are being used with a single file
  if [[ ! -f "$path" && -n "$range_option_flag" && -n "$function" ]]; then
    complain "Invalid path using start-line and end-line option: ${path}"
    return 2 # ENOENT
  fi

  # When no --start-line is specified, assign the first line of the file to start_line
  if [[ -n "$range_option_flag" && -z "$start_line" ]]; then
    start_line=1
  fi

  # When no --end-line is specified, assign the last line of the file to end_line
  if [[ -n "$range_option_flag" && -z "$end_line" ]]; then
    end_line=$(wc -l < "$FLIST")
  fi

  # For --function option, find the start line of the function definition
  # and assign it to start_line.
  if [[ -n "$function" ]]; then
    start_line=$(awk "/[a-zA-Z]+[[:space:]]+${function}[[:space:]]*\\(.*[^;]$/ {print FNR}" "$FLIST")
  fi

  # If --start-line, --end-line or --function options are being used, assign a temporary file
  # to FLIST with blank lines and SPDX License Identifier
  if [[ -n "$range_option_flag" || -n "$function" ]]; then
    suffix=".${FLIST#*.}"
    temp_file=$(mktemp --suffix "$suffix" --tmpdir="$PWD")

    if [[ "$start_line" != '1' ]]; then
      printf '%s\n' '// SPDX-License-Identifier: TEMPFILE' > "$temp_file"
      ((blank_lines = start_line - 2))
      yes '' | head -n "$blank_lines" >> "$temp_file"
    fi
  fi

  # For --start-line and --end-line options, write the line interval to the temporary file
  # and assign it to FLIST
  if [[ -n "$range_option_flag" ]]; then
    sed -n "${start_line},${end_line}p" "$FLIST" >> "$temp_file"
    FLIST="$temp_file"
  fi

  # For --function option, write the function definition to the temporary file
  # and assign it to FLIST
  if [[ -n "$function" ]]; then
    awk '
      $0 ~ "[a-zA-Z]+[[:space:]]+"FUNCTION_NAME"[[:space:]]*\\(.*[^;]$" {
        in_function_header = 1
      }
      in_function_header {
        if ($0 ~ /{/) {
          in_function_header = 0
          in_function = 1
        }
        if (!in_function) print
      }
      in_function {
        if (!in_function_header) print
        if ($0 ~ /{/) open_braces++
        if ($0 ~ /}/) open_braces--
        if (open_braces == 0) exit
      }
    ' FUNCTION_NAME="$function" "$FLIST" >> "$temp_file"
    FLIST="$temp_file"
  fi

  for current_file in $FLIST; do
    file="$current_file"

    if [[ ! -e "$file" ]]; then
      printf '%s\n' "$file does not exist."
      continue
    fi

    cmd_manager "$flag" "$cmd_script $file"
    [[ "$?" != 0 ]] && say "$SEPARATOR"
  done

  if [[ -n "$range_option_flag" || -n "$function" ]]; then
    rm "$temp_file"
  fi
}

# This function gets raw data and based on that fill out the options values to
# be used in another function.
#
# Return:
# In case of successful return 0, otherwise, return 22.
function parse_codestyle_options()
{
  local long_options='verbose,help,start-line:,end-line:,function:'
  local short_options='h'
  local options

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw diff' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['VERBOSE']=''
  options_values['TEST_MODE']=''
  options_values['START_LINE']=''
  options_values['END_LINE']=''
  options_values['FUNCTION']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      --start-line)
        options_values['START_LINE']="$2"
        shift 2
        ;;
      --end-line)
        options_values['END_LINE']="$2"
        shift 2
        ;;
      --function)
        options_values['FUNCTION']="$2"
        shift 2
        ;;
      TEST_MODE)
        options_values['TEST_MODE']='TEST_MODE'
        shift
        ;;
      --help | -h)
        codestyle_help "$1"
        exit
        ;;
      --)
        shift
        ;;
      *)
        options_values['PATH']="$1"
        shift
        ;;
    esac
  done
}

function codestyle_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'codestyle'
    return
  fi
  printf '%s\n' 'kw codestyle:' \
    '  codestyle [<dir>|<file>|<patch>] - Use checkpatch on target' \
    '  codestyle (--verbose) [<dir>|<file>|<patch>] - Show detailed output' \
    '  codestyle (--start-line <line>) - Set line where the script will start checkpatch' \
    '  codestyle (--end-line <line>) - Set line where the script will end checkpatch' \
    '  codestyle (--function <function-name>) - Define function to apply checkpatch'
}

load_kworkflow_config
