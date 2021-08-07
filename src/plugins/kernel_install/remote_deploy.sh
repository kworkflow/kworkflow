#!/bin/bash

# This script will be executed via ssh, because of this, I can't see any good
# reason (until now) for making things complicated here. For simplicity sake,
# this script will execute from "$HOME/kw_deploy".
#
# There are a few things to notice about this file from the kw perspective:
# 1. We need one specific file script per distro; this code is in the
#    `distro_deploy.sh` file on the remote machine. This file is copied from
#    `src/plugins/kernel_install/DISTRO_NAME`.
# 2. The script related to the distro deploy can have any function as far it
#    implements `install_modules` and `install_kernel` (I think the function
#    names already explain what it does).
#
# All specific distro script should implement the following functions:
#
# install_modules
#  params:
#    module_target="$1"
# update_boot_loader()
#  params:
#    name="$1"
#    local="$2"
#    flag="$3"
# install_kernel()
#  params:
#    name="$1"
#    reboot="$2"
#    local="$3"
#    architecture="$4"
#    flag="$5"
target_kw_deploy="$HOME/kw_deploy"
cd "$target_kw_deploy" || exit_msg 'It was not possible to move to deploy dir'

# Load specific distro script
. distro_deploy.sh --source-only
. utils.sh --source-only

case "$1" in
  --modules)
    shift # Get rid of --modules
    install_modules "$@"
    ;;
  --kernel_update)
    shift # Get rid of --kernel_update
    install_kernel "$@"
    ;;
  --list_kernels)
    shift # Get rid of --list_kernels
    list_installed_kernels "$@"
    ;;
  --uninstall_kernel)
    shift # Get rid of --list_kernels
    kernel_uninstall "$@"
    ;;
  *)
    echo "Unknown operation"
    ;;
esac
