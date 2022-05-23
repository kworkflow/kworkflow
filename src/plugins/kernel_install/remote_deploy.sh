#!/bin/bash

# This script will be executed via ssh, because of this, I can't see any good
# reason (until now) for making things complicated here.
#
# There are a few things to notice about this file from the kw perspective:
# 1. We need one specific file script per distro; this code is in the
#    `distro_deploy.sh` file on the remote machine. This file is copied from
#    `src/plugins/kernel_install/DISTRO_NAME`.
# 2. The script related to the distro deploy can have any function as far it
#    implements `install_modules` and `install_kernel` (I think the function
#    names already explain what it does).
#
# The following parameter sequence must be followed:
#
# --kw-path: Path where kw scripts will live
# --kw-tmp-files: Temporary directories
# --modules|--kernel-update|--list-kernels|--uninstall-kernels: Which action we
#   want to uxecute in the target. It is only allowed to request one execution
#   at time.

# Global variable
declare -g REMOTE_KW_DEPLOY='/opt/kw'
declare -g KW_DEPLOY_TMP_FILE='/tmp/kw'
declare -g INSTALLED_KERNELS_PATH="$REMOTE_KW_DEPLOY/INSTALLED_KERNELS"

# Processing input data
action=''
options_string=''

long_options='kw-path:,kw-tmp-files:,modules,kernel-update,uninstall-kernels,'
long_options+='list-kernels,deploy-setup,collect-info'
options="$(getopt -o '' --longoptions "$long_options" -- "$@")"
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
      INSTALLED_KERNELS_PATH="$REMOTE_KW_DEPLOY/INSTALLED_KERNELS"
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

# Load specific distro script
if [[ -f 'debian.sh' ]]; then
  . 'debian.sh' --source-only
elif [[ -f 'arch.sh' ]]; then
  . 'arch.sh' --source-only
elif [[ -f 'fedora.sh' ]]; then
  . 'fedora.sh' --source-only
else
  printf '%s\n' 'It looks like kw does not support your distro'
  exit 95 # Not supported
fi

. utils.sh --source-only

case "$action" in
  'modules')
    # shellcheck disable=SC2068
    install_modules ${action_parameters[@]}
    ;;
  'kernel_update')
    # shellcheck disable=SC2068
    install_kernel ${action_parameters[@]}
    ;;
  'list_kernels')
    # shellcheck disable=SC2068
    list_installed_kernels ${action_parameters[@]}
    ;;
  'uninstall_kernels')
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
