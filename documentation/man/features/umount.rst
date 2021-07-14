=========
kw-umount
=========

.. _umount-doc:

SYNOPSIS
========
*kw* (*um* | *umount*) [\--alert=(s | v | (sv | vs) | n)]

DESCRIPTION
===========
Projects that use a QEMU VM in the development cycle to host the development
environment usually require that developers use some specific commands to
manage this VM. This explains the `umount` command available in **kw**.

This unmounts the previously mounted QEMU image, based on the parameters
available in the **kworkflow.config** file.

OPTIONS
=======

\--alert=(s | v | (sv | vs) | n):
  Defines the alert behaviour upon the command completion.
    | **s** enables sound notification.
    | **v** enables visual notification.
    | **sv** or **vs** enables both.
    | **n** (or any other option) disables notifications (this is the default).
