include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"

declare -gA options_values

# Executes get_maintainer with the given file or dir
#
# @raw_options String with all user options
#
# Returns:
# False uppon error and true otherwise.
#
# This function also handle the cases where:
# - The working dir and/or given path is not the root of a linux kernel repo
# - The working dir and/or given path is not inside a linux kernel repo
# - Option --authors/-a is given. It will print the name of the module's
#   authors
# - Option --update-patch/-u is given. It will include a "To:" field in
#   the header of the patch with the contact of the maintainers associated
#   with that patch
# - Options --update-patch/-u is given and a field "To:" is already
#   present in the patch
function maintainers_main()
{
  local raw_options="$*"
  local FILE_OR_DIR
  local print_authors=false
  local update_patch=false
  local is_file_a_patch=true
  local is_file_inside_kernel_tree=true
  local script_output
  local flag

  local -r script='scripts/get_maintainer.pl'
  local script_options="${configurations[get_maintainer_opts]}"

  local -r original_working_dir=$PWD
  local kernel_root=''

  flag=${flag:-'SILENT'}

  if [[ "$1" =~ -h|--help ]]; then
    maintainers_help "$1"
    exit 0
  fi

  parse_maintainers_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  FILE_OR_DIR=${options_values['FILE_OR_DIR']}
  print_authors=${options_values['PRINT_AUTHORS']}
  update_patch=${options_values['UPDATE_PATCH']}

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  # Check if is a valid path
  if [[ ! -d "$FILE_OR_DIR" && ! -f "$FILE_OR_DIR" ]]; then
    complain 'Invalid path'
    return 1 # EPERM
  fi

  FILE_OR_DIR="$(realpath "${FILE_OR_DIR}")"

  # if given path is not a patchfile, add -f to get_maintainer.pl options
  if ! is_a_patch "$FILE_OR_DIR"; then
    if [[ -n "$update_patch" ]]; then
      complain 'Option --update-patch was passed but given path is not a patch.'
      return 1 # EPERM
    fi
    is_file_a_patch=false
    script_options="${script_options} -f"
  fi

  # try to find kernel root at given path
  kernel_root="$(find_kernel_root "${FILE_OR_DIR}")"
  if [[ -z "$kernel_root" ]]; then
    is_file_inside_kernel_tree=false
    # fallback: try to find kernel root at working path
    kernel_root="$(find_kernel_root "$original_working_dir")"
  fi

  # Check if kernel root was found.
  if [[ -z "$kernel_root" ]]; then
    complain 'Neither the given path nor the working path is in a kernel tree.'
    return 1 # EPERM
  fi

  # If file is not a patch and outside a kernel tree, it must be an user's
  # mistake. Although get_maintainer.pl can handle this, it's better to abort
  # because it is most likely a user's mistake. So better let the user know.
  if ! "$is_file_a_patch" && ! "$is_file_inside_kernel_tree"; then
    complain 'The given file is not a patch and is outside a kernel tree.'
    return 1 # EPERM
  fi

  cmd_manager "$flag" "cd ${kernel_root}"
  if [[ "$?" != 0 ]]; then
    exit_msg 'It was not possible to move to kernel root dir'
    return 2 # ENOENT
  fi

  script_output="$(eval perl "$script" "$script_options" "$FILE_OR_DIR")"

  cmd_manager "$flag" "cd ${original_working_dir}"
  if [[ "$?" != 0 ]]; then
    exit_msg 'It was not possible to move back from kernel dir'
    return 2 # ENOENT
  fi

  say "$SEPARATOR"
  if [[ -n "$update_patch" ]]; then
    script_output_copy="${script_output//(/\\(}"
    # Check if "To:" field is already present
    cmd_manager "$flag" "grep --quiet --extended-regexp '^To:.*${script_output_copy}' ${FILE_OR_DIR}"
    if [[ "$?" == 0 ]]; then
      say "Maintainers already in 'To:' field of $(basename "${FILE_OR_DIR}")"
      return 0
    fi

    cmd_manager "$flag" "grep --quiet --extended-regexp '^To: ' ${FILE_OR_DIR}"
    if [[ "$?" == 0 ]]; then
      cmd_manager "$flag" "sed --regexp-extended --in-place 's/(^To:.*)/\1, ${script_output_copy}/' ${FILE_OR_DIR}"
    else
      cmd_manager "$flag" "sed --regexp-extended --in-place 's/(^Subject:.*)/To: ${script_output_copy}\n\1/' ${FILE_OR_DIR}"
    fi

    say "Patch $(basename "${FILE_OR_DIR}") updated with the following maintainers:"
  else
    say 'HERE:'
  fi
  printf '%s\n' "$script_output"

  if [[ -n "$print_authors" ]]; then
    print_files_authors "$FILE_OR_DIR"
  fi
}

