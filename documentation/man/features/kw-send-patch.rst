=========================================
kw-send-patch - Send patches through mail
=========================================

.. _send-patch-doc:

SYNOPSIS
========
| *kw send-patch* (-s | \--send) [\--simulate]  [-k | \--keep-patch-files] [\--private] [\--rfc] [\--to='<recipient>,...'] [\--cc='<recipient>,...'] [<rev-range>...] [-v<version>] [\--no-checkpatch] [\-- <extra-args>...]
| *kw send-patch* (-t | \--setup) [\--local | \--global] [-f | \--force] (<config> <value>)...
| *kw send-patch* (-i | \--interactive) [\--local | \--global]
| *kw send-patch* (-l | \--list)
| *kw send-patch* \--verify [\--local | \--global]
| *kw send-patch* \--template[=<template>] [-n | \--no-interactive] [\--local | \--global] [-f | \--force] [(<config> <value>)...]
| *kw send-patch* \--verbose


DESCRIPTION
===========
It is common to deal with patch submissions to a mailing list, and
``git send-email`` is one of the most famous tools for handling that. The
**send-patch** functionality aims to wrap this tool to simplify its usage and
integrate it with other **kw** functionalities.
If used inside of a linux kernel tree the send feature will auto populate the
*to* and *cc* fields of each patch file with the appropriate maintainers and
mailing lists fetched with the *get_maintainer.pl* script. It will also use
the union of the recipients of each patch as the recipients of the cover-letter.

.. note::
  You can block certain e-mail addresses from being automatically added to the
  recipients list of the patches using the *blocked_emails* option in the
  **send_patch.config** file.

.. note::
  You can add To\: and CC\: recipients to be included by default using the
  *default_to_recipients* and *default_cc_recipients* configurations, respectively,
  in the **send_patch.config** file.

.. note::
  Any option recognized by ``git send-email`` can be passed directly to it if
  placed after the double dash (``--``) argument.

.. note::
  When used inside a Linux kernel tree, **send-patch** automatically runs
  ``checkpatch.pl`` on all generated patches before sending them. Every patch
  in the series is checked and all style issues are reported before the
  operation is aborted, so you can fix everything at once instead of
  discovering problems one at a time. The check is skipped if
  ``checkpatch.pl`` is not found at ``scripts/checkpatch.pl`` in the kernel
  tree. You can pass extra options to ``checkpatch.pl`` via the
  ``checkpatch_opts`` setting in ``kworkflow.config``. To disable this
  validation for a single invocation use ``--no-checkpatch``; to disable it
  permanently set ``checkpatch_before_send=no`` in ``send_patch.config``.

OPTIONS
=======
-s, \--send:
  Send a patch by email using ``git send-email`` to the email addresses
  specified with ``--to`` and ``--cc``. You can provide *<extra-args>* to be
  passed directly to ``git send-email``, they should be placed after the double
  dash (``--``) argument. By default this function assumes these arguments to
  ``git send-email``::

    --annotate --cover-letter --no-chain-reply-to --thread

  .. note::
    You can change the default arguments used to send emails in the
    **send_patch.config** file.

\--to='<recipient>,...':
  Specify the recipients that will receive the patch via e-mail. The
  *<recipient>* list can be in any format accepted by ``git send-email``, e.g.:
  ``some@email.com`` or ``Xpto Lala <lala.xpto@mail.com>``.

\--cc='<recipient>,...':
  Specify the recipients that will receive a copy of the patch via e-mail.

\--simulate:
  Do everything without actually sending the e-mail. This is similar to
  ``git send-email``'s ``--dry-run`` option.

  .. note::
    After a ``--simulate`` run, if you edited the cover letter, it is
    automatically saved in the current directory.  You can reuse its
    contents in a future send by passing the file with ``-- cover-letter.patch``
    arguments, or by copying the contents into a new cover letter.

-k, \--keep-patch-files:
  Save the generated ``.patch`` files (and cover letter) to the current
  working directory. Useful in combination with ``--simulate`` to review
  and edit patches before sending.

  .. note::
    If ``--simulate`` is used together with ``--keep-patch-files``, the
    cover letter is saved once by the auto-save mechanism (preserving
    your edits) and the remaining patch files are saved separately by
    the ``--keep-patch-files`` logic.

  .. note::
    If sending fails and you had edited the cover letter, it is
    automatically saved to the current working directory.

\--private:
  Suppress auto generation of recipients.

\--rfc:
  Add a request for comment prefix to the e-mail's subject.

<rev-range>...:
  Specify the *<rev-range>* to be sent. The last commit is taken as the
  default.

-v<version>:
  Specify a number *<version>* for your patch.

\--no-checkpatch:
  Skip the ``checkpatch.pl`` style validation that normally runs before
  sending patches. Useful when you intentionally want to bypass the check
  for a specific invocation.

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

\--verbose:
  Verbose mode is an option that causes the kw program to display debug messages to track
  its progress. This functionality is very useful during the debugging process, allowing
  you to identify possible errors more easily.

EXAMPLES
========
If you wish to use gmail you can run the following command to setup all the
variables at once::

  kw send-patch -t --name 'Xpto Lala' --email myemail@gmail.com --smtpencryption tls \
    --smtpserver smtp.gmail.com --smtpserverport 587 --smtpuser myemail@gmail.com

To simulate sending the last commit as a patch just write::

  kw send-patch --send --simulate --to=some@email.com

Then when you are sure the command executed as expected, drop the
``--simulate`` argument to actually send the patch::

  kw send-patch --send --to=some@email.com

To send a range of commits the following can be used::

  kw send-patch  -s <SHA1>..<SHA2>

Extra arguments can be passed directly to ``git send-email`` like this::

  kw send-patch  -s --to='some@email.com' -- --thread

If you are inside of a linux kernel tree, you can send the last three commits
as a patchset to the maintainers of the subsystems and with copies to the
appropriate mailing lists using::

  kw send-patch  -s -3

To send patches previously generated by git format-patch, you can use
the *<extra-args>* options, specifiyng the files after the two dashes::

  kw send-patch --simulate -s -- *.patch

To generate patches for review before sending them::

  kw send-patch --keep-patch-files --simulate -s -3

If sending fails, a previously edited cover letter is saved automatically::

  kw send-patch -s -3
  sending failed. Cover letter saved to /path/to/cover-letter.patch

After a failed send, you can recover and reuse the cover letter::

  kw send-patch -s -3 -- /path/to/cover-letter.patch

.. note::
  A `<rev-range>` and existing patch files passed after `--` are mutually
  exclusive. Use either `-s -3` (generate from last 3 commits) or `-s -- *.patch`
  (send existing files), but not both.
