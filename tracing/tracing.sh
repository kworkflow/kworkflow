# This file contains library functions specific to adding tracing capabilities
# to kw. The functions defined here are to be called at installation time when
# running `setup.sh`.

# Injection of tracing code won't be attempted in files of this array.
declare -ga ignored_lib_files=(
  'src/bash_autocomplete.sh'
  'src/_kw'
  'src/VERSION'
)

# This function injects code that enables tracing into the main kw file and
# installs this altered version.
#
# @kw_path: Name/Path to main kw file. By default, we assume it resides in the
#   current dir
# @bin: Path of `bin` dir to install main kw file
# @tracing_code_excerpts_dir: Path do dir containg code excerpts to be injected
#   into kw main file
#
# Return:
# Returns 2 (ENOENT) if either `@kw_path` or `@bin` isn't a valid file/dir path,
# and 0, otherwise.
function sync_main_kw_file_with_tracing()
{
  local kw_path="$1"
  local bin="$2"
  local tracing_code_excerpts_dir="$3"
  local main_kw_file_with_tracing

  [[ ! -f "$kw_path" || ! -d "$bin" ]] && return 2 # ENOENT

  # Parse each line of base kw main file and inject the correspondent excerpt
  # when `line` is a guard that marks the injection point.
  while read -r line; do
    if [[ "$line" =~ ^[[:space:]]*#INJECT_CODE_TRACING_SETUP$ ]]; then
      main_kw_file_with_tracing+=$(< "${tracing_code_excerpts_dir}/tracing_setup")$'\n'
    elif [[ "$line" =~ ^[[:space:]]*#INJECT_CODE_TRACING_COMMIT$ ]]; then
      main_kw_file_with_tracing+=$(< "${tracing_code_excerpts_dir}/tracing_commit")$'\n'
    else
      main_kw_file_with_tracing+="$line"$'\n'
    fi
  done < "$kw_path"

  printf '%s' "$main_kw_file_with_tracing" > "${bin}/${kw_path}"
  chmod +x "${bin}/${kw_path}"
}

# This function injects code that enables tracing in every kw library file (files
# inside the `src` directory) and installs them. Files pertaining to Bash and Zsh
# completions (`src/bash_autocomplete.sh` and `src/_kw`), and the `src/VERSION`
# aren't injected.
#
# @input_dir: Path to directory where base library files are stored
# @output_dir: Path to directory where altered files with tracing will be installed
function sync_kw_lib_files_with_tracing()
{
  local input_dir="$1"
  local output_dir="$2"
  local file_with_tracing
  local parent_directory
  local all_filepaths
  local tmp_dir_path

  tmp_dir_path=$(mktemp --directory)

  all_filepaths=$(find "$input_dir" -type f)

  while IFS=$'\n' read -r filepath; do
    # We shouldn't try to inject code in the completions files nor the `VERSION` file
    # shellcheck disable=SC2076
    if [[ "${ignored_lib_files[*]}" =~ "$filepath" ]]; then
      cp "$filepath" "${tmp_dir_path}/$(basename "$filepath")"
    else
      file_with_tracing=$(inject_lib_file_with_tracing "$filepath")
      # Removing 'src/' from the filepath
      filepath=$(printf '%s' "$filepath" | cut --delimiter='/' -f2-)
      # In case the file is in a sub-directory of `src`, create it
      parent_directory="${filepath%/*}"
      if [[ ! "$parent_directory" =~ \.sh$ ]]; then
        mkdir --parents "${tmp_dir_path}/${parent_directory}"
      fi
      # Save altered file in temporary directory
      printf '%s' "$file_with_tracing" > "${tmp_dir_path}/${filepath}"
    fi
  done <<< "$all_filepaths"

  # Commit the synchronization of altered files
  rsync --quiet --recursive "${tmp_dir_path}/" "${output_dir}"
}

# This function reads a kw library file, injects it with code that logs the execution
# for tracing and outputs this altered file.
#
# @filepath: Path of file to be altered
#
# Return:
# Outputs the file in `@filepath` injected with code that enables tracing.
function inject_lib_file_with_tracing()
{
  local filepath="$1"
  local file_with_tracing
  local inside_function
  local function_name

  filepath=$(realpath "$filepath")

  while read -r line; do
    # Start of a function declaration and definition
    if [[ "$line" =~ ^function[[:space:]].+\(\)$ ]]; then
      inside_function=1
      function_name=$(printf '%s' "$line" | cut --delimiter=' ' -f2 | sed -e 's/()//')
      file_with_tracing+="$line"$'\n'
      file_with_tracing+='{'$'\n'
      file_with_tracing+="$(get_tracing_log_line 'entry' "$function_name")"$'\n'
      read -r line
    else
      file_with_tracing+="$line"$'\n'
    fi

    while [[ -n "$inside_function" ]]; do
      read -r line

      # Convert multi-line commands into single line to avoid wrong parsing of
      # background executions.
      while [[ "$line" =~ [[:space:]]\\$ ]]; do
        line="${line::-1}"
        read -r line_append
        line+="$line_append"
      done

      file_with_tracing+=$(process_function_line "$line" "$function_name")$'\n'
      [[ "$line" == '}' ]] && inside_function=''
    done
  done < "$filepath"

  printf '%s' "$file_with_tracing"
}

# This function processes a line from inside a function definition and alters it,
# if necessary, to enable tracing in that function. There are two types of
# alterations that this function does:
#   1. For a line that represents an/a exit/return point of the function, add code
#      that logs that action when evaluated.
#   2. For a line that launches a background execution, add code that assigns the
#      correct `THREAD_NUMBER` value for each thread.
#
# @line: Line to be processed
# @function_name: Name of the function that `@line` belongs
#
# Return:
# Outputs the result of processing `@line`.
function process_function_line()
{
  local line="$1"
  local function_name="$2"
  local and_return_statement
  local and_exit_statement
  local processed_line

  and_return_statement='&& return'
  and_exit_statement='&& exit'

  # End of function definition
  if [[ "$line" == '}' ]]; then
    processed_line+='local _return_val="$?"'$'\n'
    processed_line+="$(get_tracing_log_line 'return' "$function_name")"$'\n'
    processed_line+='return "$_return_val"'$'\n'
    processed_line+='}'$'\n'
  # Process single-line return statement
  elif [[ "$line" =~ ^[[:space:]]*return ]]; then
    processed_line+="$(get_tracing_log_line 'return' "$function_name")"$'\n'
    processed_line+="$line"$'\n'
  # Process statement with '&& return'
  elif [[ "$line" =~ \&\&[[:space:]]return ]]; then
    processed_line+="${line%"$and_return_statement"*}&& "
    processed_line+="$(get_tracing_log_line 'return' "$function_name") "
    processed_line+="${and_return_statement}${line#*"$and_return_statement"}"$'\n'
  # Process single-line exit statement
  elif [[ "$line" =~ ^[[:space:]]*exit ]]; then
    processed_line+="$(get_tracing_log_line 'exit' "$function_name")"$'\n'
    processed_line+="$line"$'\n'
  # Process statements with '&& exit'
  elif [[ "$line" =~ \&\&[[:space:]]exit ]]; then
    processed_line+="${line%"$and_exit_statement"*}&& "
    processed_line+="$(get_tracing_log_line 'exit' "$function_name") "
    processed_line+="${and_exit_statement}${line#*"$and_exit_statement"}"$'\n'
  # Process background execution
  elif [[ "$line" =~ [^\&\;]\&$ ]]; then
    processed_line+="THREAD_NUMBER=\$((++TOTAL_NUMBER_OF_THREADS))"$'\n'
    processed_line+="$line"$'\n'
    processed_line+="THREAD_NUMBER=0"$'\n'
  # Only copy the line
  else
    processed_line+="$line"$'\n'
  fi

  printf '%s' "$processed_line"
}

# This function outputs an expression that logs a tracing event when it gets
# evaluated. A tracing event can be either entering (entry) or returning (return)
# into/from a function, or exiting (exit) the execution. When evaluated, the
# outputted expression adds a CSV line to the current thread tracing file with
# the format:
#
#   <tracing_event>,<function_name>,<timestamp>
#
# @tracing_event: String that represent the entry/return of a function, or the
#   exit of the execution
# @function_name: Name of the function of tracing event
#
# Return:
# Outputs an expression ready to be evaluated.
function get_tracing_log_line()
{
  local tracing_event="$1"
  local function_name="$2"
  local expression

  expression="printf '${tracing_event},${function_name},%s\n' "
  expression+='"$(date '+%s%N')" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"'
  printf '%s' "$expression"
}
