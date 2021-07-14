========
kw-mount
========

.. _mount-doc:

SYNOPSIS
========
*kw* (*mo* | *mount*) [\--alert=(s | v | (sv | vs) | n)]

DESCRIPTION
===========
Projects that use a QEMU VM in the development cycle to host the development
environment usually require that developers use some specific commands to
manage this VM. This explains the `mount` command available in **kw**.

This mounts the QEMU image in a specific directory, based on the data available
in the **kworkflow.config** file. Notice that the configuration file has the
information about the source image and destination mount point.

.. note::
  **Only run this command after you turn off your VM**.

OPTIONS
=======

\--alert=(s | v | (sv | vs) | n):
  Defines the alert behaviour upon the command completion.
    | **s** enables sound notification.
    | **v** enables visual notification.
    | **sv** or **vs** enables both.
    | **n** (or any other option) disables notifications (this is the default).
