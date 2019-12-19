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
workflow to the Linux Kernel. It can (and should) be customized by editing the
*kworkflow.config* file, as discussed in section "ABOUT kworflow.config".

COMMANDS
========
**kw** offers several subcommands catering to different audiences and targeting
different functionality groups. Most subcommands have sane defaults.

COMMANDS FOR USING QEMU
-----------------------
Projects that use a QEMU VM in the development cycle to host the development
environment usually require that developers use some specific commands to
manage this VM. In this section, you can find all commands available in **kw**
to manage many daily tasks related to QEMU VM operation.  Notice that some
rules are specific for the Linux Kernel project.

mo, mount
~~~~~~~~~
Mount the QEMU image in a specific directory, based on the data available in
the **kworkflow.config**. Notice that the configuration file has the
information about the source image and destiny mount point.

.. note::
  **Only run this command after you turn off your VM**.

um, umount
~~~~~~~~~~
Umount the previously mounted QEMU image.

u, up
~~~~~
Start the QEMU VM based on parameters in the **kworkflow.config** file.

s, ssh [--script|-s="PATH"]|[--command|-c="COMMAND"]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Ssh into the QEMU VM. The *--script* parameter expects a bash script as a
parameter to evaluate it in the VM. The *--command* parameter expects a command
to be executed inside the QEMU VM.

i, install
~~~~~~~~~~
Installs or updates the Linux kernel modules on the QEMU VM. Under the hood, it
executes the mount operation, followed by **make modules_install** with a
specific target, and finally umounts the QEMU image.

.. note::
  **Only run this command after you turn off your VM**.

d, deploy [--remote [REMOTE:PORT]][--local] [--reboot]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
If you are in a kernel directory, this command will try to install the current
kernel version in your target machine (remote, host, and VM). If you want to
install a kernel version in a remote machine, the following steps will be
executed:

1. Prepare a local directory with all the required files;

2. Send all the files to the target machine; and

3. Execute the script that will update the target machine.

You can specify the deploy target via command line by using the flag *--remote
[REMOTE:PORT]* (e.g., *--remote 172.16.254.1:22*); however, if you do it
frequently you probably will prefer to add this information in your local
*kworkflow.config*. See the example below::

  default_deploy_target=remote
  ssh_ip=172.16.254.1
  ssh_port=22

If you want to install a new kernel version in your host machine, you can use
the flag *--local*; you will need to use your root password.

Another typical operation when deploying a new kernel to a test machine, it is
the reboot after the update. You can explicitly say it for *kw* by adding the
flag *--reboot*, or again, add this to the *kworkflow.config* with::

  reboot_after_deploy=yes

COMMANDS FOR WORKING WITH CODE
------------------------------
Projects that have a similar workflow to the Linux Kernel usually have a set of
tools that simplify part of the tasks related with the code. This section
describes some of the key features supported by **kw** to help with code.

b, build
~~~~~~~~
This command calls make on a local Makefile to build the project. It tries to
take advantage of your hardware by using the *-j* option with the appropriate
parameter.

c, codestyle [*DIRECTORY|FILE*]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The **checkpatch** tool is one of the most fabulous scripts provided by the
Linux Kernel to help developers follow the code style adopted by the project.
This command is a wrapper for **checkpatch**, with the goal of simplifying the
use of this tool; notice that you can specify a single file or an entire
directory.

e, explore [--log] [*EXPRESSION*] [-p] [*DIRECTORY|FILE*]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The *explore* command is a wrapper to git grep. It can search for string
matches in either the git repository contents or in the git log messages. For
example, you can use **kw e functionName** to find *functionName* in the source
directory; If you want to search for a composed string, you have to quote your
search (e.g., **kw e "str1 str2"**). You can also search the git log history by
using *--log* after the *e*; for instance, **kw e --log STRING_MATCH**.
Additionally, you can use *-p* to see the diff in the search.

m, maintainers [*-a|--authors*] [*DIRECTORY|FILE*]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Based on the Linux Kernel get_maintainers script, this command shows the
maintainers of a given Kernel module (a given file or directory).  The
*[-a|--authors]* option will also print the authors of the top-level target
files (non-recursively). Files with more than one author will have their names
separated by ",". This output should not be used by scripts because some
authors include "," in their names (e.g. "Company X, Inc.").

