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

cd "$HOME/kw_deploy"

# Load specific distro script
. distro_deploy.sh --source-only

case "$1" in
  --modules)
    shift # Get rid of --modules
    install_modules "$@"
    ;;
  --kernel_update)
    shift # Get rid of --kernel_update
    install_kernel "$@"
    ;;
  *)
    echo "Unknown operation"
    ;;
esac
