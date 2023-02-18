======================================
  How to manipulate kw config options
======================================
.. _manipulating-kw-config-file:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

kw has multiple configuration files, many associated with a specific feature
since we follow the pattern <feature-name> has <feature-name.config> file. For
example, ``kw build`` reads the ``build.config`` file to get the user's
parameters.  kw config file syntax is straightforward, it just follows::

  <option> <value>

Users can open any config file at ``.kw/`` and manually change it. However,
this is far from convenient, and manually changing a file should be avoided
since we have a dedicated command to interface with those files. This command
is the ``config`` option which you can use like this::

 kw config <config-name.option> <value>

For example, suppose you want to use the kernel ``menuconfig`` option instead
of the ``nmenu``::

 kw config build.menu_config menuconfig
