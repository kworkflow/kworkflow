==========
kw-configm
==========

.. _configm-doc:

SYNOPSIS
========
| *kw* (*g* | *configm*) [(-s | \--save) <name> [(-d | \--description) <description>] [-f | \--force]]
| *kw* (*g* | *configm*) [-l | \--list]
| *kw* (*g* | *configm*) [\--fetch [(-o | \--output) <filename>] [-f | \--force] [\--optimize] [\--remote [<remote>:<port>]]]:
| *kw* (*g* | *configm*) [\--get <name> [-f | \--force]]
| *kw* (*g* | *configm*) [(-r | \--remove) <name> [-f | \--force]]

DESCRIPTION
===========
The **configm** command manages different versions of the project's **.config**
file. It provides the save, load, remove, and list operations of such files. By
default, if the user does not provide any parameter, the configm will list all
configs under **kw**'s management.

OPTIONS
=======
\--save <name> [-d <description>] [-f | \--force]:
  The save option creates a snapshot of the **.config** file in the current
  folder in **kw**'s management system under the specified *<name>*.
  Additionally, users can add a description by using the ``-d`` flag. Finally,
  if the user tries to add another config with a name that's already being
  managed, **kw** will issue a warning; ``-f`` will suppress such a warning.

-l, \--list:
  Lists all the **.config** file versions available. This is also the default
  behavior when no option is specified.

\--get <name> [-f | \--force]:
  Get a copy of the config file with the provided *<name>* in the current
  directory. As this operation overwrites the current **.config** file a
  warning is shown; ``-f`` will suppress such a warning and carry on any
  destructive operations.

-r <name> [-f | \--force], \--remove <name> [-f | \--force]:
  Remove config labeled with *<name>* from **kw**'s management system. As this
  operation removes a **.config** file from kw management a warning is shown;
  ``-f`` will suppress such a warning and carry on any destructive operations.

\--fetch [(-o | \--output) <filename>] [-f | \--force] [\--optimize] [\--remote [<remote>:<port>]]:
  Fetches a **.config** file from a target machine to your current directory.
  If another config is found in this directory, then **kw** will ask you
  whether you want to replace it or not; ``-f`` will suppress such a warning
  and carry on any destructive operations. ``--output`` allows you to specify
  the config file name, and ``--optimize`` will run `make localmodconfig` in
  order to generate a config that's optimized for the target machine.

EXAMPLES
========
In the following examples, we assume your **kworkflow.config** file is already
properly configured.

In case you want **kw** to save your current **.config** file, you can use::

  cd <kernel-path>
  kw g --save my_current_config

You can see the config's file maintained by **kw** with::

  kw g --list

If you want to fetch a config from a remote machine (available at
``localhost:2222``) as root, you can run::

  kw configm --fetch --remote root@localhost:2222
