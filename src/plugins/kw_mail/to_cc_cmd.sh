# This file reads the files generated containing the recipients for any given
# patch, this is supposed to be used by `git send-email` in the `--to-cmd` and
# `--cc-cmd` arguments after the appropriate files have been created using the
# `generate_kernel_recipients` function in the `src/send_patch.sh` file.

# This reads the list of recipients stored in a file corresponding to the given
# patch
#
# @kw_cache:   Path to KW_CACHE_DIR
# @to_cc:      Should be either `to` or `cc` and defines which list to read, passed
#                by kw.
# @patch_path: Path to the current patch, passed by `git send-email`. Always
#                the last argument.
#
# Returns:
# Relevant list of recipients to the patch
function to_cc_main() {
  local kw_cache="$1"
  local to_cc="$2"
  local patch_path="$3"
  local patch
  local patch_cache="${kw_cache}/patches/${to_cc}"
  local recipients_path
  local recipients

  [[ -z "$to_cc" || -z "$patch_path" ]] && return 22 # EINVAL

  patch="$(basename "$patch_path")"

  if [[ "$patch" =~ cover-letter ]]; then
    cat "${patch_cache}/cover-letter"
    exit 0
  fi

  cat "${patch_cache}/${patch}"
  exit 0
}

to_cc_main "$@"
