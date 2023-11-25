=========================================
kw-device - Retrieve hardware information
=========================================

.. _device-doc:

SYNOPSIS
========
*kw device* [\--local | \--remote [<remote>:<port>] [\--verbose]

DESCRIPTION
===========
In order to easily retrieve basic information about the hardware of a target
machine, kw provides the **device** option, which outputs details such as:

  | - CPU architecture
  | - RAM
  | - Operating system
  | - Storage device
  | - GPU

OPTIONS
=======
\--local:
  Show hardware information from host machine.

\--remote [<remote>:<port>]:
  Show hardware information from remote machine.

\--verbose:
  Verbose mode is an option that causes the kw program to display debug
  messages to track its progress. This functionality is very useful during the
  debugging process, allowing you to identify possible errors more easily.
