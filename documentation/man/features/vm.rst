========
kw-vm
========

.. _vm-doc:

SYNOPSIS
========
*kw* *vm* (--mount | --umount) [\--alert=(s | v | (sv | vs) | n)]
*kw* *vm* *--up*

DESCRIPTION
===========
Projects that use a QEMU VM in the development cycle to host the development
environment usually require that developers use some specific commands to
manage the access to the VM files. For this reason, we have commands like
mount, umount, and up.

.. note::
  **Only run this command after you turn off your VM**.

OPTIONS
=======
\--mount:
  This mounts the QEMU image in a specific directory, based on the data 
  available in the **kworkflow.config** file. Notice that the configuration file
  has the information about the source image and destination mount point.

\--umount:
  This unmounts the previously mounted QEMU image, based on the parameters
  available in the **kworkflow.config** file.

\--up:
  This starts the QEMU VM based on parameters in the **kworkflow.config** file.

\--alert=(s | v | (sv | vs) | n):
  Defines the alert behaviour upon the command completion.
    | **s** enables sound notification.
    | **v** enables visual notification.
    | **sv** or **vs** enables both.
    | **n** (or any other option) disables notifications (this is the default).
