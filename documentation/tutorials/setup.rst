==========================
  How to setup kworkflow
==========================

.. _setup-tutorial:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Downloading kw
--------------
First of all, let's download **kw**::

  git clone https://github.com/kworkflow/kworkflow.git

We recommend checking out the unstable branch, to get the latest version
of software::

  git checkout unstable

Alternatively, you can check if kw is available in your distribution
package manager. For example, on debian-based distributions, you can
try::

  sudo apt install kworkflow

but keep in mind that it might not get you **kw**'s latest version.

Installing kw
-------------
First, ``cd`` into the repository you cloned::

  cd kworkflow

Then install **kw**::

  ./setup.sh --install

Actually, in this folder you can see three executables: **run_tests.sh**,
**setup.sh** and **kw**.

* **run_tests.sh** is used by kw's developers to run its test suite;
* **setup.sh** is used to install kw to your system, like we just did;
* **kw** is kw's main executable, but it should normally not be called
  from this folder: **setup.sh** will alter it slightly when installing
  it in your system.

After install **kw**, you should be able to call ``kw`` directly from the
command line. For example, to display kw's help message::

  kw help

You can check out more details in :ref:`installing kw<install-and-remove-kw>`.
After installing, you should check that everything is working as expected. Try
running::

  kw version

Kw's autocompletion may not have been loaded by your shell after
installation. To load it, simply restart the shell.

Configuring kw
--------------
Kw works with three levels of configuration files: global, user, and local. The
`global` configuration file contains the default values for options and may be
in any of the folders listed in ``echo "$XDG_CONFIG_DIRS"`` where, for each
folder ``FOLDER``, the config file has to be located in
``$FOLDER/kw/kworkflow.config``. The `user` configuration file is valid for a
single user and lives in ``$XDG_CONFIG_HOME/kw/kworkflow.config``
(hint: ``$XDG_CONFIG_HOME`` is usually located at ``~/.config`` by default).

At last, the `local` option is specific to a directory. You can run::

  kw init

to create a file **kworkflow.config** in any directory and, if **kw** is called
from there, it will use that configuration file. This is useful, for example,
if you work with more than one kernel repository and would like **kw** to behave
differently for each one of them.

Actually, **kw** always parses all three levels of configurations, but local
has precedence over user, which has precedence over global, and then every
folder in the ``XDG_CONFIG_DIRS`` list is also parsed with precedence inversely
proportional to its place on the list. This means you could use a local
**kworkflow.config** to only override specific options, leaving the rest as
defined in the global configuration file.

When configuring kw, you might want to start looking at theses options:
 * ``ssh_ip`` and ``ssh_port`` define the IP address and port kw will use when
   calling ``ssh``

 * ``default_deploy_target`` defines if the deploy of a kernel build is to be
    done locally (``local``) or to a remote machine (``remote``);

 * ``alert`` defines if kw should notify you visually (``v``), with sound
   (``s``), both (``vs``) or no notification at all (``n``). Default is ``n``.

After making some changes, check that kw is incorporating them with::

  kw vars

which simply shows all the defined configuration options.

Taking a look around
--------------------
Let's see some of kw in action. ``cd`` into you kernel repository and try the
following command::

  kw m sound/core/

``kw m`` is short for ``kw maintainers``, which is a wrapper around the kernel
script **get_maintainer.pl**. It shows you who is the maintainer of a given file
or folder in the kernel repository and which are the mailing lists relevant to
that file (that is, which mailing lists should receive a patch to that file).
Now try::

  kw c drivers/gpu/drm/vkms

``kw c`` is short for ``kw codestyle``, which is a wrapper around another kernel
script: **checkpath.pl**, which checks if the code in a given file or directory
is conforming to linux's coding style.

Finally, take a glance over all of kw's options with::

  kw man

Next steps
----------
Next, you might want to :ref:`build your kernel <buildlinux>` using kw.
Then, you might want to deploy (see ``kw deploy``) it, that is, install
it in some machine. Unless you know what you are doing, you shouldn't do
that to your own main machine (locally). Instead, configure a virtual
machine following `this tutorial
<https://flusp.ime.usp.br/others/use-qemu-to-play-with-linux/>`_.
Another alternative is to use an external machine, with which you can
communicate through ssh. By the way, these three possible ways to deploy a
kernel (local, VM and remote) correspond to the options ``kw deploy``
accepts: ``--local`` and ``--remote``.
