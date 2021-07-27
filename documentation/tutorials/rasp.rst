============================================================
  How to build and install a new kernel for your raspberrypi
============================================================
.. _rasp:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Get the kernel repository
-------------------------
After successfully :ref:`installing kw<install-and-remove-kw>`, it's time to
build your RaspberryPi kernel. Let's start by cloning the official repository
into your current working directory::

  git clone https://github.com/raspberrypi/linux

.. note::
    You can use the --depth=1 flag in git clone if you are only interested in
    the latest kernel, this can really speed up download times!


Then, change the current directory to the kernel repository::

  cd linux

.. note::
    From now on, all commands will assume you're in the kernel folder.

Get .config
-----------
To build the kernel, a `.config` file is necessary. This file contains
configurations about the kernel compilation process.
To generate this file, run::

  make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- bcm2709_defconfig

.. note::
    Here we are assuming a 32 bits kernel, if you wish to target an arm 64 bits
    architecture be sure to adapt the ARCH and CROSS_COMPILE variable accordingly

.. note::
    Here we are assuming a 3B RaspberryPi model, be sure to utilize a defconfig
    appropriate to your board and desired architecture, for more information you
    may wish to refer to the official RaspberryPi Foundation documentation.

kworkflow.config
----------------
As :ref:`previously mentioned kw<install-and-remove-kw>`, you may want to configure
kw. For our RaspberryPi we are interesed in a few particular important parameters::

   install_dtb=yes
   arch=arm
   cross_compile=arm-linux-gnueabihf-

With kw configured, we are ready to install our new kernel.

.. note::
    Don't forget to also configure ssh access!


Build!
------
Building and deploying the kernel now is as easy as invoking::

  kw bd --remote

Well, that's it. kw will automatically infer the number of cores to use
based on on your processor and compilation will begin!
