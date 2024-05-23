=========================================================
kw-handle-trailer - Handle commit and patch trailer lines
=========================================================

.. _handle-trailer-doc:

SYNOPSIS
========
*kw* *commit-trailer* ([-r(<string>) | \--add-reviewed-by=(<string>)]
                      [-a(<string>) | \--add-acked-by=(<string>)]
                      [-f(<sha>) | \--add-fixes=(<sha>)])
                      [\--verbose] [<sha> | <patch>]...

DESCRIPTION
===========
This is a wrapper to some useful usage of the 'git commit --amend',
'git rebase' and the 'git interpret-trailers' commands. This kw's command
is able to perform usual operations over trailer lines of commits and patches
such as adding **Reviewed-by**, **Acked-by** or **Fixes** tags. By default,
it uses the commit currently pointed by ``HEAD`` as the target of the
operation if user does not specify one. Also, no operation is used by
default. At least one operation option must be given.

A behavior this command has is that the last option given will override
all the previous ones. For example, the following command only adds the
**Acked-by** line::

  $ kw handle-trailer -r "Reviewer Name <mail>" -a "Some Name <mail>"

To perform both operations, the user has to call this command 2 times
using different options.

OPTIONS
=======
-r, \--add-reviewed-by:
  Adds a **Reviewed-by** trailer line to either commits or patch files.
  It requires an argument to define the name of the reviewer that will
  be written.

-a, \--add-acked-by:
  Adds a **Acked-by** trailer line to either commits or patch files.
  It requires an argument to define the name of the one responsible for
  acking the changes.

-f, \--add-fixes:
  Adds a **Fixes** trailer line to either commits or patch files.
  It requires an argument, which must be a valid commit reference, to
  define the fixed commit's hash that follows this tag.

\--verbose:
  Display commands executed under the hood.

EXAMPLES
========
To add a **Reviewed-by** line to commit pointed by ``HEAD``::

  $ kw handle-trailer --add-reviewed-by "Reviewer Name <reviewer@mail.org>"

To add a **Acked-by** line to last 3 commits starting from ``HEAD``::

  $ kw handle-trailer --acked-by "Some Name <example@mail.com>" HEAD~3

To add **Fixes** line to commit pointed by ``HEAD``, which fixes another
previous commit ``90a7ba23340d``::

  $ kw handle-trailer --add-fixes 90a7ba23340d

All the above options can be used to perform operations over patch files
as well::

  $ kw handle-trailer -r "Reviewer Name <reviewer@mail.org>" example.patch

  $ kw handle-trailer -a "Some Name <example@mail.com>" example.patch

  $ kw handle-trailer -f 90a7ba23340d example.patch

This command accepts multiples arguments, which means that multiple files
(both names and globs) and commits can be passed with one single command.

To add **Acked-by** line to multiple patches::

  $ kw handle-trailer -a "Some Name <example@mail.com>" file1.patch file2.patch

To add **Reviewed-by** line to all patch files in current working directory::

  $ kw handle-trailer -r "Reviewer Name <reviewer@mail.org>" *.patch
