======================================
kw-vm - Commands to work with QEMU VMs
======================================

.. _vm-doc:

SYNOPSIS
========
| *kw vm* (-m | \--mount) [\--alert=(s | v | (sv | vs) | n)]
| *kw vm* (-n | \--umount) [\--alert=(s | v | (sv | vs) | n)]
| *kw vm* (-u | \--up)

DESCRIPTION
===========
Developers that use QEMU Virtual Machine (VM) as their test system usually
need to use compound commands to manage their work with the VM. With this
idea in mind, kw provides a set of commands to wrap everyday tasks associated
with QEMU machines under the *vm* option.

OPTIONS
=======
-m, \--mount:
  This mounts the QEMU image in a specific directory, based on the data available
  in the **vm.config** file. Notice that the configuration file has the
  information about the source image and destination mount point.

.. note::
  **Only run this command after you turn off your VM**.

-n, \--umount:
  This unmounts the previously mounted QEMU image, based on the parameters
  available in the **vm.config** file.

-u, \--up:
  This starts the QEMU VM based on parameters in the **vm.config** file.

\--alert=(s | v | (sv | vs) | n):
  Defines the alert behaviour upon the command completion.
    | **s** enables sound notification.
    | **v** enables visual notification.
    | **sv** or **vs** enables both.
    | **n** (or any other option) disables notifications (this is the default).
