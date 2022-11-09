include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kwlib.sh"

declare -gA options_values

# Prints the authors of a given file or files inside a given dir.
#
# @FILE_OR_DIR The argument is a file or directory path
function print_files_authors()
{
  local FILE_OR_DIR=$1
  local files=()
  if [[ -d $FILE_OR_DIR ]]; then
    for file in "$FILE_OR_DIR"/*; do
      if [[ -f $file ]]; then
        files+=("$file")
      fi
    done
  elif [[ -f $FILE_OR_DIR ]]; then
    files+=("$FILE_OR_DIR")
  fi

  local printed_authors_separator=false

  for file in "${files[@]}"; do
    authors=$(grep -oE 'MODULE_AUTHOR *\(.*\)' "$file" |
      sed -E 's/(MODULE_AUTHOR *\( *\"|\" *\))//g' |
      sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/, /g')
    if [[ -n $authors ]]; then
      if [[ $printed_authors_separator = false ]]; then
        say "$SEPARATOR"
        say 'MODULE AUTHORS:'
        printed_authors_separator=true
      fi
      say -n "$(basename "$file"): "
      printf '%s\n' "$authors"
    fi
  done
}

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

  local -r script='scripts/get_maintainer.pl'
  local script_options="${configurations[get_maintainer_opts]}"

  local -r original_working_dir=$PWD
  local kernel_root=''

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

  # Check if is a valid path
  if [[ ! -d $FILE_OR_DIR && ! -f $FILE_OR_DIR ]]; then
    complain 'Invalid path'
    return 1
  fi

  FILE_OR_DIR="$(realpath $FILE_OR_DIR)"

  # if given path is not a patchfile, add -f to get_maintainer.pl options
  if ! is_a_patch "$FILE_OR_DIR"; then
    if "$update_patch"; then
      complain 'Option --update-patch was passed but given path is not a patch.'
      return 1
    fi
    is_file_a_patch=false
    script_options="$script_options -f"
  fi

  # try to find kernel root at given path
  kernel_root="$(find_kernel_root "$FILE_OR_DIR")"
  if [[ -z "$kernel_root" ]]; then
    is_file_inside_kernel_tree=false
    # fallback: try to find kernel root at working path
    kernel_root="$(find_kernel_root "$original_working_dir")"
  fi

  # Check if kernel root was found.
  if [[ -z "$kernel_root" ]]; then
    complain 'Neither the given path nor the working path is in a kernel tree.'
    return 1
  fi

  # If file is not a patch and outside a kernel tree, it must be an user's
  # mistake. Although get_maintainer.pl can handle this, it's better to abort
  # because it is most likely a user's mistake. So better let the user know.
  if ! $is_file_a_patch && ! $is_file_inside_kernel_tree; then
    complain 'The given file is not a patch and is outside a kernel tree.'
    return 1
  fi

  cd "$kernel_root" || exit_msg 'It was not possible to move to kernel root dir'
  local -r script_output="$(eval perl "$script" "$script_options" "$FILE_OR_DIR")"
  cd "$original_working_dir" || exit_msg 'It was not possible to move back from kernel dir'

  say "$SEPARATOR"
  if "$update_patch"; then
    # Check if "To:" field is already present
    if grep -q -E '^To: .*'"$script_output" "$FILE_OR_DIR"; then
      say "Maintainers already in 'To:' field of $(basename "$FILE_OR_DIR")"
      return 0
    elif grep -q -E '^To: ' "$FILE_OR_DIR"; then
      # append maintainers to existing "To:" field
      sed -E -i 's/(^To:.*)/\1, '"$script_output"'/' "$FILE_OR_DIR"
    else
      sed -E -i 's/(^Subject:.*)/To: '"$script_output"'\n\1/' "$FILE_OR_DIR"
    fi
    say "Patch $(basename "$FILE_OR_DIR") updated with the following maintainers:"
  else
    say 'HERE:'
  fi
  printf '%s\n' "$script_output"

  if $print_authors; then
    print_files_authors "$FILE_OR_DIR"
  fi
}

function parse_maintainers_options()
{
  local long_options='authors,update-patch'
  local short_options='a,u'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw maintainers' \
      "$short_options" "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['FILE_OR_DIR']='.'
  options_values['PRINT_AUTHORS']=false
  options_values['UPDATE_PATCH']=false

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --authors | -a)
        options_values['PRINT_AUTHORS']=true
        shift
        ;;
      --update-patch | -u)
        options_values['UPDATE_PATCH']=true
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
        options_values['ERROR']="Unrecognized argument: $1"
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
    '  maintainers (-u | --update-patch) - Add maintainers to patch file header'
}

load_kworkflow_config
