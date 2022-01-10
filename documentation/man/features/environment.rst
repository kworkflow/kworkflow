==============
kw-environment
==============

.. _environment-doc:

SYNOPSIS
========
| *kw* (*env* | *environment*) [(-s | \--switch) <name> [(-d | \--description) <description>]
| *kw* (*env* | *environment*) [-l | \--list]
| *kw* (*env* | *environment*) [(-c | --clean) <name>]
| *kw* (*env* | *environment*) [(-D | \--destroy) <name>]

DESCRIPTION
===========
The **environment** command switches between different outputs of the project.
It provides the switch, clean, destroy, and list operations for such outputs.
By default, if the user does not provide any parameter, the environment command
will list all existing environments under the current project.

OPTIONS
=======
-s, \--switch <name> [(-d | --description) <description>]:
  The save option searches the current directory for a **.config** file to be
  kept under the management of **kw**. The save option expects a name to identify
  this version of the file. Additionally, users can add a description by
  using ``-d`` flag. Finally, if the user tries to add the same name twice,
  **kw** will issue a warning; ``-f`` will suppress this message.

-l, \--list:
  Lists all the **.config** file versions available. If the user does not
  provide any command option, kw will assume the list option.

-c, \--clean <name>:
  Get a config file based on the *<name>* and paste it in the current
  directory. It pop-up a warning message because this operation override the
  current **.config** file. The user can suppress this warning by using ``-f``
  flag.

-D, \--destroy <name>:
  Remove config labeled with *<name>*. It pop-up a warning message because it
  will remove the config file from kw management. The user can suppress this
  warning by using ``-f``.


EXAMPLES
========
For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

In case you want that kw saves your current **.config** file, you can use::

  cd <kernel-path>
  kw env --switch kunit_build

You can see the config's file maintained by kw with::

  kw g --list

If you want to fetch a .config file from a remote machine at localhost:2222 with
user root, then you can run::

  kw configm --fetch --remote root@localhost:2222
