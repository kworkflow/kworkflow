============================================
  How to cross-compile your kernel with kw
============================================
.. _cross-compilation:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Cross-compilation Overview
--------------------------

From `Wikipedia <https://en.wikipedia.org/wiki/Cross_compiler>`_:

  A cross compiler is a compiler capable of creating executable code for a
  platform other than the one on which the compiler is running.

The above explanation is slightly broad; let's make it more focused on the kw
context, i.e., let's talk about cross-compiling the Linux kernel. Consider a
developer with an x86 laptop who wants to deploy a clever bug fix for an
embedded device that uses an ARM processor (e.g., a Raspberry Pi). This
developer will need to create a kernel image that runs in an ARM device from an
x86 machine. As a result, developers need a particular set of tools that enable
cross-compilation, usually called a toolchain.

Fortunately, cross-compilation is part of the kernel DNA; as a result, Linux
provides options such as `CROSS_COMPILE` and `ARCH` that allow developers to
indicate which cross-compile and architecture they want to use to build their
kernel. However, it is easy to forget to use these parameters or mess with
global variables, especially if you are doing it for the first time. For trying
to bring some quality of life improvement for kernel developers that need to
deal with cross-compilation, kw provides some simple configurations, which are
the main topic of this tutorial.

Tutorial Assumptions
--------------------

To keep things simple, we will assume a scenario where you have a development
system based on x86, and you will build a kernel for a Raspberry Pi 3/4. It is
important to highlight that we limited the example in this tutorial to keep it
short. However, kw should be able to work with any sort of cross-compilation;
at the end of this tutorial, we show other cross-compilation options.

kw configuration options
------------------------

If you are following kw tutorials, you already read :ref:`How to setup
kworkflow<setup-tutorial>`; if not, read that page and get back here later. In
that tutorial, you generated the standard config file by using ``kw init``,
inspect your `.kw/` folder, and you will find the `build.config` file, where
you will see these config variables::

  arch=x86_64
  [..]
  #cross_compile=aarch64-linux-gnu-

Those are the only two variables that you need to change in order to enable
cross-compilation. Let's say you want to work with an ARM 64 system (e.g.,
Raspberry Pi 4)::

  kw config build.arch arm64
  kw config build.cross_compile aarch64-linux-gnu-

If you want to build a 32 bits kernel for ARM, use::

  kw config build.arch arm
  kw config build.cross_compile arm-linux-gnueabihf-

I think at this point, you get the idea, right? You need to set the target
architecture and the toolchain you want to use.

.. note::
   As a user, you need to install the toolchain package and figure out the
   prefix (if necessary). At the end of this tutorial, we added some extra
   examples.

kw init template
----------------

Part of the kw philosophy is making things easier and manageable for kernel
developers; for this reason, we provide a set of init templates for some common
targets. If you use it, kw will be pre-configured to your target; you can also
use it as a start point and modify it for your needs. If you want to see all
available templates, just use::

  kw init --template

If you know the template name, you can use::

  kw init --template=rpi4-raspbian-64-cross-x86-arm

Compile!
--------

Now you can safely use your kernel config menu by using::

  kw b --menu

Kw uses the cross-compilation parameters when dealing with the kernel menu. Ok,
now, let's compile::

  kw b

Other cross-compilation examples
--------------------------------

Follows some examples of cross-compile options.

**ARM 64 bits**::

  kw config build.arch arm64
  kw config build.cross_compile aarch64-linux-gnu-

**ARM 32 bits**::

  kw config build.arch arm
  kw config build.cross_compile arm-linux-gnueabihf-

**x86 32 bits**::

  kw config build.arch i386

**PowerPC**::

  kw config build.arch sparc64
  kw config build.cross_compile gcc-11.2.0

Keep in mind
------------

Now that your fresh and new kernel image is ready to be deployed to your target
system, it is time to use ``kw deploy``. If your system follows the traditional
x86 approach, you can follow :ref:`How to Install a New Kernel<deploy-kernel>`.
However, if your target system does not follow the traditional x86 approach
(e.g., Raspberry Pi) and requires dealing with dtb files, you probably want to
check :ref:`Raspberry Pi (RPI): How to Install a New Kernel<rpi-deploy-kernel>`.
