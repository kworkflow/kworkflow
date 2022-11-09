===================================================
  Raspberry Pi (RPI): How to Install a New Kernel
===================================================
.. _rpi-deploy-kernel:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Tutorial Assumptions
--------------------

For simplicity's sake, this tutorial will assume that you already read
:ref:`How to cross-compile your kernel with kw<cross-compilation>` and
:ref:`How to Install a New Kernel<deploy-kernel>`. If not, get back here later;
we will wait for you :)

Anyway, we also assume the following tasks are completed:

* You already compiled your kernel
* You have a working `.config` file
* You will use remote deploy. Remember, to deploy remotely, you need to
  have root access to the target machine via ssh.
* All commands in this tutorial must be executed inside a kernel tree. If you want to work with Raspberry Pi, use this `repository <https://github.com/raspberrypi/linux>`.

We also assume that you have a Raspberry Pi (RPI) with Rasbian (it could be 32
or 64 bits), but keep in mind that the steps described here are generic, and we
just decided to focus on this device to have a way to provide some practical
examples.

DTB file and kworkflow.config
-----------------------------

Some architectures require Device Tree Binary (dtb) and Device Tree Binary
Overlay (dtbo) files, and Raspberry Pi falls into this category. We usually
need to add these files in a specific location for a functional boot. For
example, in the case of RPI 4 32 bits, it should be under the ``/boot`` folder,
and for RPI 4 64 bits, it is ``/boot/broadcom``. However, these locations may
vary, so we need to tell kw how to handle these files, but don't worry, this is
a trivial task. Open your ``.kw/deploy.config`` and search for::

  dtb_copy_pattern=

Use this parameter to configure how kw will handle the dtb files. You have
three different options:

1. Empty: It will assume ``*.dtb``, which means that kw will copy all dtb files
to the target ``/boot`` folder. For example, RPI 4 32 bits requires this
option.

2. Folder pattern: You can specify something like
``dtb_copy_pattern=broadcom/*``, which means kw will copy all dtb files inside
the broadcom folder. This is the required option for RPI 4 64 bits.

3. Multiple folder copy: Finally, you can tell kw that you want to copy
multiple folders by using a pattern like this
``dtb_copy_pattern=broadcom,rockchip,arm``.

As you can see, kw is really flexible about handling the dtb files.

Use a default kw config template for RPI
----------------------------------------

For RPI developers, kw provides some useful templates that already setup your
config in a convenient way. If you want to deploy your kernel for an RPI 32
bits, you can use the following template::

  kw init --template=rpi4-raspbian-32-cross-x86-arm

Or if you want to deploy your kernel to an RPI 4 64 bits, you can use::

  kw init --template=rpi4-raspbian-64-cross-x86-arm

Build and deploy
----------------

.. note::
   The RPI needs to keep the modules after they are installed, so to have a
   proper deploy on the RPI is ideal to set ``strip_modules_debug_option=no``
   on ``.kw/deploy.config``.

At this point, we suppose that you already compiled your kernel and added a
very cool suffix name to your image. Additionally, we presume that your target
is a machine that you have ssh access as root. For now, you can run the
glorious build and deploy::

  kw bd

Other kw deploy features
------------------------

Remember that kw deploy provides many other features to handle your custom
kernel. For example, if you want to list all custom kernels that you installed
in your system, just use::

  kw deploy --list

Or if you want to remove some specific kernel::

  kw deploy --uninstall KERNEL_NAME

Keep in Mind
------------

In this tutorial, we used RPI 4 as a use case in order to make some of the new
concepts more practical. Nevertheless, you should be able to setup kw to handle
dtb files that need to be deployed in various ways. Finally, if this step does
not work in your custom system, consider improving kw to support your target
system workflow; patches are always welcome.
