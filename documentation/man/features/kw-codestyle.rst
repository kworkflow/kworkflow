=================================
kw-codestyle - Checkpatch wrapper
=================================

.. _codestyle-doc:

SYNOPSIS
========
| *kw* (*c* | *codestyle*)
| *kw* (*c* | *codestyle*) [<directory> | <file> | <patch>]
| *kw* (*c* | *codestyle*) [\--verbose] [<directory> | <file> | <patch>]

DESCRIPTION
===========
The **checkpatch** tool is one of the most fabulous scripts provided by the
Linux Kernel to help developers follow the code style adopted by the project.
This command is a wrapper for **checkpatch**, with the goal of simplifying the
use of this tool; notice that you can specify a single file, an entire
directory, or a single patch.

OPTIONS
=======
<directory>, <file>, <patch>:
  Define which files to run checkpatch on. Defaults to current working
  directory if it is a kernel tree.

\--verbose:
  Display commands executed under the hood.

EXAMPLES
========
For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

For checking the code style::

  cd <kernel-path>
  kw c drivers/iio/dummy/
  kw c drivers/iio/dummy/iio_simple_dummy.c
