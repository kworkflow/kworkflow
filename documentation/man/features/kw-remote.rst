=========
kw-remote
=========

.. _remote-doc:

SYNOPSIS
========
| *kw remote* [-v | \--verbose]
| *kw remote* [--global] add <name> <user>@<remote>[:<port>]
| *kw remote* [--global] remove <name>
| *kw remote* [--global] rename <old-name> <new-name>
| *kw remote* [--global] \--list
| *kw remote* [--global] (-s | \--set-default)=<name>

DESCRIPTION
===========
Manage the set of test machines ("remotes") you want kw to have easy
access.  This feature directly interacts with kw configuration for remote
available locally at `.kw/remote.config` or globally at `~/.config/kw/remote.config`.

OPTIONS
=======
add <name> <remote-address>:
  Adds a remote named <name> for the test machine at <remote-address>. Notice
  that <remote_address> must follow the pattern `<user>@<remote>[:<port>]` where
  `remote` can be an IP or a name server and `:<port>` is optional (default port
  is 22).

remove <name>:
  Remove the remote named <name>.

rename <old-name> <new-name>:
  Rename the remote named <old-name> to <new-name>. If you try a name already
  in use, kw will fail with a message.

\--list:
  List all available remotes.

\--global:
  Force use global config file instead of the local one.

\-s=<name>, \--set-default=<name>:
  Set default remote to remote named <name>.

\-v, \--verbose:
  Be a little more verbose and show remote url after name.

EXAMPLES
========

In case you want **kw** to track a new test machine, you can use::

  cd <kernel-path>
  kw remote add origin root@my-test-machine

If you do not use port 22, you can use::

  kw remote add my-x86-test-system root@my-test-machine:5555

If you want to remove some remote::

  kw remote remove origin

If you want to rename::

  kw remote rename origina arm-device

You can also list all your available remotes via::

 kw remote --list

If you want to set the default remote::

  kw remote --set-default=new-default-remote

