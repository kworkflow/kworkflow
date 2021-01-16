# Checkpatch is a useful tool provided by Linux, and the main goal of the code
# in this file is to handle this script in a way to make this tool easier for
# users.

. "$KW_LIB_DIR/kw_config_loader.sh" --source-only
. "$KW_LIB_DIR/kwlib.sh" --source-only

# Runs checkpatch in the given path, which might be a file or directory.
#
# @FILE_OR_DIR_CHECK Target path for running checkpatch script
function execute_checkpatch()
{
  local FILE_OR_DIR_CHECK="$1"

  #TODO: Note that codespell file is not specified yet because of the poluted
  # output. It could be nice if we can add another option just for this sort
  # of check.

  local -r options="--terse --no-tree --color=always -strict --file "
  local -r script="scripts/checkpatch.pl $options"
  local -r original_working_dir="$PWD"
  local kernel_root=""

  if [[ -z "$FILE_OR_DIR_CHECK" ]]; then
    FILE_OR_DIR_CHECK="."
  fi

  # Check if is a valid path
  if [[ ! -d "$FILE_OR_DIR_CHECK" && ! -f "$FILE_OR_DIR_CHECK" ]]; then
    complain "Invalid path"
    return 2 # ENOENT
  fi

  # Get realpath for using inside checkpatch
  FILE_OR_DIR_CHECK="$(realpath $FILE_OR_DIR_CHECK)"

  # Try to find kernel root at given path
  kernel_root="$(find_kernel_root $FILE_OR_DIR_CHECK)"
  if [[ -z "$kernel_root" ]]; then
    # Fallback: try to find kernel root at working path
    kernel_root="$(find_kernel_root $original_working_dir)"
  fi

  # Check if kernel root was found
  if [[ -z "$kernel_root" ]]; then
    complain "Neither the given path nor the working path is in a kernel tree."
    return 22 # EINVAL
  fi

  # Build a list of file to apply check patch
  FLIST=`find $FILE_OR_DIR_CHECK -type f ! -name '*\.mod\.c' | grep "\.[ch]$"`

  say "Running checkpatch.pl on: $FILE_OR_DIR_CHECK"
  say "$SEPARATOR"

  cmd="perl $script "
  for current_file in $FLIST; do
    file="$current_file"

    if [[ ! -e "$file" ]]; then
      echo "$file does not exist."
      continue
    fi

    cd "$kernel_root"

    cmd_manager "SILENT" "$cmd $file"

    if [[ "$?" != 0 ]]; then
      say "$SEPARATOR"
    fi

    cd "$original_working_dir"
  done
}
