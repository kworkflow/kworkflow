=====
 kw
=====

--------------------------------------------
Inglorious kernel developer workflow scripts
--------------------------------------------

:Author: Rodrigo Siqueira <rodrigosiqueiramelo@gmail.com>
:Author: Matheus Tavares <matheus.bernardino@usp.br>
:Date: 2018-05-18
:Copyright: GPLv2+
:Manual section: 1
:Manual group: Kernel Workflow

SYNOPSIS
========

**kw** *COMMAND* [*OPTION* ...] 

DESCRIPTION
===========

**kw** is a set of scripts that have a single mission: reduce the overhead
related with infrastructure project setup in projects that have a similar
workflow of Linux Kernel.

COMMANDS
========

Here we have a list of commands tied to **kw**; target audiences and
functionality below group the commands. Many of the commands have default
aliases.

COMMANDS FOR USING QEMU
=======================

Projects that use QEMU in the development cycle usually requires the developers
to use some specific commands. In this section, you can find all commands
available in **kw** to manage some daily tasks related to QEMU. Notice, that
some rules are specific for Linux Kernel.

mo, mount
---------
Mount a QEMU image in a specific directory, based on the data available in the
**kworkflow.config**. Notice, that the configuration file have the information
about the source and destiny.

.. note::
  **Just run this command after you turn off your VM**.

um, umount
----------
Umount a QEMU image previously mounted with the command **kw mount**.

u, up
-----
Base on the **kworkflow.config** file, it start the QEMU VM.

s, ssh
------
Ssh into the VM.

i, install
----------
This command is dedicated to installing or updating the Linux kernel modules of
a target QEMU VM. Under the hood, it executes the mount operation, followed by
**make modules_install** with a specific target, and finally umount the QEMU
image.

.. note::
  **Just run this command after you turn off your VM**.

p, prepare
----------
**(EXPERIMENTAL)** You can put your VM in a status that is ready to work with
the prepare command. However, there are some basic steps for it to work well:

1. Add your public key in the VM in the authorized_keys file.

2. Remove the requirement for password in the VM to became root.

This command uses Ansible playbooks to deploy to put the VM in a well-known
state.

COMMANDS FOR WORKING WITH CODE
==============================

Projects that have a similar workflow of the Linux Kernel, usually have a set
of tools that simplifies part of the tasks related with the code. This section
describes some of the key features supported by **kw** to help with code.

b, build
--------
This command expects a local Makefile to build the project; it takes cares of
the correct number of jobs to be used for your machine. This command tries to
take advantage of your hardware, and try to use all of your CPU cores.

c, codestyle [*DIRECTORY|FILE*]
-------------------------------
The **checkpatch** tool is one of the most fabulous scripts provided by the
Linux Kernel to help developers follow the code style adopted by the project.
This command is a wrapper for **checkpatch**, with the goal of simplifying the
use of this tool; notice that you can specify a single file or an entire
directory.

e, explore [log] [*EXPRESSION*] [-p] [*DIRECTORY|FILE*]
-------------------------------------------------------
The *explore* command can search for string match in the repository and the git
log messages. For example, you can use **kw e functionName** to find
functionName in the source directory. You can also search the log history by
using *log* after the *e*; for instance, **kw e log STRING_MATCH**.
Additionally, you can use *-p* to see the diff in the search.

m, maintainers [*-a|--authors*] [*DIRECTORY|FILE*]
--------------------------------------------------

Get maintainers (directory or file): The option *[-a|--authors]* will print the
file author of FILE or the authors of the files under DIRECTORY
(non-recursively). Files with more than one author will have their authors
separated by ",". Use with care, because sometimes, authors include also "," in
their names (e.g. "Company X, Inc.").

OTHER COMMANDS
==============

Managing configuration files is part of many projects; this section describes a
tool available in **kw** to help developers to keep track of such config files.
Additionally, there are several other features provided by **kw** that do not
fit into the previous sections.

g, configm [*--save NAME* [*-d DESCRIPTION*][-f]]|[*--ls*]
----------------------------------------------------------

The 'configm' command is the application helps you manage your '.config' files.
It provides the operations of saving, loading, removing, and listing the user's
'.config' files.

1.  --save NAME [-d DESCRIPTION] [-f]: The save option seeks in the current
directory for a '.config' file to be added under the management of kw.  The
save option expects a name to be used as an alias for the target .config file.
If we have a local .config and a valid name, kw saves the configuration file.
Additionally, users can add a description by using *-d* flag. Finally, if the
user tries to add the same name twice kw will warn about it; the '-f' will
suppress this message.

