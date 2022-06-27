============================================================
  How to build the Linux kernel for an x86_64 architecture
============================================================
.. _buildlinux:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Get a Linux repository
----------------------
After successfully :ref:`installing kw<install-and-remove-kw>`, it's time to
build the Linux kernel using it. Let's start by cloning the Linux repository
from Torvalds into our current working directory::

  git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git

Then, change the current directory to the Linux repository::

  cd linux

.. note::
    From now on, all commands will assume you're in the kernel folder.

Get .config
-----------
To build the kernel, a **.config** file is necessary. This file contains
configurations about the kernel compilation process.
To retrieve this file from your computer, run either::

  cp /boot/config-`uname -r` .config

Or::

  zcat /proc/config.gz > .config

.. note::
    Get the **.config** file from the same Linux distribution you plan on using
    the customized kernel in.

Change .config a bit
--------------------
A small modification you can make in the **.config** file is changing the kernel
release name. To do that, run::

  kw build --menu

Or its shorter form::

  kw b -n

The default menu config option is set in the **kworkflow.config** file as
nconfig, but it can be changed, for instance, to menuconfig, or whichever you
prefer. To change this option, you can use::

  kw config build.menu_config menuconfig

After running the command above, go to *General setup*, then *Local version -
append to kernel release*, choose any name you like, save the new configuration
and exit the menu.

.. note::
  You can read more about the **kworkflow.config** file in our
  :ref:`manual<manual>`.

Build!
------
Building the kernel now is as easy as invoking::

  kw build

And it can be even simpler by just running::

  kw b

Well, that's it. kw will automatically infer the number of job slots for
compiling based on the number of cores of your machine (i.e. when running make
``-j<number>``, *<number>* is an integer that specifies the number of processes
that will run at the same time), and compilation will begin!
