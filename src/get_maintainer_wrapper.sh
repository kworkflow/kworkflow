include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kwlib.sh"

# Prints the authors of a given file or files inside a given dir.
#
# @FILE_OR_DIR The argument is a file or directory path
function print_files_authors()
{
  local FILE_OR_DIR=$1
  local files=()
  if [[ -d $FILE_OR_DIR ]]; then
    for file in $FILE_OR_DIR/*; do
      if [[ -f $file ]]; then
        files+=($file)
      fi
    done
  elif [[ -f $FILE_OR_DIR ]]; then
    files+=($FILE_OR_DIR)
  fi

  local printed_authors_separator=false

  for file in ${files[@]}; do
    authors=$(grep -oE "MODULE_AUTHOR *\(.*\)" $file |
      sed -E "s/(MODULE_AUTHOR *\( *\"|\" *\))//g" |
      sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/, /g')
    if [[ ! -z $authors ]]; then
      if [[ $printed_authors_separator = false ]]; then
        say $SEPARATOR
        say "MODULE AUTHORS:"
        printed_authors_separator=true
      fi
      say -n "$(basename $file): "
      echo "$authors"
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
function execute_get_maintainer()
{
  local raw_options="$@"
  local FILE_OR_DIR
  local print_authors=false
  local update_patch=false
  local is_file_a_patch=true
  local is_file_inside_kernel_tree=true

  local -r script="scripts/get_maintainer.pl"
  local script_options="--separator , --nokeywords --nogit "
  script_options="$script_options --nogit-fallback --norolestats "

  local -r original_working_dir=$PWD
  local kernel_root=""
  local path_from_kernel_root=""

  if [[ "$1" == -h ]]; then
    maintainers_help
    exit 0
  fi

  IFS=' ' read -r -a options <<< "$raw_options"
  for option in "${options[@]}"; do
    if [[ "$option" =~ ^(--.*|-.*) ]]; then
      case "$option" in
        -au | -ua)
          print_authors=true
          update_patch=true
          continue
          ;;
        --authors | -a)
          print_authors=true
          continue
          ;;
        --update-patch | -u)
          update_patch=true
          continue
          ;;
        *)
          warning "Unrecognized option: $option"
          continue
          ;;
      esac
    else
      FILE_OR_DIR=${FILE_OR_DIR:-$option}
    fi
  done

  # If no file is given, assume "."
  if [[ -z $FILE_OR_DIR ]]; then
    FILE_OR_DIR="."
  fi

  # Check if is a valid path
  if [[ ! -d $FILE_OR_DIR && ! -f $FILE_OR_DIR ]]; then
    complain "Invalid path"
    return 1
  fi

  FILE_OR_DIR="$(realpath $FILE_OR_DIR)"

  # if given path is not a patchfile, add -f to get_maintainer.pl options
  if ! is_a_patch "$FILE_OR_DIR"; then
    if "$update_patch"; then
      complain "Option --update-patch was passed but given path is not a patch."
      return 1
    fi
    is_file_a_patch=false
    script_options="$script_options -f "
  fi

  # try to find kernel root at given path
  kernel_root="$(find_kernel_root $FILE_OR_DIR)"
  if [[ -z "$kernel_root" ]]; then
    is_file_inside_kernel_tree=false
    # fallback: try to find kernel root at working path
    kernel_root="$(find_kernel_root $original_working_dir)"
  fi

  # Check if kernel root was found.
  if [[ -z "$kernel_root" ]]; then
    complain "Neither the given path nor the working path is in a kernel tree."
    return 1
  fi

  # If file is not a patch and outside a kernel tree, it must be an user's
  # mistake. Although get_maintainer.pl can handle this, it's better to abort
  # because it is most likely a user's mistake. So better let the user know.
  if ! $is_file_a_patch && ! $is_file_inside_kernel_tree; then
    complain "The given file is not a patch and is outside a kernel tree."
    return 1
  fi

  cd "$kernel_root"
  local -r script_output="$(eval perl $script $script_options "$FILE_OR_DIR")"
  cd "$original_working_dir"

  say "$SEPARATOR"
  if "$update_patch"; then
    # Check if "To:" field is already present
    if grep -q -E '^To: .*'"$script_output" "$FILE_OR_DIR"; then
      say "Maintainers already in \"To:\" field of $(basename $FILE_OR_DIR)"
      return 0
    elif grep -q -E '^To: ' "$FILE_OR_DIR"; then
      # append maintainers to existing "To:" field
      sed -E -i 's/(^To:.*)/\1, '"$script_output"'/' "$FILE_OR_DIR"
    else
      sed -E -i 's/(^Subject:.*)/To: '"$script_output"'\n\1/' "$FILE_OR_DIR"
    fi
    say "Patch $(basename $FILE_OR_DIR) updated with the following maintainers:"
  else
    say "HERE:"
  fi
  echo "$script_output"

  if $print_authors; then
    print_files_authors $FILE_OR_DIR
  fi
}

function maintainers_help()
{
  echo -e "kw maintainers|m:\n" \
    "\tmaintainers,m [--authors|-a] [--update-patch|-u]\n"
}
