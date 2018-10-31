. $src_script_path/miscellaneous.sh --source-only


function print_files_authors()
{
    # TODO: currently only authors found in a single line MODULE_AUTHOR
    # statement are captured and printed. In the future, it would be
    # nice to look for multiline MODULE_AUTHOR statatements such as:
    #
    # MODULE_AUTHOR ("a_long_email@xx.com" \
    #                "another_long@yy.com" )
    # and:
    #
    # MODULE_AUTHOR ("a_long_email@xx.com"
    #                "another_long@yy.com" )
    #
    # which are, both, valid C statements. In the currently
    # implementation neither of these four emails will be printed.

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
            if [ $printed_authors_separator = false ]; then
                say $SEPARATOR
                say "MODULE AUTHORS:"
                printed_authors_separator=true
            fi
            say -n "$(basename $file): "
            echo "$authors"
        fi
    done
}

function execute_get_maintainer()
{
  local FILE_OR_DIR_CHECK
  local print_authors

  local -r script="scripts/get_maintainer.pl"
  local -r options="--separator , --nokeywords --nogit --nogit-fallback --norolestats "
  local -r getmaintainers="perl $script $options"

  # Check if the command was invoked from the kernel root tree
  if [ ! -f $script ]; then
    complain "You have to execute this command from the linux tree"
    return 1
  fi

  if [[ $# -ge 1 && ( $1  = "--authors" || $1 = "-a" ) ]]; then
      FILE_OR_DIR_CHECK=$2
      print_authors=true
  else
      FILE_OR_DIR_CHECK=$1
      print_authors=false
  fi

  # Check if is a valid path
  if [ ! -d $FILE_OR_DIR_CHECK -a ! -f $FILE_OR_DIR_CHECK ]; then
    complain "Invalid path"
    return 1
  fi

  say $SEPARATOR
  say "HERE:"
  $getmaintainers $FILE_OR_DIR_CHECK

  if [ $? -ne 0 ]; then
    return $?
  fi

  if [ $print_authors = true ]; then
      print_files_authors $FILE_OR_DIR_CHECK
  fi
}
