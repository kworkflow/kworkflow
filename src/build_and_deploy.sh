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
  ##build and deploy flags
  build_options=()
  deploy_options=()

  parse_build_and_deploy_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    build_and_deploy_help
    return 22 # EINVAL
  fi

  build_kernel_main '' "${build_options[@]}"
  if [[ "$?" != 0 ]]; then
    complain 'kernel build failed\n'
    exit 22 # EINVAL
  fi

  # parameter 1 indicates that deploy is being called within kw bd context.
  deploy_main 1 "${deploy_options[@]}"
  if [[ "$?" != 0 ]]; then
    complain 'kernel deploy failed\n'
    exit 22 # EINVAL
  fi
  return 0
}

function parse_build_and_deploy_options()
{
  #build options
  local long_options='help,ccache,cpu-scaling:,warnings::,save-log-to:,llvm,verbose,cflags:'
  local short_options='h,S:,w::,s:'

  # #deploy options
  long_options+=',remote:,local,reboot,no-reboot,modules,force,setup,verbose,create-package,from-package:,boot-into-new-kernel-once'
  short_options+=',r,m,f,v,p,F:,n'

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then

    options_values['ERROR']="$(kw_parse_get_errors 'kw bd' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  while [[ "$#" -gt 0 ]]; do

    case "$1" in
      --help | -h)
        # build_and_deply_help "$1"
        build_and_deploy_help "$1"
        exit
        ;;
      --cpu-scaling | -S)
        build_options+=("$1" "$2")
        shift 2
        ;;
      --ccache)
        build_options+=("$1")
        shift
        ;;
      --llvm)
        build_options+=("$1")
        shift
        ;;
      --cflags)
        build_options+=("$1" "$2")
        shift 2
        ;;
      --verbose)
        build_options+=("$1")
        deploy_options+=("$1")
        shift
        ;;
      --warnings | -w)
        # Handling optional parameter
        if [[ "$2" =~ [0-9]+ ]]; then
          build_options+=("$1" "$2")
          shift 2
        else
          build_options+=("$1")
          shift
        fi
        ;;
      --save-log-to | -s)
        build_options+=("$1" "$2")
        shift 2
        #after this line only deploy options
        ;;
      --remote)
        deploy_options+=("$1" "$2")
        shift 2
        ;;
      --local)
        deploy_options+=("$1")
        shift
        ;;
      --reboot | -r)
        deploy_options+=("$1")
        shift
        ;;
      --no-reboot)
        deploy_options+=("$1")
        shift
        ;;
      --modules | -m)
        deploy_options+=("$1")
        shift
        ;;
      --force | -f)
        deploy_options+=("$1")
        shift
        ;;
      --create-package | -p)
        deploy_options+=("$1")
        shift
        ;;
      --from-package | -F)
        deploy_options+=("$1" "$2")
        shift 2
        ;;
      --boot-into-new-kernel-once | -n)
        deploy_options+=("$1")
        shift
        ;;
      --)
        shift
        ;;
      *)
        options_values['ERROR']="$1" #it is an invalid option
        return 22                    # EINVAL
        ;;
    esac
  done
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
