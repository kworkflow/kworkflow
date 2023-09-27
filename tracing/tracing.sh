# This file contains library functions specific to adding tracing capabilities
# to kw. The functions defined here are to be called at installation time when
# running `setup.sh`.

# This function injects code that enables tracing into the main kw file and
# installs this altered version.
#
# @kw_path: Name/Path to main kw file. By default, we assume it resides in the
#   current dir
# @bin: Path of `bin` dir to install main kw file
# @tracing_code_excerpts_dir: Path do dir containg code excerpts to be injected
#   into kw main file
#
# Return:
# Returns 2 (ENOENT) if either `@kw_path` or `@bin` isn't a valid file/dir path,
# and 0, otherwise.
function sync_main_kw_file_with_tracing()
{
  local kw_path="$1"
  local bin="$2"
  local tracing_code_excerpts_dir="$3"
  local main_kw_file_with_tracing

  [[ ! -f "$kw_path" || ! -d "$bin" ]] && return 2 # ENOENT

  # Parse each line of base kw main file and inject the correspondent excerpt
  # when `line` is a guard that marks the injection point.
  while read -r line; do
    if [[ "$line" =~ ^[[:space:]]*#INJECT_CODE_TRACING_SETUP$ ]]; then
      main_kw_file_with_tracing+=$(< "${tracing_code_excerpts_dir}/tracing_setup")$'\n'
    elif [[ "$line" =~ ^[[:space:]]*#INJECT_CODE_TRACING_COMMIT$ ]]; then
      main_kw_file_with_tracing+=$(< "${tracing_code_excerpts_dir}/tracing_commit")$'\n'
    else
      main_kw_file_with_tracing+="$line"$'\n'
    fi
  done < "$kw_path"

  printf '%s' "$main_kw_file_with_tracing" > "${bin}/${kw_path}"
  chmod +x "${bin}/${kw_path}"
}
