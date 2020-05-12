. $src_script_path/kw_config_loader.sh --source-only
. $src_script_path/kwlib.sh --source-only

# Prints the authors of a given file or files inside a given dir.
#
# @FILE_OR_DIR The argument is a file or directory path
function print_files_authors()
{
  local FILE_OR_DIR=$1
  local files=( )
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
              sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/, /g' )
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
# @1 First argument can be "--authors" or "a" to enable authors
#    printing. It is optional.
# @2 Second argument is the given file/dir. It is optional and, if not
#    given, the current working directory will be used.
#
# Returns:
# False uppon error and true otherwise.
#
# This function also handle the cases where:
# - A patch file is given
# - The working dir and/or given path is not the root of a linux kernel repo
# - The working dir and/or given path is not inside a linux kernel repo
function execute_get_maintainer()
{
  local FILE_OR_DIR
  local print_authors
  local is_file_a_patch=true
  local is_file_inside_kernel_tree=true

  local -r script="scripts/get_maintainer.pl"
  local options="--separator , --nokeywords --nogit --nogit-fallback --norolestats "

  local -r original_working_dir=$PWD
  local kernel_root=""
  local path_from_kernel_root=""

  # Check function options
  if [[ $# -ge 1 && ( $1  = "--authors" || $1 = "-a" ) ]]; then
    FILE_OR_DIR=$2
    print_authors=true
  else
    FILE_OR_DIR=$1
    print_authors=false
  fi

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
    is_file_a_patch=false
    options="$options -f "
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

  say $SEPARATOR
  say "HERE:"
  cd $kernel_root
  eval perl $script $options "$FILE_OR_DIR"
  cd $original_working_dir

  if $print_authors; then
    print_files_authors $FILE_OR_DIR
  fi
}
