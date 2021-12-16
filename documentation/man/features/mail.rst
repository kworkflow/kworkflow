=======
kw-mail
=======

.. _mail-doc:

SYNOPSIS
========
| *kw mail* (-t | \--setup) [\--local | \--global] [-f | \--force] (<config> <value>)...
| *kw mail* (-i | \--interactive) [\--local | \--global]
| *kw mail* (-v | \--verify) [\--local | \--global]
| *kw mail* (-l | \--list)
| *kw mail* \--template[=<template>] [-n | \--no-interactive] [\--local | \--global] [-f | \--force] [(<config> <value>)...]

DESCRIPTION
===========
It is common to deal with patch submissions to a mailing list, and
``git send-email`` is one of the most famous tools for handling that. The
**mail** functionality aims to wrap this tool to simplify its usage and
integrate it with other **kw** functionalities.

OPTIONS
=======
-t, \--setup:
  Initialize and configure **mail** functionality. Each argument specifies a
  *<config>* to be set with the corresponding *<value>*, multiple *<config>*
  *<value>* pairs may be passed at once. Current accepted options are::

    --name           <name>
    --email          <email>
    --smtpuser       <email>
    --smtpserver     <domain>
    --smtpserverport <port>
    --smtpencryption <encryption>
    --smtppass       <password>

-i, \--interactive:
  Interactively prompt the user for the values of the options. Recommended for
  inexperienced users.

-n, \--no-interactive:
  Inhibits interactive properties, particularly from the template option.

\--local:
  Forces the commands to be run at a local scope. If nothing is passed all
  changes will be applied locally, but the listing and verification will happen
  in all scopes.

\--global:
  Same as ``--local`` but in the global scope.

-f, \--force:
  Forces the configurations to be added, regardless of conflicts with the
  current values already set in the system. Implies ``--no-interactive``.

-v, \--verify:
  Verify that all the settings needed are set and valid.

\--template[=<template>]:
  This loads the default configuration values based on the given *<template>*.
  If no template is given the user will be shown the available templates to
  choose from.

-l, \--list:
  Lists the settings that mail uses.

EXAMPLES
========
If you wish to use gmail you can run the following command to setup all the
variables at once::

  kw mail -t --name 'Xpto Lala' --email myemail@gmail.com --smtpencryption tls \
    --smtpserver smtp.gmail.com --smtpserverport 587 --smtpuser myemail@gmail.com
