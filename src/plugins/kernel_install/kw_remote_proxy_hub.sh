# Summary: This file works as a proxy between the kw in the dev machine and the
# files in the remote.
#
# This file is executed via ssh, i.e., it is used in the remote machine. This
# code works as an entry point between the code under src/deploy.sh and
# kernel_install files; for this reason, it also has some variable adaptations
# to ensure that lib and other files work as expected in the remote.
#
# There are a few things to notice about this file from the kw perspective:
#
# 1. We need one specific file distro based on the target distro (e.g.,
#    ArchLinux requires arch.sh, Ubuntu require debian.sh, etc.
# 2. The code associted with the distro deploy can have any function as far it
#    implements install_modules, install_kernel, kernel_uninstall, and
#    list_installed_kernels (I think the function names already explain what it
#    does).
#
# The following parameter sequence must be followed:
#
# --kw-path: Path where kw code is available in the remote machine.
# --kw-tmp-files: Temporary directories to receive kw package and others.
# --modules|--kernel-update|--list-kernels|--uninstall-kernels: Which action we
#   want to uxecute in the target. It is only allowed to request one execution
#   at time.

# Global variable
declare -g REMOTE_KW_DEPLOY='/opt/kw'
declare -g KW_DEPLOY_TMP_FILE='/tmp/kw'
declare -g INSTALLED_KERNELS_PATH="${REMOTE_KW_DEPLOY}/INSTALLED_KERNELS"

# ATTENTION:
#
# All files from lib are prefixed with the variable KW_LIB_DIR. Since this
# script is only executed in the remote machine, we can safely override this
# variable value to the correct path which is REMOTE_KW_DEPLOY.
KW_LIB_DIR="${REMOTE_KW_DEPLOY}"

# Allow include function to be used in the kernel_install plugin
. "${REMOTE_KW_DEPLOY}/lib/kw_include.sh" --source-only

# Processing input data
action=''
options_string=''

long_options='kw-path:,kw-tmp-files:,modules,kernel-update,uninstall-kernels,'
long_options+='list-kernels,deploy-setup,collect-info'
options="$(getopt --options '' --longoptions "$long_options" -- "$@")"
eval "set -- $options"

# Tiny hack to extract actions parameters
#1. Get everything after --
action_parameters=$(echo "$options" | sed 's/.*--//')
#2. Remove single-quotes and ensure that we keep '' as a parameter
action_parameters=$(echo "$action_parameters" | sed "s/''/¬/g" | sed "s/'//g" | sed "s/¬/''/g")

IF=' ' read -r -a action_parameters <<< "$action_parameters"

while true; do
  case "$1" in
    --kw-path)
      REMOTE_KW_DEPLOY="$2"
      INSTALLED_KERNELS_PATH="${REMOTE_KW_DEPLOY}/INSTALLED_KERNELS"
      shift 2
      ;;
    --kw-tmp-files)
      KW_DEPLOY_TMP_FILE="$2"
      shift 2
      ;;
    --modules)
      action='modules'
      shift 2
      break
      ;;
    --deploy-setup)
      action='deploy_setup'
      shift 2
      break
      ;;
    --kernel-update)
      action='kernel_update'
      shift 2
      break
      ;;
    --list-kernels)
      action='list_kernels'
      shift 2
      break
      ;;
    --uninstall-kernels)
      action='uninstall_kernels'
      shift 2
      break
      ;;
    --collect-info)
      action='collect_info'
      shift 2
      break
      ;;
    --)
      shift
      ;;
    *)
      printf "kw: error: Unknown parameter - %s\n" "$1"
      exit 22 # EINVAL
      ;;
  esac
done

if [[ -z "$action" ]]; then
  printf 'kw: error: Please, provide an action\n'
  exit 22 # EINVAL
fi

if [[ ! -d "$REMOTE_KW_DEPLOY" ]]; then
  printf 'It was not possible to move to %s\n' "$REMOTE_KW_DEPLOY"
  exit 2 # ENOENT
fi

# It is safe to cd `$REMOTE_KW_DEPLOY` due to the above check
#shellcheck disable=SC2164
cd "$REMOTE_KW_DEPLOY"

# Include base files
include "${REMOTE_KW_DEPLOY}/utils.sh"
include "${REMOTE_KW_DEPLOY}/bootloader_utils.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kwio.sh"

# Identify which distro this script will run, and load the correct file (e.g.,
# ArchLinux should load arch.sh, Fedora should load fedora.sh, etc)
#
distro=$(detect_distro '/')

if [[ "$distro" =~ 'none' ]]; then
  printf '%s\n' 'It looks like kw does not support your distro'
  exit 95 # Not supported
fi

# Load the correct distro file is important to ensure that kw calls the correct
# function.
include "${REMOTE_KW_DEPLOY}/${distro}.sh"

case "$action" in
  'modules')
    # shellcheck disable=SC2068
    install_modules ${action_parameters[@]}
    ;;
  'kernel_update')
    include "${REMOTE_KW_DEPLOY}/install.sh"
    # shellcheck disable=SC2068
    install_kernel ${action_parameters[@]}
    ;;
  'list_kernels')
    # shellcheck disable=SC2068
    list_installed_kernels ${action_parameters[@]}
    ;;
  'uninstall_kernels')
    include "${REMOTE_KW_DEPLOY}/uninstall.sh"
    # shellcheck disable=SC2068
    kernel_uninstall ${action_parameters[@]}
    ;;
  'deploy_setup')
    # shellcheck disable=SC2068
    distro_deploy_setup ${action_parameters[@]}
    ;;
  'collect_info')
    # shellcheck disable=SC2068
    collect_deploy_info ${action_parameters[@]}
    ;;
  *)
    printf '%s\n' 'Unknown operation'
    ;;
esac
