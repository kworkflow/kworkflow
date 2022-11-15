=======
kw-init
=======

.. _init-doc:

SYNOPSIS
========
| *kw* *init* [\--template[=name]]
| *kw* *init* [\--arch <name>][\--remote <user>@<ip>:<port>][\--target <target>]

DESCRIPTION
===========
This command creates a **.kw** folder containing a **kworkflow.config** file in
the current kernel directory. The primary reason for running ``kw init`` is to
pick up a freshly created config file.

OPTIONS
=======
\--template[=name]:
  kw supports some pre-defined configurations for specific targets, and users
  can select them using the template parameter. If the user does not provide
  any input, kw will show all the available templates, and the user just needs
  to pick one. If the user provides the template name, kw will use it for
  creating the local config file.

\--arch <arch>:
  Set the variable `arch` from the newly created **kworkflow.config** file.
  Before actually changing it, this option checks if *<arch>* is a valid
  architecture found in the **arch** folder from the kernel directory.

\--remote <user>@<ip>:<port>:
  Set the variables `ssh_user`, `ssh_ip`, and `ssh_port` to *<user>*, *<ip>*,
  and *<port>*, respectively.

\--target <target>:
  Set the variable `default_deploy_target` from **kworkflow.config** to
  *<target>*, which can be local or remote.

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

Kw provides some default templates that can be useful for the first setup.
Users can see and interactively select the target option by using::

  kw init --template

Alternatively, if the user knows which template they want to use::

  kw init --template=rpi4-raspbian-64-cross-x86-arm

Keep in mind that you are still able to combine other parameters with the
template feature, for example::

  kw init --template=rpi4-raspbian-64-cross-x86-arm --remote mary@localhost:1234 --target remote
