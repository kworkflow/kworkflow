===========================
  Install and Remove `kw`
===========================

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Package Dependencies
--------------------
You have to figure out the correct package name in your distro for the
following dependencies:

* libguestfs
* Qemu
* Ansible
* Bash
* git
* python-docutils
* rsync

If you want to use the default alert system (for commands that may take longer
to run), you also have to install:

* paplay
* notify-send or dunst

For development, you will need:

* dash
* shunit2
* fish

For getting the Sphinx Documentation:

* Sphinx

Recommendations
~~~~~~~~~~~~~~~
If you want to use Qemu, we suggest the following steps:

1. Create a Qemu image;
2. Create a working directory in your host machine at: `mkdir -p ~/p/mount`;
3. After you have your working QEMU image, we recommend you to setup basic
   stuff (this can vary depending on the distribution you choose - kernel setup,
   ssh, etc);

Install
-------

Manual install
~~~~~~~~~~~~~~
In the kw's directory, type::

    ./setup.sh -i
    bash --login

This command will install `kw` in `~/.config/kw`, and append the following
lines at the end of your `.bashrc`.::

    # kw
    PATH=$PATH:/home/$USER/.config/kw
    source /home/$USER/.config/kw/src/bash_autocomplete.sh

If you use another shell (`ksh`, for example), you will need to manually add
the path to `kw` to `PATH` environment variable.

To check if the installations was ok, open another terminal and type::

    kw help

Package install
~~~~~~~~~~~~~~~

- Arch Linux:
   Available at AUR: https://aur.archlinux.org/packages/kworkflow-git/

Update
------
Every time you want to get a new version of `kw`, just pull from this
repository and install kw again (`./setup -i` removes legacy files and installs
new ones).

Remove
------
There's two way to remove kw: soft and hard way. The soft way (recommended
method) does not remove .config files under kw management and you can type::

  ./setup.sh --uninstall # or just -u

.. warning::
   Beware: that the following command is dangerous! Use it only if you are
   entirely aware of what are you doing.

If you want to remove all files under kw management, you can use::

  ./setup.sh --completely-remove

Global Configuration File
-------------------------

All the default configurations adopted by kworflow can be seen at
`~/.config/kw/etc/kworkflow.config`; this config file has a comment on each
configuration option. Finally, it is essential to highlight that kw loads the
default configurations; next, it tries to find a local configuration file
(detailed ahead) and overwrites the global options with the ones read from the
local config file. In summary, the local config has higher precedence than the
global config.

Local Configuration File
------------------------

Kw allows you to have a specific set of configuration per project. For example,
if you have a particular kernel tree named ‘drm-work’ and want a different
configuration from the default you can follow these steps:

1. `~/.config/kw/etc/kworkflow.config` to
   `/path/to/your/kernel/tree/drm-work/kworkflow.config`

.. note::
   The default name **must be** `kworkflow.config`

2. Change the options inside as you want. You can also remove settings you do
   not want to customize; In this case, kw will read them from the global
   configuration file.

3. Done! Every time you execute any command in the root dir of drm-work the
   local configuration file will be read. And if the file does not exist, the
   default settings will be used.

