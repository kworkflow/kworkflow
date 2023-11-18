======
kw-ssh
======

.. _ssh-doc:

SYNOPSIS
========
| *kw* (*s* | *ssh*) [(-s | \--script) <script-path>] [\--verbose]
| *kw* (*s* | *ssh*) [(-c | \--command) <string-command>] [\--verbose]
| *kw* (*s* | *ssh*) [(-r | \--remote) <USER@IP:PORT | CONFIG_HOST_NAME>] [\--verbose]
| *kw* (*s* | *ssh*) \--send <from-local-path> [\--to <to-remote-path>] [\--verbose]
| *kw* (*s* | *ssh*) \--get <from-remote-path> [\--to <to-local-path>] [\--verbose]

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

\--verbose:
  Verbose mode is an option that causes the kw program to display debug messages to track
  its progress. This functionality is very useful during the debugging process, allowing
  you to identify possible errors more easily.

\--send <from-local-path> \--to <to-remote-path>:
  Transfers a file or directory located in *<from-local-path>* to the remote destination
  specified in *<remote-path>*. If the user does not supply the ``--to`` option, the file or
  directory specified in *<from-local-path>* will be transferred to the user's home folder
  on the remote destination.

\--get <from-remote-path> \--to <to-local-path>:
  Gets a file or directory from the specified remote path *<from-remote-path>* and saves
  it to the local machine at the specified path *<to-local-path>*. When the user does not
  specify the ``--to`` option, the default destination directory is automatically set
  to the current directory where the user is located.

EXAMPLES
========

For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

After you start your VM you can ssh into it with::

  kw s -c "dmesg -wH"
  kw s

If you want to send a file or directory to a remote machine::

  kw s --send /path/to/file/or/folder --to /tmp/

If you want to get a file or directory from a remote machine::

  kw s --get /path/to/file/or/folder --to /path/to/save
