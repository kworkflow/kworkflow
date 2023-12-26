===============================================
kw-patch-hub - UI with lore.kernel.org archives
===============================================

.. _patch-hub-doc:

SYNOPSIS
========
| *kw patch-hub*

DESCRIPTION
===========
The `kw patch-hub` feature provides an interface with the public mailing lists
archived on `https://lore.kernel.org`, focusing on patch series. The feature can
be used to just consult patch series from a given list, but, as it integrates
with other kw features, it simplifies the process of reviewing patch series,
like:

- Applying a patch series to a git tree
- Building the series version of the kernel
- Deploying the series version of the kernel
- Replying with `Reviewed-by/Tested-by`

`kw patch-hub` provides routines to automate and simplify these actions.

EXAMPLES
========
The feature is screen-focused, and to open the UI with the public mailing lists,
just run::

  kw patch-hub
