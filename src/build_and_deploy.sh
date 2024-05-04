#
# The `build_and_deploy.sh` file centralizes functions related to kw bd.
#

include "${KW_LIB_DIR}/deploy.sh"
include "${KW_LIB_DIR}/build.sh"

# kw bd is a shortcut to build and deploy a new kernel.
# It also supports arguments related to git bisect usage.
#
# The idea of using git bisect along with kw bd is to find the
# first commit where building and/or deploying the kernel failed.
#
# @raw_options String with all user options
#
function build_and_deploy_main()
{

  local raw_options="$*"

  if [[ "$1" =~ -h|--help ]]; then
    build_and_deploy_help "$1"
    exit 0
  fi

  last_commit=$(eval git rev-parse HEAD)
  parse_build_and_deploy_options "$last_commit" "$raw_options"

  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    exit 22 # EINVAL
  fi

  run_bisect="${options_values['GOOD_OR_BAD']}"
  good="${options_values['GOOD']}"
  bad="${options_values['BAD']}"
  deploy_main_args="${options_values['DEPLOY_MAIN_ARGS']}"

  if [[ $run_bisect == 0 ]]; then
    eval "build_kernel_main && deploy_main 1 ""$deploy_main_args"""
  else
    git bisect start &&
      git bisect bad "$bad" &&
      git bisect good "$good" &&
      git bisect run eval "kw b && kw d ""$deploy_main_args"""
  fi
}

# Build and deploy arguments parser
#
# @commit_hash The given commit hash
# @raw_options Options other than @commit_hash
#
function parse_build_and_deploy_options()
{
  local commit_hash="$1"
  shift
  local raw_options="$*"

  options_values['GOOD']=$commit_hash
  options_values['BAD']=$commit_hash
  options_values['GOOD_OR_BAD']=0
  options_values['DEPLOY_MAIN_ARGS']=''
  eval "set -- " "$raw_options"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --good | -g)
        options_values['GOOD_OR_BAD']=1
        options_values['CAN_RUN_OUTSIDE_KERNEL_TREE']=0
        if [[ "$2" =~ ^- || -z "${2// /}" ]]; then
          shift 1
        else
          options_values['GOOD']="$2"
          shift 2
        fi
        ;;
      --bad | -b)
        options_values['GOOD_OR_BAD']=1
        options_values['CAN_RUN_OUTSIDE_KERNEL_TREE']=0
        if [[ "$2" =~ ^- || -z "${2// /}" ]]; then
          shift 1
        else
          options_values['BAD']="$2"
          shift 2
        fi
        ;;
      *)
        options_values['DEPLOY_MAIN_ARGS']+=" "$1
        shift
        ;;
    esac
  done
}

function build_and_deploy_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'bd'
    return
  fi
  printf '%s\n' 'kw bd:' \
    '  bd - build and deploy kernel and modules:' \
    '  bd (--good | -g)[=<SHA>] - good commit hash' \
    '  bd (--bad | -b)[=<SHA>] - bad commit hash'
}
