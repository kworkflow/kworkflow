================================================
  Check if your code follows kernel code style
================================================
.. _codestyle:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

The Linux kernel has a very clear and well-defined code style automated by a
tool named `checkpatch.pl`. You can use this script to check a file or a patch,
and it has a large number of options. Although this tool has powerful features,
it requires multiple parameters for different contexts, which can make it
tedious to use.

kw tries to deliver a unified development experience in the same way that it
provides a simple interface for developers to access some supported tools by
the kernel. For this reason, kw provides the ``kw codestyle <target>`` feature,
which will identify if the target is a folder, file, or patch with the same
command line. For example, you can point to a folder::

 kw codestyle drivers/gpu/drm/amd/display/amdgpu_dm/

or you can point it to a file::

 kw codestyle drivers/gpu/drm/amd/display/amdgpu_dm/amdgpu_dm.c

That is all you need to know about kernel code style checking under kw
management.
