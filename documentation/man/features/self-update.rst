==============
kw-self-update
==============

.. _self-update-doc:

SYNOPSIS
========
| *kw* (*u* | *self-update*)
| *kw* (*u* | *self-update*) [(-u | --unstable)]
| *kw* (*u* | *self-update*) [(-h | --help)]

DESCRIPTION
===========
The `kw self-update` feature facilitates the process of updating kw.

By just running `kw self-update`, the user can update `kw` based on the
master or unstable branch in a simple way.

By default, `kw self-update` updates `kw` based on the master branch. If
the user wants to update based on the unstable branch, the `--unstable`
option should be used.

OPTIONS
=======
-u, \--unstable:
  Update kw based on the unstable branch

\--help:
  Show this man page

EXAMPLES
========
Updating based on the master branch::

  kw self-update

Updating based on the unstable branch::

  kw self-update --unstable