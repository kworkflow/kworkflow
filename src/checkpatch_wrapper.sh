. $src_script_path/commons.sh --source-only
. $src_script_path/kwlib.sh --source-only

function execute_checkpatch()
{
  local FILE_OR_DIR_CHECK=$1

  #TODO: Note that codespell file is not specified yet because of the poluted
  # output. It could be nice if we can add another option just for this sort
  # of check. Follow the line that makes the magic:
  # --codespell $external_script_path/spelling.txt

  local -r options="--terse --no-tree --color=always -strict --file "
  local kernel_root=""
  local -r script="scripts/checkpatch.pl $options"
  local -r original_working_dir=$PWD

  if [[ -z $FILE_OR_DIR_CHECK ]]; then
    FILE_OR_DIR_CHECK="."
  fi

  FILE_OR_DIR_CHECK="$(realpath $FILE_OR_DIR_CHECK)"
  # Check if is a valid path
  if [[ ! -d $FILE_OR_DIR_CHECK && ! -f $FILE_OR_DIR_CHECK ]]; then
    complain "Invalid path"
    return 1
  fi

  # try to find kernel root at given path
  kernel_root="$(find_kernel_root $FILE_OR_DIR_CHECK)"
  if [[ -z "$kernel_root" ]]; then
    # fallback: try to find kernel root at working path
    kernel_root="$(find_kernel_root $original_working_dir)"
  fi

  # Check if kernel root was found.
  if [[ -z "$kernel_root" ]]; then
    complain "Neither the given path nor the working path is in a kernel tree."
    return 1
  fi  
  # Build a list of file to apply check patch
  FLIST=`find $FILE_OR_DIR_CHECK -type f ! -name '*\.mod\.c' | grep "\.[ch]$" `
  say "Running checkpatch.pl on: $FILE_OR_DIR_CHECK"
  say $SEPARATOR

  for current_file in $FLIST
  do
    file=$current_file

    if [ ! -e "$file" ]
    then
      echo "$file does not exist."; echo
      continue
    fi

    cd $kernel_root
    eval perl $script $file
    cd $original_working_dir

    if [ $? != 0 ]; then
      say $SEPARATOR
    fi

  done
}