OTHER COMMANDS
--------------

This section describes a tool available in **kw** to help developers keep track
of configuration files and other features provided by **kw** that do not fit in
the previous sections.

g, configm [--save *NAME* [-d *DESCRIPTION*][-f]]|[--ls]|[--get *NAME* [-f]]|[--rm *NAME* [-f]]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The 'configm' command manages different versions of the project's '.config'
file.  It provides the save, load, remove, and list operations of such files.

1.  --save NAME [-d DESCRIPTION] [-f]: The save option searches the current
directory for a '.config' file to be kept under the management of kw. The save
option expects a name to identify this version of the file. Additionally, users
can add a description by using *-d* flag. Finally, if the user tries to add the
same name twice, **kw** will issue a warning; the '-f' will suppress this
message.

2. --ls lists all the .config file versions available.

3. --get *NAME* [-f]: Get a config file based on the *NAME* and paste it in the
current directory. It pop-up a warning message because this operation override
the current .config file. The user can suppress this warning by using -f flag.

4. --rm *NAME* [-f]: Remove config labeled with *NAME*. It pop-up a warning
message because it will remove the config file from kw management. The user can
suppress this warning by using -f.

v, vars
~~~~~~~
Shows configurations being used by **kw** in the current working directory. To
do that, it examines both global and local *kworkflow.config* files.

bi
~~
Build and install a new module version. It is a combination of the **build**
and **install** commands.

alert=[*vs|sv,v,s,n*]
~~~~~~~~~~~~~~~~~~~~~
Some commands take considerable time to execute. **kw** gives you an option to
be notified when they finish. The commands *build*, *install*, *mount*,
*umount*, new and *bi* offer this feature.

1. *v* enables visual notification.

2. *s* enables sound notification.

3. *vs* or *sv* enables both.

4. *n* (or any other option) disables notifications (this is the default).

init
~~~~
This command creates a kworkflow.config file in the current directory. The
primary reason for rerunning kw init is to pick up newly config file.

h, help
~~~~~~~
Show basic help.

ABOUT kworflow.config
=====================

**kw** reads its configuration from two files: the global
*PATH/etc/kworkflow.config* file and the local *kworkflow.config* file present
at the current working directory. The global **kworkflow.config** is a part of
the **kw** code and provides the overall behavior for **kw**. Local
**kworkflow.config** settings override global ones; you may have one
**kworkflow.config** per project. In this section, we describe the possible
fields you can specify in the configuration files.

ssh_ip=IP
---------
Sets the IP address to be used by ssh. By default **kw** uses **localhost**.

ssh_port=PORT
-------------
Sets the ssh port. By default **kw** uses 2222.

arch=ARCHITECTURE
-----------------
Allows you to specify the default architecture used by **kw**. By default,
**kw** uses x86_64.

virtualizer=VIRTUALIZER
-----------------------
Defines the virtualization tool that should be used by kw. Currently, we only
support QEMU and, as a result, the default is **qemu-system-x86_64**

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

First, if you are working in a specific kernel module, and if you want to
install your recent changes in your VM you can use::

    cd /KERNEL/PATH
    kw i

.. note::
   Turn off your VM before use the *intall* command.

For building and installing a new module version based on the current kernel
version, you can use::

  cd /KERNEL/PATH
  kw bi

For checking the code style::

  cd /KERNEL/PATH
  kw c drivers/iio/dummy/
  kw c drivers/iio/dummy/iio_simple_dummy.c

If you want to check the maintainers::

  cd /KERNEL/PATH
  kw m drivers/iio/dummy/iio_simple_dummy.c

In case you want that kw saves your current .config file, you can use::

    cd /KERNEL/PATH
    kw g --save my_current_config

You can see the config's file maintained by kw with::

  kw g --ls

You can turn on your VM with::

  kw u

After you start your VM you can ssh into it with::

  kw s -c="dmesg -wH"
  kw s

.. note::
   You have to wait for the sshd to become ready.

