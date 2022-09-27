=======
kw-diff
=======

.. _diff-doc:

SYNOPSIS
========
*kw* (*df* | *diff*) [\--no-interactive] <file1> <file2>

DESCRIPTION
===========
This is a wrapper to some useful usage of the diff command. By default, it shows
diff files side-by-side in an interactive way. If instead of files, two directories
are passed to the command, it shows which files are on <folder1> but not on <folder2>.

OPTIONS
=======
\--no-interactive:
  This option displays all diff in two columns at once.
