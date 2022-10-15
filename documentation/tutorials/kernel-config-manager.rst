====================================
  How to manage your .config files
====================================

.. _kernel-config-manager-tutorial:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Introduction
------------

When we work with Linux Kernel, we have a precious file named `.config`, which
describes how to compile the kernel. If you work in the kernel for a long time,
the chances are that you have multiple config files for working with different
devices. You probably end up with numerous `.config` files saved somewhere in
your hard disk, and when you need it, you take a look at this old and dusty
folder. What if we have a tool to manage these config files? What if I tell you
that we already have it under kw? Yeah, we have it, and in this tutorial, we
will learn about the `config manager` or just the kernel-config-manager feature.

Save your config file
---------------------

If you are in a kernel tree with an important `.config` file, you can save it
under kw by using the `\--save` option, which requires giving a name for your
config. For example, let's suppose that you are working in the Raspberry Pi
tree and you have a good config file; you can save it by using::

  kw kernel-config-manager --save "RASP4"

The name you used in the `\--save` option will be used later to retrieve the
config file. You probably noticed that just using the name does not describe
your config file well, and for this reason, `kernel-config-manager` also provides a
description option to better describe your config file. For example, you could
use::

  kw kernel-config-manager --save "RASP4" -d "RASP4 config file used in the project LALA"

List config files under kw
--------------------------

To show all the config files saved using kw, you just need to use::

  kw kernel-config-manager --list # kw k -l

The above command displays the configs labels and the descriptions associated
to them.

Retrieve a config file
----------------------

If you want to retrieve a specific config file, you can use the following
command::

  kw kernel-config-manager --get <label>

For example::

  kw kernel-config-manager --get RASP4

This command will first check if you already have a `.config` file in your
kernel tree; if you do, it will ask you whether to override it or not.

Conclusion
----------

The kernel-config-manager option makes it easier for you to keep track of different config
files. Another advantage of using this feature comes from the fact that the
backup option also saves these files, enabling you to easily move your config
files. Finally, under the hood, these config files are maintained by a folder structure
managed by kw. If you want to see these files, they are stored inside this folder::

  $XDG_DATA_HOME/kw/configs

Or::

  $HOME/.local/share/kw/configs

Depending on your configurations.
