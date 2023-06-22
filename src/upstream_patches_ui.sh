# The `upstream_patches_ui.sh` file is the entrypoint for the `upstream-patches-ui`
# feature that follows kw codestyle. As the feature is screen-driven, it is implemented
# as a state-machine in files stored at the `src/ui/upstream_patches_ui` directory.

declare -gA options_values

include "${KW_LIB_DIR}/ui/upstream_patches_ui/upstream_patches_ui_core.sh"

function upstream_patches_ui_main()
{
  if [[ "$1" =~ -h|--help ]]; then
    upstream_patches_ui_help "$1"
    exit 0
  fi

  parse_upstream_patches_ui_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    upstream_patches_ui_help
    return 22 # EINVAL
  fi

  upstream_patches_ui_main_loop
  return "$?"
}

function parse_upstream_patches_ui_options()
{
  local long_options=''
  local short_options=''

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw upstream-patches-ui' "$short_options" \
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

function upstream_patches_ui_help()
{
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'upstream-patches-ui'
    return
  fi
  printf '%s\n' 'kw upstream_patches_ui:' \
    '  upstream_patches_ui - Open UI with lore.kernel.org archives'
}
