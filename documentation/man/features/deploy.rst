=========
kw-deploy
=========

.. _deploy-doc:

SYNOPSIS
========
*kw* (*d* | *deploy*) [\--remote <remote>:<port> | \--local | \--vm]
                      [-r | \--reboot] [-m | \--modules] [-s | \--ls-line]
                      [-l | \--list] [-a | \--list-all]
                      [(-u | \--uninstall) <kernel-name>[,...]] [-f \--force]
                      [\--alert=(s | v | (sv | vs) | n)]

DESCRIPTION
===========
If you are in a kernel directory, this command will try to install the current
kernel version in your target machine (remote, host, and VM). If you want to
install a kernel version in a remote machine, the following steps will be
executed:

1. Prepare a local directory with all the required files;

2. Send all the files to the target machine; and

3. Execute the operations that will update the target machine.

You can specify the deploy target via command line by using the flag
**\--remote <remote>:<port>** (e.g., **\--remote 172.16.254.1:22**); however,
if you do it frequently you probably will prefer to add this information in
your local **kworkflow.config**. See the example below::

  default_deploy_target=remote
  ssh_user=root
  ssh_ip=172.16.254.1
  ssh_port=22

If you want to install a new kernel version in your host machine, you can use
the flag **\--local**; you will need to use your root password.

.. note::
  **Currently, we don't support the Kernel image update in the --vm option.
  However, you can use the remote option for a workaround this issue**.

Another typical operation when deploying a new kernel to a test machine, it is
the reboot after the update. You can explicitly say it for **kw** by adding the
flag **\--reboot**, or again, add this to the **kworkflow.config** with::

  reboot_after_deploy=yes

This can be used with conjunction the **build** command by invoking ``kw bd``.

OPTIONS
=======
\--remote <remote>:<port>:
  Deploy the Kernel image and modules to a machine in
  the network.

\--local:
  Deploy the Kernel image and modules in the host machine, you will
  need root access. :code:`kw deploy \--local` should not be executed with sudo
  or root.

\--vm:
  Deploy the Kernel image and modules to QEMU vm.

-r, \--reboot:
  Reboot machine after deploy.

-m, \--modules:
  Only install/update modules.

-l, \--list:
  List available kernels in a single column the target.

-a, \--list-all:
  List all available kernels, including the ones not installed by kw.

-s, \--ls-line:
  List available kernels separated by comma.

-u <kernel-name>[,...], \--uninstall <kernel-name>[,...]:
  Remove a single kernel or multiple kernels; for removing
  multiple kernels it is necessary to separate them with comma.

-f, \--force:
  Remove kernels even if they were not installed by kw (only valid with
  \--uninstall or -u)

\--alert=(s | v | (sv | vs) | n):
  Defines the alert behaviour upon the command completion.
    | **s** enables sound notification.
    | **v** enables visual notification.
    | **sv** or **vs** enables both.
    | **n** (or any other option) disables notifications (this is the default).

.. note::
  **Only run commands related to VM after you turn it off**. Under the hood, it
  executes the mount operation, followed by :code:`make modules_install` with a
  specific target, and finally umounts the QEMU image.

EXAMPLES
========
For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

First, if you are working in a specific kernel module, and if you want to
install your recent changes in your VM you can use::

  cd </kernel/path>
  kw d --vm --modules

.. note::
  Turn off your VM before use the **install** command.

For building and installing a new module version based on the current kernel
version, you can use::

  cd </kernel/path>
  kw bd
