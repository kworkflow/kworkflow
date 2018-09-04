function execute_checkpatch()
{
  local FILE_OR_DIR_CHECK=$1

  local -r options="--terse --no-tree --color=always --codespell -strict --file "
  local -r checkpatch="perl $external_script_path/checkpatch.pl $options"

  # Check if is a valid path
  if [ ! -d $FILE_OR_DIR_CHECK -a ! -f $FILE_OR_DIR_CHECK ]; then
    complain "Invalid path"
    return
  fi

  # Build a list of file to apply check patch
  FLIST=`find $FILE_OR_DIR_CHECK -type f ! -name '*\.mod\.c' | grep "\.[ch]$" `

  say "Running checkpatch.pl on: $FILE_OR_DIR_CHECK"

  for current_file in $FLIST
  do
    file=$current_file
    echo

    if [ ! -e "$file" ]
    then
      echo "$file does not exist."; echo
      continue
    fi

    say $SEPARATOR
    $checkpatch $file
  done
}
