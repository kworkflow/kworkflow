==========
kw-explore
==========

.. _explore-doc:

SYNOPSIS
========
*kw* (*e* | *explore*) [(-l | \--log) | (-g | \--grep) | (-a | \--all)]
                       [(-c | \--only-source) | (-H | \--only-header)] <expr>
                       [-p] [<dir> | <file>]

DESCRIPTION
===========
The **explore** command is, by default, a wrapper to git grep, searching for
string matches in files under git control or in the git log messages.
Additional parameters extended its behavior to cover all files in a directory
(whether or not controlled by git) and also to replace the search tool with the
GNU grep utility. Default usage: you can use ``kw e <function-name>`` to find
*<function-name>* in the source directory; If your string has spaces in it you
have to quote your search (e.g., ``kw e "<str1> <str2>"``).

OPTIONS
=======
-l, \--log:
  Search the git log history by using **\--log** after the **e**; for
  instance, ``kw e --log <string-match>``. Additionally, you can use **-p** to
  see the diff in the search.

-g, \--grep:
  Search for string matches in directory contents using GNU grep
  tool. For instance, ``kw e --grep <string-match>``. It also covers files
  inside .git directory.

-a, \--all:
  Search for string matches in directory contents using Git grep
  tool. For instance, ``kw e --all <string-match>``. With this, the search
  ignores files inside .git, except if it is called inside .git directory. In
  other words, if you use this option you will notice that ``git grep`` is
  used first, and then GNU grep.

-c | \--only-source:
  With this option, it is possible to show only the results from the source.

-H | \--only-header:
  With this option, it is possible to show only the results from the header.
