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
  local varname

  if [[ ! -r "$filepath" ]]; then
    if [[ ! -e "$filepath" ]]; then
      printf '%s\n' "File $filepath could not be found, check your file path."
      return 2 # ENOENT
    fi
    printf '%s\n' "File $filepath could not be read, check your file permissions."
    return 1 # EPERM
  fi

  varname="$(realpath "$filepath")"
  varname="${varname#"$KW_LIB_DIR/"}" # leave path until KW_LIB_DIR
  varname="${varname//\//_}"          # change bars to underlines
  varname="${varname//\./_}"          # change dots into underscores
  varname="${varname// /_}"           # change spaces into underscores
  varname="${varname//-/_}"           # change dashes into underscores
  varname="${varname^^}_IMPORTED"     # capitalize and append "_IMPORTED"

  if [[ -v "${varname}" ]]; then
    return 0
  fi

  declare -g "${varname}"=1

  [[ "$?" != 0 ]] && return 22 # EINVAL

  . "$filepath" --source-only
}
