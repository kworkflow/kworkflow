=========
kw-deploy
=========

.. _deploy-doc:

SYNOPSIS
========
*kw* (*d* | *deploy*) [\--remote <remote>:<port> | \--local]
                      [\--setup]
                      [-r | \--reboot] [\--no-reboot]
                      [-m | \--modules] [-s | \--ls-line]
                      [-l | \--list] [-a | \--list-all]
                      [(-u | \--uninstall) <kernel-name>[,...]] [-f \--force]
                      [\--alert=(s | v | (sv | vs) | n)]
                      [-p | \--create-package]
                      [(-F | \--from-package) <kw-package-path>]

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
``--remote <remote>:<port>`` (e.g., ``--remote 172.16.254.1:22``); however, if
you do this frequently you will probably prefer to add this information to your
local **kworkflow.config**. See the example below::

  default_deploy_target=remote
  ssh_user=root
  ssh_ip=172.16.254.1
  ssh_port=22

If you want to install a new kernel version in your host machine, you can use
the flag ``--local``; you will need to use your root password.

Another typical operation when deploying a new kernel to a test machine, it is
the reboot after the update. You can explicitly say it for **kw** by adding the
flag ``--reboot``, add this to the **kworkflow.config** with::

  reboot_after_deploy=yes

This can be used with conjunction the :ref:`build<build-doc>` command by
invoking ``kw bd``.

OPTIONS
=======
\--remote <remote>:<port>:
  Deploy the Kernel image and modules to a machine in
  the network.

\--local:
  Deploy the Kernel image and modules in the host machine, you will
  need root access. ``kw deploy --local`` should not be executed with sudo
  or root.

-r, \--reboot:
  Reboot machine after deploy.

\--no-reboot:
  Do not reboot machine after deploy.

\--setup:
  This command runs a basic setup in the target machine, including installing
  packages and preparing the distro for the deploy.

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
  \--uninstall or -u). Trying to remove a kernel not directly managed by
  kw can lead to system failures, and it is not recommended; only use it
  if you are sure about what you are doing.

-p, \--create-package:
  It is possible to create a kw package that can be shared with other users and
  deployed with kw. This option instructs kw to just generate the package
  without deploying it; notice that the package will be available in the
  current folder.

-F, \--from-package:
  You can use this option to deploy a custom kernel from kw package.

\--alert=(s | v | (sv | vs) | n):
  Defines the alert behaviour upon the command completion.
    | **s** enables sound notification.
    | **v** enables visual notification.
    | **sv** or **vs** enables both.
    | **n** (or any other option) disables notifications (this is the default).

.. note::
  **Only run commands related to VM after you turn it off**. Under the hood, it
  executes the mount operation, followed by ``make modules_install`` with a
  specific target, and finally umounts the QEMU image.

EXAMPLES
========
For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

First, if you are working in a specific kernel module, and if you want to
install your recent changes in your local machine you can use::

  cd <kernel-path>
  kw d --local --modules

For building and installing a new module version based on the current kernel
version, you can use::

  cd <kernel-path>
  kw bd

Now, let's say that you set up your configuration file to deploy your new
kernel to a machine reachable via ssh. You can run the following command in
order to prepare your target machine to receive your new kernel via `kw d`::

  kw deploy --setup

Alternatively, you can just run `kw d` directly; the standard behavior will
automatically run the setup operation in your first deploy.

Suppose that you want to share a specific kernel with someone else for
validation; you can generate a kw package with::

  kw deploy --create-package

The above command will create a \*.kw.tar package file that can be shared with
any other kw user. If you want to install a custom kernel from this package,
you can use::

  kw deploy --from-package 5.19.0-THIS-IS-AN-EXAMPLE+.kw.tar
