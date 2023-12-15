#!/bin/bash
# The `patch_hub.sh` file is the entrypoint for the `patch-hub`
# feature that follows kw codestyle. As the feature is screen-driven, it is implemented
# as a state-machine in files stored at the `src/ui/patch_hub` directory.

declare -gA options_values

include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

function patch_hub_main()
{
  if [[ "$1" =~ -h|--help ]]; then
    patch_hub_help "$1"
    exit 0
  fi

  parse_patch_hub_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    patch_hub_help
    return 22 # EINVAL
  fi

  patch_hub_main_loop
  return "$?"
}

function parse_patch_hub_options()
{
  local long_options=''
  local short_options=''

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw patch-hub' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  eval "set -- ${options}"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --)
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
}

function patch_hub_help()
{
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'patch-hub'
    return
  fi
  printf '%s\n' 'kw patch-hub:' \
    '  patch-hub - Open UI with lore.kernel.org archives'
}
