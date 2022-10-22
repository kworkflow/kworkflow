=========
kw-config
=========

.. _config-doc:

SYNOPSIS
========
| *kw* (*g* | *config*)
| *kw* (*g* | *config*) [(-g | \--global)] <config.option value>
| *kw* (*g* | *config*) [(-l | \--local)] <config.option value>
| *kw* (*g* | *config*) (-s | \--show) [<config_target>]...


DESCRIPTION
===========
The `kw config` feature is an interface to manipulate the configuration files
used by kw. This option provides a local and global reference, and it follows
the following syntax to identify the target configuration::

  <config file name>.<valid option for specific config file> <value>

You can also use `kw config` to show all or some of the current configurations
displayed in a similar fashion to the `git config --list` command::

  kw (g | config) [(-s | \--show)]                    # show all configurations
  kw (g | config) (-s | \--show) <config_target>...   # show configurations of target(s) 

OPTIONS
=======
-g, \--global:
  Set the `<config.option value>` to the global configuration.
  
-l, \--local:
  This is the default option, and it sets `<config.option value>` to the local
  configuration.

-s, \--show:
  Display current configurations

EXAMPLES
========
Suppose that you want to enable llvm compilation for your local kernel; you can
use::

  cd <kernel-path>
  kw config build.use_llvm yes

Let's say you want to enable the visual and sonorous alert. You can use::

  kw config kworkflow.alert vs

If you want to display all configurations you could use::

  kw config

If you want to display deploy configurations you could use::

  kw config -s deploy
