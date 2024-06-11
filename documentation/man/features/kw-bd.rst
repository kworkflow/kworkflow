=======================================
kw-bd - Build the kernel and deploy it
=======================================

.. _bd-doc:

SYNOPSIS
========

*kw* (*bd*)

DESCRIPTION
===========

Kw bd is expected to run inside a kernel tree. It executes the build,
and if there are no errors, it proceeds with deploying the new kernel.

Currently, all arguments invoked along with kw bd will be redirected to kw deploy.

See the kw build and kw deploy man pages for more information.

.. note::
  This command must be run inside of a kernel tree.

EXAMPLES
========

For simply executing build and deploy use::

	kw bd

If you want to build and deploy the kernel with 
--create-package option use::

	kw bd --create-package