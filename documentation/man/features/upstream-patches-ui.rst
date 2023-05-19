======================
kw-upstream-patches-ui
======================

.. _upstream-patches-ui-doc:

SYNOPSIS
========
| *kw upstream-patches-ui*

DESCRIPTION
===========
The `kw upstream-patches-ui` feature provides an interface with the public mailing
lists archived on `https://lore.kernel.org`. The feature can be used to just consult
patch series from a given list, but, as it integrates with other kw features, it
simplifies the process of reviewing patch series, like:

- Applying a patch series to a git tree
- Building the series version of the kernel
- Deploying the series version of the kernel
- Replying with `Reviewed-by/Tested-by`

`kw upstream-patches-ui` provides routines to automate and simplify these actions.

EXAMPLES
========
The feature is screen-focused, and to open the UI with the public mailing lists,
just run::

  kw upstream-patches-ui
