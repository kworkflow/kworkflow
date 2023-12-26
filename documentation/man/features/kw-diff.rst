===================
kw-diff - Diff tool
===================

.. _diff-doc:

SYNOPSIS
========
*kw* (*df* | *diff*) <file1> <file2> [\--no-interactive] [\--verbose]

DESCRIPTION
===========
This is a wrapper to some useful usage of the diff command. By default, it shows
diff files side-by-side in an interactive way. If instead of files, two directories
are passed to the command, it shows which files are on <folder1> but not on <folder2>.

OPTIONS
=======
\--no-interactive:
  This option displays all diff in two columns at once.

\--verbose:
  Verbose mode is an option that causes the kw program to display debug messages to track
  its progress. This functionality is very useful during the debugging process, allowing
  you to identify possible errors more easily.
