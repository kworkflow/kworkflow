=========
kw-config
=========

.. _config-doc:

SYNOPSIS
========
| *kw* (*g* | *config*) [(-g | \--global)] <config.option value>
| *kw* (*g* | *config*) [(-l | \--local)] <config.option value>


DESCRIPTION
===========
The `kw config` feature is an interface to manipulate the configuration files
used by kw. This option provides a local and global reference, and it follows
the following syntax to identify the target configuration::

  <config file name>.<valid option for specific config file> <value>

OPTIONS
=======
-g, \--global:
  Set the `<config.option value>` to the global configuration.
  
-l, \--local:
  This is the default option, and it sets `<config.option value>` to the local
  configuration.

EXAMPLES
========
Suppose that you want to enable llvm compilation for your local kernel; you can
use::

  cd <kernel-path>
  kw config build.use_llvm yes

Let's say you want to enable the visual and sonorous alert. You can use::

  kw config kworkflow.alert vs
