# This file handles any web access

include "${KW_LIB_DIR}/kwio.sh"
include "${KW_LIB_DIR}/kwlib.sh"

# Download a webpage.
#
# @url         Target url
# @output      Name of the output file
# @output_path Alternative output path
# @flag        Flag to control output
function download()
{
  local url="$1"
  local output=${2:-'page.xml'}
  local output_path="$3"
  local flag="$4"

  if [[ -z "$url" ]]; then
    complain 'URL must not be empty.'
    return 22 # EINVAL
  fi

  flag=${flag:-'SILENT'}

  output_path="${output_path:-${KW_CACHE_DIR}}"

  cmd_manager "$flag" "curl --silent '$url' --output '${output_path}/${output}'"
}
