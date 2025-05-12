#
# The `build_and_deploy.sh` is the entrypoint for `kw bd`, i.e.,
# `kw build` followed by `kw deploy`.
#

include "${KW_LIB_DIR}/deploy.sh"
include "${KW_LIB_DIR}/build.sh"
include "${KW_LIB_DIR}/lib/kwio.sh"

# `kw bd` is a shortcut for `kw build` followed `kw deploy`, to run the entire workflow
# of building a kernel from source and deploying it to a target machine.
#
# @raw_options String with all deploy options
function build_and_deploy_main()
{
  if [[ "$1" =~ -h|--help ]]; then
    build_and_deploy_help "$1"
    exit 0
  fi

  build_kernel_main
  if [[ "$?" != 0 ]]; then
    complain 'kernel build failed\n'
    exit 22 # EINVAL
  fi

  # parameter 1 indicates that deploy is being called within kw bd context.
  deploy_main 1 "$@"
  if [[ "$?" != 0 ]]; then
    complain 'kernel deploy failed\n'
    exit 22 # EINVAL
  fi
  return 0
}

function build_and_deploy_help()
{
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'bd'
    return
  fi
  printf '%s\n' 'kw bd:' \
    '  bd - build and deploy kernel and modules:'
}
