========================================================================
kw-patch-hub - Terminal UI to interact with patches from lore.kernel.org
========================================================================

.. _patch-hub-doc:

SYNOPSIS
========
| *kw patch-hub*

DESCRIPTION
===========
The `kw patch-hub` feature provides a TUI (*Terminal User Interface*) that
streamlines the interaction of Linux developers with patches archived on
lore.kernel.org. The feature can be used to just consult patchsets from a
target list, but, as it integrates with other kw features, it simplifies the
process of reviewing patchset, like:

- Applying a patchset to a git tree
- Building the patchset version of the Linux kernel
- Deploying the patchset version of the Linux kernel
- Replying with `Reviewed-by/Tested-by` tags

`kw patch-hub` is an integrated interface to automate and simplify these
actions.

.. note::
  `patch-hub` is a `standalone sub-project
  <https://github.com/kworkflow/patch-hub>`_ from the kw organization and it is
  under heavy development. We welcome contributions!

EXAMPLES
========
To launch `kw patch-hub` simply run::

  kw patch-hub
