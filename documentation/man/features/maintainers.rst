==============
kw-maintainers
==============

.. _maintainers-doc:

SYNOPSIS
========
*kw* (*m* | *maintainers*) [-a | \--authors] [-u | \--update-patch]
                           [<dir> | <file>]

DESCRIPTION
===========
Based on the Linux Kernel get_maintainers script, this command shows the
maintainers of a given Kernel module (a given file or directory). The
**\--authors** option will also print the authors of the top-level target
files (non-recursively). Files with more than one author will have their names
separated by ",". This output should not be used by scripts because some
authors include "," in their names (e.g. "Company X, Inc."). The
**\--update-patch** will update the patch *<file>*'s header with a **To:**
field with the maintainers (excluding the authors) associated with that patch.

OPTIONS
=======
-a, \--authors:
  Prints the authors of the top-level target files (non-recursively). Files
  with more than one author will have their names separated by ",".

-u, \--update-patch:
  It will include a **To:** field in the header of the patch file with the
  contact of the maintainers (excluding the authors) associated with that
  patch.

EXAMPLES
========
For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

If you want to check the maintainers::

  cd </kernel/path>
  kw m drivers/iio/dummy/iio_simple_dummy.c
