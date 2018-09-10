function kw::execute_get_maintainer()
{
  local FILE_OR_DIR_CHECK=$1

  local -r script="scripts/get_maintainer.pl"
  local -r options="--separator , --nokeywords --nogit --nogit-fallback --norolestats "
  local -r getmaintainers="perl $script $options"

  # Check if the command was invoked from the kernel root tree
  if [ ! -f $script ]; then
    kw::complain "You have to execute this command from the linux tree"
    return
  fi

  # Check if is a valid path
  if [ ! -d $FILE_OR_DIR_CHECK -a ! -f $FILE_OR_DIR_CHECK ]; then
    kw::complain "Invalid path"
    return
  fi

  kw::say $SEPARATOR
  kw::say "HERE:"
  $getmaintainers $FILE_OR_DIR_CHECK
}
