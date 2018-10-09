. $src_script_path/miscellaneous.sh --source-only

function execute_get_maintainer()
{
  local FILE_OR_DIR_CHECK=$1

  local -r script="scripts/get_maintainer.pl"
  local -r options="--separator , --nokeywords --nogit --nogit-fallback --norolestats "
  local -r getmaintainers="perl $script $options"

  # Check if the command was invoked from the kernel root tree
  if [ ! -f $script ]; then
    complain "You have to execute this command from the linux tree"
    return 1
  fi

  # Check if is a valid path
  if [ ! -d $FILE_OR_DIR_CHECK -a ! -f $FILE_OR_DIR_CHECK ]; then
    complain "Invalid path"
    return 1
  fi

  say $SEPARATOR
  say "HERE:"
  $getmaintainers $FILE_OR_DIR_CHECK
}
