=======
kw-mail
=======

.. _mail-doc:

SYNOPSIS
========
| *kw mail* (-s | \--send) [\--simulate] [\--private] [\--rfc] [\--to='<recipient>,...'] [\--cc='<recipient>,...'] [<rev-range>...] [-v<version>] [\-- <extra-args>...]
| *kw mail* (-t | \--setup) [\--local | \--global] [-f | \--force] (<config> <value>)...
| *kw mail* (-i | \--interactive) [\--local | \--global]
| *kw mail* (-l | \--list)
| *kw mail* \--verify [\--local | \--global]
| *kw mail* \--template[=<template>] [-n | \--no-interactive] [\--local | \--global] [-f | \--force] [(<config> <value>)...]

DESCRIPTION
===========
It is common to deal with patch submissions to a mailing list, and
``git send-email`` is one of the most famous tools for handling that. The
**mail** functionality aims to wrap this tool to simplify its usage and
integrate it with other **kw** functionalities.
If used inside of a linux kernel tree the send feature will auto populate the
*to* and *cc* fields of each patch file with the appropriate maintainers and
mailing lists fetched with the *get_maintainer.pl* script. It will also use
the union of the recipients of each patch as the recipients of the cover-letter.

.. note::
  You can block certain e-mail addresses from being automatically added to the
  recipients list of the patches using the *blocked_emails* option in the
  *kworkflow.config* file.

.. note::
  Any option recognized by ``git send-email`` can be passed directly to it if
  placed after the double dash (``--``) argument.

OPTIONS
=======
-s, \--send:
  Send a patch by email using ``git send-email`` to the email adresses
  specified with ``--to`` and ``--cc``. You can provide *<extra-args>* to be
  passed directly to ``git send-email``, they should be placed after the double
  dash (``--``) argument. By default this function assumes these arguments to
  ``git send-email``::

    --annotate --cover-letter --no-chain-reply-to --thread

  .. note::
    You can change the default arguments used to send emails in the
    *kworkflow.config* file.

\--to='<recipient>,...':
  Specify the recipients that will receive the patch via e-mail. The
  *<recipient>* list can be in any format accepted by ``git send-email``, e.g.:
  ``some@email.com`` or ``Xpto Lala <lala.xpto@mail.com>``.

\--cc='<recipient>,...':
  Specify the recipients that will receive a copy of the patch via e-mail.

\--simulate:
  Do everything without actually sending the e-mail. This is similar to
  ``git send-email``'s ``--dry-run`` option.

\--private:
  Supress auto generation of recipients.

\--rfc:
  Add a request for comment prefix to the e-mail's subject.

<rev-range>...:
  Specify the *<rev-range>* to be sent. The last commit is taken as the
  default.

-v<version>:
  Specify a number *<version>* for your patch.

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

\--verify:
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

To simulate sending the last commit as a patch just write::

  kw mail --send --simulate --to=some@email.com

Then when you are sure the command executed as expected, drop the
``--simulate`` argument to actually send the patch::

  kw mail --send --to=some@email.com

To send a range of commits the following can be used::

  kw mail -s <SHA1>..<SHA2>

Extra arguments can be passed directly to ``git send-email`` like this::

  kw mail -s --to='some@email.com' -- --thread

If you are inside of a linux kernel tree, you can send the last three commits
as a patchset to the maintainers of the subsystems and with copies to the
appropriate mailing lists using::

  kw mail -s -3
