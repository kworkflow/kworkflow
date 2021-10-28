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

\--remote <user>@<ip>:<port>:
  Set the variables `ssh_user`, `ssh_ip`, and `ssh_port` to *<user>*, *<ip>*,
  and *<port>*, respectively.

\--target <target>:
  Set the variable `default_deploy_target` from **kworkflow.config** to
  *<target>*, which can be any of vm, local or remote.

\--interactive:
  Initiates interactive setup mode. In this mode, kw will suggest a series of
  configurations, explaining their purpose and recommending default options.
  User confirmation and input is required to configure every feature.
  Recommended for first time users.

EXAMPLES
========
For these examples, we suppose that the kernel directory is your current
directory.

For initializing a **kworkflow.config** with `arch` set to arm, use::

  kw init --arch arm

To initialize **kworkflow.config** with `arch` set to x86, `ssh_user` set to
john, `ssh_ip` set to localhost, and `ssh_port` set to 2222, run::

  kw init --arch x86 --remote john@localhost:2222

For initializing a **kworkflow.config** with `arch` set to arm64, `target` set to
remote, `ssh_user` mary, `ssh_ip` localhost, and `ssh_port` 1234, run::

  kw init --arch arm64 --remote mary@localhost:1234 --target remote
