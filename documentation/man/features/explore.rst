==========
kw-explore
==========

.. _explore-doc:

SYNOPSIS
========
*kw* (*e* | *explore*) [(-l | --log) | (-g | --grep) | (-a | --all)] <expr>
                       [-p] [<dir> | <file>]

DESCRIPTION
===========
The **explore** command is, by default, a wrapper to git grep, searching for
string matches in files under git control or in the git log messages.
Additional parameters extended its behavior to cover all files in a directory
(whether or not controlled by git) and also to replace the search tool with the
GNU grep utility. Default usage: you can use :code:`kw e <function-name>` to
find *<function-name>* in the source directory; If you want to search for a
composed string, you have to quote your search (e.g.,
:code:`kw e "<str1> <str2>"`).

OPTIONS
=======
-l, \--log:
  Search the git log history by using **--log** after the **e**; for
  instance, :code:`kw e --log <srting-match>`. Additionally, you can use **-p**
  to see the diff in the search.

-g, \--grep:
  Search for string matches in directory contents using GNU grep
  tool. For instance, :code:`kw e --grep <srting-match>`. It also covers files
  inside .git directory.

-a, \--all:
  Search for string matches in directory contents using Git grep
  tool. For instance, :code:`kw e --all <srting-match>`. With this, the search
  ignores files inside .git, except if it is called inside .git directory. In
  other words, if you use this option you going feel that :code:`git grep` is
  first used, and then GNU grep.
