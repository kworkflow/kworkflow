======
kw-ssh
======

.. _ssh-doc:

SYNOPSIS
========
| *kw* (*s* | *ssh*) [(-s | \--script) <script-path>]
| *kw* (*s* | *ssh*) [(-c | \--command) <string-command>]
| *kw* (*s* | *ssh*) [(-r | \--remote) <USER@IP:PORT | CONFIG_HOST_NAME>]

DESCRIPTION
===========
  Ssh into any machine reachable via the network. The ``--script`` parameter
  expects a bash script as a parameter to evaluate it in the target machine.
  The ``--command`` parameter expects a command to be executed inside of target
  machine.

OPTIONS
=======
-c <string-command>, \--command <string-command>:
  Receives a bash *<string-command>* to be executed remotely in the target
  machine.

-s <script-path>, \--script <script-path>:
  Receives the *<script-path>* of a local script to be run remotely.

-r <USER@IP:PORT | CONFIG_HOST_NAME>, \--remote <USER@IP:PORT | CONFIG_HOST_NAME>:
  Uses parameter to ssh into the target machine

EXAMPLES
========

For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

After you start your VM you can ssh into it with::

  kw s -c "dmesg -wH"
  kw s