# Prints the authors of a given file or files inside a given dir.
#
# @FILE_OR_DIR The file or directory path for which authors should be printed.
# If FILE_OR_DIR is a directory, it will process all files within the directory.
# If FILE_OR_DIR is a file, it will process only that specific file.
function print_files_authors()
{
  local FILE_OR_DIR="$1"
  local files=()
  if [[ -d "$FILE_OR_DIR" ]]; then
    for file in "$FILE_OR_DIR"/*; do
      if [[ -f "$file" ]]; then
        files+=("$file")
      fi
    done
  elif [[ -f "$FILE_OR_DIR" ]]; then
    files+=("$FILE_OR_DIR")
  fi

  local printed_authors_separator=false

  for file in "${files[@]}"; do
    # Match everything inside the parenthesis of `MODULE_AUTHOR (<match>)`, with arbitrary white spaces
    # before `(`, while handling multi-line cases. The `\K` escape sequence resets the grep's match,
    # that is, it excludes `MODULE_AUTHOR *\(` from the final result
    authors=$(grep --null-data --perl-regexp --only-matching 'MODULE_AUTHOR\s*\(\K[^)]*' "$file" | tr --delete '\0')

    # Trim contents from first grep deleting `\n` and `\` with any adjacent white spaces,
    # and substitute leading white spaces to a single one.
    authors=$(sed --expression 's/\\n//g' --expression 's/\s*\\\s*//g' --expression 's/^\s*/ /g' <<< "$authors")
    authors=$(tr --delete '\n' <<< "$authors")

    # Finally, delete string quotes by substituting them to commas to separate the authors, removing
    # remaining blank characters at the end of the output.
    authors=$(sed --expression 's/\"\s*\"/, /g' --expression 's/\s*\"//g' --expression 's/\s*$//g' <<< "$authors")

    if [[ -n "$authors" ]]; then
      if [[ "$printed_authors_separator" = false ]]; then
        say "$SEPARATOR"
        say 'MODULE AUTHORS:'
        printed_authors_separator=true
      fi
      say -n "$(basename "${file}"): "
      printf '%s\n' "$authors"
    fi
  done
}

function parse_maintainers_options()
{
  local long_options='authors,update-patch,verbose'
  local short_options='a,u'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw maintainers' \
      "$short_options" "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['FILE_OR_DIR']='.'
  options_values['PRINT_AUTHORS']=''
  options_values['UPDATE_PATCH']=''
  options_values['VERBOSE']=''

  eval "set -- ${options}"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --authors | -a)
        options_values['PRINT_AUTHORS']=1
        shift
        ;;
      --update-patch | -u)
        options_values['UPDATE_PATCH']=1
        shift
        ;;
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      --) # End of options, beginning of arguments
        if [[ -n "$2" ]]; then
          options_values['FILE_OR_DIR']=$2
          shift
        fi
        shift
        ;;
      *)
        options_values['ERROR']="Unrecognized argument: ${1}"
        return 22 # EINVAL
        shift
        ;;
    esac
  done
}

function maintainers_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'maintainers'
    return
  fi
  printf '%s\n' 'kw maintainers:' \
    '  maintainers [<dir> | <file>] - Shows maintainers of module' \
    '  maintainers (-a | --authors) - Also shows module authors' \
    '  maintainers (-u | --update-patch) - Add maintainers to patch file header' \
    '  maintainers (--verbose) - Show a detailed output'
}

load_kworkflow_config
