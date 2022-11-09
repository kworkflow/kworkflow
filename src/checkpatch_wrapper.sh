# Checkpatch is a useful tool provided by Linux, and the main goal of the code
# in this file is to handle this script in a way to make this tool easier for
# users.

include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kwlib.sh"

# Runs checkpatch in the given path, which might be a file or directory.
#
# @FILE_OR_DIR_CHECK Target path for running checkpatch script
function execute_checkpatch()
{
  local FILE_OR_DIR_CHECK="$1"
  local flag="$2"

  if [[ "$FILE_OR_DIR_CHECK" =~ ^-h|^--help ]]; then
    codestyle_help "$1"
    return 0
  fi
  # TODO: Note that codespell file is not specified yet because of the poluted
  # output. It could be nice if we can add another option just for this sort
  # of check.

  local options="${configurations[checkpatch_opts]}"
  local -r original_working_dir="$PWD"
  local kernel_root
  local cmd_script

  FILE_OR_DIR_CHECK=${FILE_OR_DIR_CHECK:-'.'}
  flag=${flag:-'SILENT'}

  # Check if is a valid path
  if [[ ! -d "$FILE_OR_DIR_CHECK" && ! -f "$FILE_OR_DIR_CHECK" ]]; then
    complain 'Invalid path'
    return 2 # ENOENT
  fi

  # Get realpath for using inside checkpatch
  FILE_OR_DIR_CHECK="$(realpath "$FILE_OR_DIR_CHECK")"

  # Try to find kernel root at given path
  kernel_root="$(find_kernel_root "$FILE_OR_DIR_CHECK")"
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
  FLIST=$(find "$FILE_OR_DIR_CHECK" -type f ! -name '*\.mod\.c' | grep "\.[ch]$")

  say "Running checkpatch.pl on: $FILE_OR_DIR_CHECK"
  say "$SEPARATOR"

  # Define different rules for patch and files
  if is_a_patch "$FILE_OR_DIR_CHECK"; then
    FLIST="$FILE_OR_DIR_CHECK"
  else
    options="--terse $options --file"
  fi

  cmd_script="perl scripts/checkpatch.pl $options"

  for current_file in $FLIST; do
    file="$current_file"

    if [[ ! -e "$file" ]]; then
      printf '%s\n' "$file does not exist."
      continue
    fi

    cd "$kernel_root" || exit_msg 'It was not possible to move to kernel root dir'

    cmd_manager "$flag" "$cmd_script $file"
    [[ "$?" != 0 ]] && say "$SEPARATOR"

    cd "$original_working_dir" || exit_msg 'It was not possible to move back from kernel dir'
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
    '  codestyle [<dir>|<file>|<patch>] - Use checkpatch on target'
}

load_kworkflow_config