2. --ls list all the config files available.

v, vars
-------
Show configurations being used by **kw** in the current working directory. To
do that, it examines both global and local *kworkflow.config* files.

bi
--
Build and install a new module version. It is a combination of **build** and
**install** commands.

alert=[*vs|sv,v,s,n*]
---------------------
Some commands take considerable time to execute. So **kw** gives you an option
to be notified when they finish. That way, you can do something else while they
run. The commands with this feature available are: *prepare*, *build*,
*install*, *mount*, *umount*, new and *bi*. The default option, when --alert=
is not given is n. It can be configured in the kworflow.config file. To enable
the notification, use the option *--alert=vs*. There are four options to
*--alert=*, which are *vs|sv, v, s, n*.

1. *v* enables visual notification.

2. *s* enables sound notification.

3. *vs* or *sv* enables both.

4. *n* (or any other option) disables notifications.

h, help
-------
Show basic help.

ABOUT kworflow.config
=====================

**kw** reads its configurations from two files the global
*PATH/etc/kworkflow.config* file and local *kworkflow.config* files present at
the current working directory where kw was invoked. The global
**kworkflow.config** is kept with the **kw** code and provides the overall
behavior for **kw**. The local **kworkflow.config** overrides the global; you
can have one **kworkflow.config** per project with specific configurations. In
this section, we describe the possible fields you can specify in the
configuration files.

ssh_ip=IP
---------
Set the IP to be used by the ssh. By default **kw** uses **localhost**.

ssh_port=PORT
-------------
Set the SSH port. By default **kw** uses 2222.

arch=ARCHITECTURE
-----------------
Allow you to Specify the default architecture used by **kw**. By default,
**kw** uses x86_64.

virtualizer=VIRTUALIZER
-----------------------
Defines the virtualization tool that should be used by kw. Currently, we only
support QEMU, as a result, te default is **qemu-system-x86_64**

mount_point=PATH
----------------
Defines the kw mount point, which will be used by libguestfs during the
mount/umount operation of a VM. By default, **kw** uses /home/$USER/p/mount.

qemu_hw_options=OPTIONS
-----------------------
Sets QEMU options. By default, **kw** uses
**-enable-kvm -daemonize -smp 2 -m 1024**

qemu_net_options=OPTIONS
------------------------
Defines the network configuration. By default, **kw** uses
**-net nic -net user,hostfwd=tcp::2222-:22,smb=/home/USER**

qemu_path_image=PATH
--------------------
Specify the VM image path. By default, **kw** uses
**/home/USERKW/p/virty.qcow2**

alert=[vs|s|v|n]
----------------
Default alert options, you have:

1. v: enables visual notification.

2. s enables sound notification.

3. vs or sv enables both.

4. n (or any other option) disables notifications.

sound_alert_command=COMMAND
---------------------------
Command to run for sound completion alert. By default, **kw** uses
**paplay INSTALLPATH/sounds/complete.wav &**

visual_alert_command=COMMAND
----------------------------
Command to run for visual completion alert. By default, **kw** uses
notify-send -i checkbox -t 10000 "kw" "Command: \\"$COMMAND\\" completed!"
(Note: You may use COMMAND, which will be replaced by the kw command
whose conclusion the user wished to be alerted.)

EXAMPLE
=======
For these examples, we suppose the fields in your *kworkflow.config* file is
already configured.

If you are working in a specific kernel module, and if you want to install your
recent changes in your VM you can use::

    cd /KERNEL/PATH
    kw i

.. note::
   Turn off your VM before use the *intall* command.

If you want to build and install a new module version based on the current
kernel version, you can use::

  cd /KERNEL/PATH
  kw bi

If you want to check the codestyle::

  cd /KERNEL/PATH
  kw c drivers/iio/dummy/
  kw c drivers/iio/dummy/iio_simple_dummy.c

If you want to check the maintainers::

  cd /KERNEL/PATH
  kw m drivers/iio/dummy/iio_simple_dummy.c

If you want that kw saves your current .config file, you can use::

    cd /KERNEL/PATH
    kw g --save my_current_config

You can see the config's file maintained by kw with::

  kw g --ls

You can turn on your VM with::

  kw u

After you start your VM you can ssh into it with::

  kw s

.. note::
   You have to wait for the sshd become ready.

