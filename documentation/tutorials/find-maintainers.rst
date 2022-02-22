===================================
  Find people to review your work
===================================
.. _find-maintainers:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Do you have a very cool patch, but you don't know to whom you can send it?
Don't worry, you just need::

  kw maintainer <path>

or even shorter::

  kw m <path>

For example, let's say that you have a fix for the amdgpu, you can use::

  kw m drivers/gpu/drm/amd/

You can also point to a specific file::

  kw m drivers/gpu/drm/amd/display/amdgpu_dm/amdgpu_dm.c
