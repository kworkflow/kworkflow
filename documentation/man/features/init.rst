=======
kw-init
=======

.. _init-doc:

SYNOPSIS
========
*kw* *init*

DESCRIPTION
===========
This command creates a **.kw** folder containing a **kworkflow.config** file in
the current kernel directory. The primary reason for running ``kw init`` is to
pick up a freshly created config file.

OPTIONS
=======
\--arch <arch>:
  Set the variable `arch` from the newly created **kworkflow.config** file.
  Before actually changing it, this option checks if *<arch>* is a valid
  architecture found in the **arch** folder from the kernel directory.

EXAMPLES
========
For these examples, we suppose that the kernel directory is your current
directory.

For initializing a **kworkflow.config** with `arch` set to arm, use::

  kw init --arch arm
