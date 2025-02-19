# kernel_install Plugin

This plugin's goal is to manage the specific details to deploy a new kernel
from kw into the specific distro. This plugin runs in two different contexts:

1. Local: In the src/deploy.sh, you'll find some places where some of this
   plugin's files are included.
2. Remote: Run this plugin inside the target machine. The file remote_deploy.sh
   is the entry point for kw in the dev machine to communicate with the remote
   machine.

In summary, this plugin manages the installation, removal, and list of kernels.

## Use of lib

TL;DL: All the code available in src/lib is copied to the remote machine;
generally, those functions can be used inside this plugin, but be careful.

The folder src/lib is copied with this plugin code to the remote machine under
the folder "${REMOTE_KW_DEPLOY}". The remote_deploy.sh does the required
modifications to ensure that the library code works as expected, but keep in
mind that some functions might be adapted to work correctly on the
remote. Ideally, try to be conservative in the use of lib functions.
