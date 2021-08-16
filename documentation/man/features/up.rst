=====
kw-up
=====

.. _up-doc:

SYNOPSIS
========
*kw* (*u* | *up*)

DESCRIPTION
===========
Projects that use a QEMU VM in the development cycle to host the development
environment usually require that developers use some specific commands to
manage the access to the VM files. For this reason, we have commands like
:ref:`mount<mount-doc>`, :ref:`umount<umount-doc>` and **up**.

This starts the QEMU VM based on parameters in the **kworkflow.config** file.
