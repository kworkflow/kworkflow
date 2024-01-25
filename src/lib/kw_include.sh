#Used for file sourcing.
#This function should used for file sourcing instead of `. file.sh --source-only`
#
# @filepath Path to the file to be sourced
#
# Returns:
# 0 on a succesful import, 1 if the file can't be read and 2 if it can´t be found
function include()
{
  local filepath="$1"
  local fullpath

  if [[ ! -r "$filepath" ]]; then
    if [[ ! -e "$filepath" ]]; then
      printf '%s\n' "File $filepath could not be found, check your file path."
      return 2 # ENOENT
    fi
    printf '%s\n' "File $filepath could not be read, check your file permissions."
    return 1 # EPERM
  fi

  fullpath="$(realpath "$filepath")"

  if [[ -v KW_INCLUDES_SET ]]; then
    [[ -v KW_INCLUDED_PATHS["$fullpath"] ]] && return 0

    KW_INCLUDED_PATHS["$fullpath"]=1
  else
    declare -g KW_INCLUDES_SET=1
    declare -gA KW_INCLUDED_PATHS=(["$fullpath"]=1)
  fi

  shift
  . "$filepath" --source-only "$@"
}
