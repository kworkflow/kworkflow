==========
kw-configm
==========

.. _configm-doc:

SYNOPSIS
========
| *kw* (*g* | *configm*) [\--save <name> [-d <description>] [-f]]
| *kw* (*g* | *configm*) [-l | \--list]
| *kw* (*g* | *configm*) [\--get <name> [-f]]
| *kw* (*g* | *configm*) [(-rm | \--remove) <name> [-f]]

DESCRIPTION
===========
The **configm** command manages different versions of the project's **.config**
file. It provides the save, load, remove, and list operations of such files.

OPTIONS
=======
\--save <name> [-d <description>] [-f]:
  The save option searches the current directory for a **.config** file to be
  kept under the management of **kw**. The save option expects a name to identify
  this version of the file. Additionally, users can add a description by
  using ``-d`` flag. Finally, if the user tries to add the same name twice,
  **kw** will issue a warning; ``-f`` will suppress this message.

-l, \--list:
  Lists all the **.config** file versions available.

\--get <name> [-f]:
  Get a config file based on the *<name>* and paste it in the current
  directory. It pop-up a warning message because this operation override the
  current **.config** file. The user can suppress this warning by using ``-f``
  flag.

-rm <name> [-f], \--remove <name> [-f]:
  Remove config labeled with *<name>*. It pop-up a warning message because it
  will remove the config file from kw management. The user can suppress this
  warning by using ``-f``.

EXAMPLES
========
For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

In case you want that kw saves your current **.config** file, you can use::

  cd <kernel-path>
  kw g --save my_current_config

You can see the config's file maintained by kw with::

  kw g --list
