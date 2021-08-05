============
kw-sendemail
============

.. _sendemail-doc:

SYNOPSIS
========
| *kw* (*s* | *send-email*) [-s | \--send] [\--args="<arguments>"]
| *kw* (*s* | *send-email*) [-i | \--setup]


DESCRIPTION
===========
A lot of projects require that patches be sent via email, usually through the
use of ``git send-email``. The **send-email** functionality aims to simplify
the setup and sending proccess of patches.

OPTIONS
=======
-s, \--send:
  Send email using available configurations.

-i, \--setup:
  Initialize and configure **send-email** functionality.

-a, \--args:
  Additional arguments to be passed directly into ``git send-email``.
  *<arguments>* must be within quotes.
