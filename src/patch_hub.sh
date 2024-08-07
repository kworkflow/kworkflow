# The `patch_hub.sh` file is the entrypoint for the `patch-hub`
# feature that follows kw codestyle. As the feature is screen-driven, it is implemented
# as a state-machine in files stored at the `src/ui/patch_hub` directory.

declare -gA options_values

include "${KW_LIB_DIR}/ui/patch_hub/patch_hub_core.sh"

function patch_hub_main()
{
  local ret

  if ! command_exists 'patch-hub'; then
    complain 'Could not find the `patch-hub` executable.'
    warning 'Either run `./setup.sh --install` from the root of a kw repo or follow the instructions below.'
    warning 'Install instructions: https://github.com/kworkflow/patch-hub?tab=readme-ov-file#package-how-to-install.'
    return 2 # ENOENT
  fi

  # We must export these env variables to be accessible by `patch-hub`
  export KW_DATA_DIR
  export KW_CACHE_DIR

  patch-hub "$@"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain "patch-hub exited with error code ${ret}"
    return "$ret"
  fi
}
