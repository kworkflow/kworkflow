==========
kw-configm
==========

.. _configm-doc:

SYNOPSIS
========
| *kw* (*g* | *configm*) [(-s | \--save) <name> [(-d | \--description) <description>] [-f | \--force]]
| *kw* (*g* | *configm*) [-l | \--list]
| *kw* (*g* | *configm*) [\--get <name> [-f | \--force]]
| *kw* (*g* | *configm*) [(-r | \--remove) <name> [-f | \--force]]

DESCRIPTION
===========
The **configm** command manages different versions of the project's **.config**
file. It provides the save, load, remove, and list operations of such files.

OPTIONS
=======
\--save <name> [-d <description>] [-f | \--force]:
  The save option searches the current directory for a **.config** file to be
  kept under the management of **kw**. The save option expects a name to identify
  this version of the file. Additionally, users can add a description by
  using ``-d`` flag. Finally, if the user tries to add the same name twice,
  **kw** will issue a warning; ``-f`` will suppress this message.

-l, \--list:
  Lists all the **.config** file versions available.

\--get <name> [-f | \--force]:
  Get a config file based on the *<name>* and paste it in the current
  directory. It pop-up a warning message because this operation override the
  current **.config** file. The user can suppress this warning by using ``-f``
  flag.

-r <name> [-f | \--force], \--remove <name> [-f | \--force]:
  Remove config labeled with *<name>*. It pop-up a warning message because it
  will remove the config file from kw management. The user can suppress this
  warning by using ``-f``.

\--fetch [(-o | --output) <filename>] [-f | --force] [--optimize] [--remote [<remote>:<port>]]:
  This option fetches a .config file from a target machine to your current
  directory. If another .config is found in this directory, then it will ask you
  whether you want to replace it or not. If you use the force option, the
  .config file will be overwritten without any warnings. By using the output
  option, you can specify the config file name. With the optimize option,
  `make localmodconfig` will be run to generate an optimized version of a
  previously fetched .config file.


EXAMPLES
========
For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

In case you want that kw saves your current **.config** file, you can use::

  cd <kernel-path>
  kw g --save my_current_config

You can see the config's file maintained by kw with::

  kw g --list

If you want to fetch a .config file from a remote machine at localhost:2222 with
user root, then you can run::

  kw configm --fetch --remote root@localhost:2222