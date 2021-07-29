=========
kw-device
=========

.. _device-doc:

SYNOPSIS
========
*kw device* [\--local | \--vm | \--remote [<remote>:<port>]]

DESCRIPTION
===========
In order to easily retrieve basic information about the hardware of a target
machine, kw provides the 'device' option, which outputs details such as:
- CPU architecture
- RAM
- Operating system
- Storage device
- GPU

OPTIONS
=======
\--local:
  Show hardware information from host machine.
\--vm:
  Show hardware information from virtual machine.
\--remote [<remote>:<port>]:
  Show hardware information from remote machine.
