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
to manage many daily tasks related to QEMU VM operation. Notice that some
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

COMMANDS FOR DEPLOY NEW KERNEL IMAGE AND MODULE
-----------------------------------------------
When we develop for Linux Kernel, we continuously want to install/update the
current version of the Kernel image or modules, and this tasks may require
several steps to be accomplished. For this reason, **kw** provides an option
named **deploy** that handles attempts to handle all the complexity related to
the new Kernel installation. It is essential to highlight that we try to
support three different types of deploy: *local*, *vm*, and *remote*. When you
want to update your host machine, you can use the *local* option; if you're
going to deploy your new kernel in the VM, you can use *vm* option. Finally, we
provide the *remote* option, which is much more flexible since it uses network;
notice that this approach is the most generic one because you can use it for
*vm* and *local*.

.. note::
  **Currently, we don't support the Kernel image update in the --vm option.
  However, you can use the remote option for a workaround this issue**.

d, deploy [--remote [REMOTE:PORT]|--local|--vm] [--reboot|-r] [--modules|-m] [--ls-line|-s] [--list|-l] [--uninstall|-u KERNEL_NAME]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
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

Follows the summary of the options:

1. --remote [REMOTE:PORT]: Deploy the Kernel image and modules to a machine in
the network.

2. --local: Deploy the Kernel image and modules in the host machine, you will
need root access. 'kw deploy –local' should not be executed with sudo or root.

3. --vm: Deploy the Kernel image and modules to QEMU vm.

4. --reboot: Reboot machine after deploy.

5. --modules: Only install/update modules.

6. --list: List available kernels in a single column the target.

7. --ls-line: List available kernels separated by comma.

8. --uninstall|-u: Remove a single kernel or multiple kernels; for removing
   multiple kernels it is necessary to separate them with comma.

.. note::
  **Only run commands related to VM after you turn it off**. Under the hood, it
  executes the mount operation, followed by **make modules_install** with a
  specific target, and finally umounts the QEMU image.

COMMANDS FOR WORKING WITH CODE
------------------------------
Projects that have a similar workflow to the Linux Kernel usually have a set of
tools that simplify part of the tasks related with the code. This section
describes some of the key features supported by **kw** to help with code.

b, build [--info|-i] [--menu|-n]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
If users invoke this option without parameters, kw will look at the local
Makefile and, based on that, start to build the project. This option tries to
take advantage of your hardware by using the *-j* option with the appropriate
parameter.

By using the *--info|-i* option, building information such as the kernel
release name and the total number of modules compiled will be displayed.

Users can use *--menu|-n* for invoking kernel menuconfig. Notice that the
default menu config can be changed in the kworkflow.config file by setting a
different option in the menu_config. If the user is working in a
*cross-compile* environment, it is recommended to use this option to avoid
messing with the config file.

c, codestyle [*DIRECTORY|FILE|PATCH*]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The **checkpatch** tool is one of the most fabulous scripts provided by the
Linux Kernel to help developers follow the code style adopted by the project.
This command is a wrapper for **checkpatch**, with the goal of simplifying the
use of this tool; notice that you can specify a single file, an entire
directory, or a single patch.

e, explore [--log, -l | --grep, -g | --all, -a] [*EXPRESSION*] [-p] [*DIRECTORY|FILE*]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The *explore* command is, by default, a wrapper to git grep, searching for
string matches in files under git control or in the git log messages.
Additional parameters extended its behavior to cover all files in a directory
(whether or not controlled by git) and also to replace the search tool with the
GNU grep utility. Default usage: you can use **kw e functionName** to find
*functionName* in the source directory; If you want to search for a composed
string, you have to quote your search (e.g., **kw e "str1 str2"**).

1. --log: Search the git log history by using *--log* after the *e*; for
   instance, **kw e --log STRING_MATCH**.  Additionally, you can use *-p* to
   see the diff in the search.

2. --grep | -g: Search for string matches in directory contents using GNU grep
   tool. For instance, **kw e --grep STRING_MATCH**. It also covers files
   inside .git directory.

3. --all | -a: Search for string matches in directory contents using Git grep
   tool. For instance, **kw e --all STRING_MATCH**. With this, the search
   ignores files inside .git, except if it is called inside .git directory. In
   other words, if you use this option you going feel that `git grep` is first
   used, and then GNU grep.

m, maintainers [*-a|--authors*] [*-u|--update-patch*] [*DIRECTORY|FILE*]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Based on the Linux Kernel get_maintainers script, this command shows the
maintainers of a given Kernel module (a given file or directory).  The
*[-a|--authors]* option will also print the authors of the top-level target
files (non-recursively). Files with more than one author will have their names
separated by ",". This output should not be used by scripts because some authors
include "," in their names (e.g. "Company X, Inc."). The *[-u|--update-patch]*
will update the patch FILE's header with a *To:* field with the maintainers
(excluding the authors) associated with that patch.

SUBSYSTEM COMMANDS
------------------

Linux kernel has multiple subsystems that expose operations via sysfs or
provide mechanisms for userspace to interact with the driver. For this reason,
kw offers some options that target some specific subsystems for providing
facilities for users to interact with a particular subsystem. Currently, we
only support drm.

drm [--remote [REMOTE:PORT]\|--local] [--load-module='MODULE[:PARAM1,...][;MODULE:...]'\|--unload-module='MODULE[;MODULE;...]'\|--gui-on\|--gui-off\|--conn-available\|--modes\|--help]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This option is responsible to deal with DRM features.

1. --remote *[REMOTE:PORT]|--local*: This option specifies the target device
for the drm action, it can be a remote or local machine. If these options are
not explicitly passed via command line, kw going to take the target set in the
variable default_deploy_target (kworkflow.config) for identifying the target.
It is important to highlight that the drm feature ** does not support VM**.

2. --load-module|-lm='MODULE[:PARAM1,...][;MODULE:...]': Allow user to specify
one or more modules to be load with or without parameters. If you want to
indicate more than one module, you have to separate them using ';'.
Additionally, if users wish to provide specific parameters for the target
module, they have to use ':' and separate each parameter with ','. This option
can be combined with **--gui-on**, kw will make sure that the target module
will be load first and after that trigger the GUI.

3. --unload-module|-um='MODULE[;MODULE;...]': This option allows users to
unload one or more DRM drivers. Users can provide a single module to be
unloaded or a list separated by ';'. This command first disables the user
interface and, after that, unloads the module.

4. --gui-on: This option provides a mechanism for turn-on the GUI, by default
it uses systemctl operation; however, users are free to add any specific
command for activating their preferred GUI in the variable gui_on in the
kworkflow.config file.

5. --gui-off: Turn off the target GUI in the specified target, by default, it
uses the systemctl operation but users can change this behavior by set gui_off
with a specific command in the kworkflow.config file with the specific command.

6. --conn-available: Show all connectors available in the target machine.

7. --modes: Show all available modes per card.

OTHER COMMANDS
--------------

This section describes a tool available in **kw** to help developers keep track
of configuration files and other features provided by **kw** that do not fit in
the previous sections.

s, ssh [--script|-s="PATH"]|[--command|-c="COMMAND"]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Ssh into any machine reachable via the network. The *--script* parameter
expects a bash script as a parameter to evaluate it in the target machine. The
*--command* parameter expects a command to be executed inside of target
machine.

g, configm [--save *NAME* [-d *DESCRIPTION*][-f]]|[--list|-l]|[--get *NAME* [-f]]|[--remove|-rm *NAME* [-f]]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The 'configm' command manages different versions of the project's '.config'
file.  It provides the save, load, remove, and list operations of such files.

1.  --save NAME [-d DESCRIPTION] [-f]: The save option searches the current
directory for a '.config' file to be kept under the management of kw. The save
option expects a name to identify this version of the file. Additionally, users
can add a description by using *-d* flag. Finally, if the user tries to add the
same name twice, **kw** will issue a warning; the '-f' will suppress this
message.

2. --list|-l lists all the .config file versions available.

3. --get *NAME* [-f]: Get a config file based on the *NAME* and paste it in the
current directory. It pop-up a warning message because this operation override
the current .config file. The user can suppress this warning by using -f flag.

4. --remove|-rm *NAME* [-f]: Remove config labeled with *NAME*. It pop-up a
warning message because it will remove the config file from kw management. The
user can suppress this warning by using -f.

v, vars
~~~~~~~
Shows configurations being used by **kw** in the current working directory. To
do that, it examines both global and local *kworkflow.config* files.

clear-cache
~~~~~~~~~~~
Clean all files generated by kw.

bd
~~
Build and install a new module version. It is a combination of the **build**
and **install** commands.

alert=[*vs|sv,v,s,n*]
~~~~~~~~~~~~~~~~~~~~~
Some commands take considerable time to execute. **kw** gives you an option to
be notified when they finish. The commands *build*, *deploy*, *mount*,
*umount*, and *bd* offer this feature.

1. *v* enables visual notification.

2. *s* enables sound notification.

3. *vs* or *sv* enables both.

4. *n* (or any other option) disables notifications (this is the default).

init
~~~~
This command creates a kworkflow.config file in the current directory. The
primary reason for running kw init is to pick up a freshly created config
file.

statistics [--day [YEAR/MONTH/DAY] | --week [YEAR/MONTH/DAY] | --month [YEAR/MONTH] --year [YEAR] ]
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
kw keeps track of metadata regarding utilization of features. This data is
used to show kw usage statistics. In summary, kw keeps track of:

1. *Build*

2. *Deploy* (included list and uninstall)


For all the data tracked by kw, users can retrieve the total amount of time
spent by a specific command, the average time consumed by the feature and the
shortest and highest time required for executing the feature. All of this
information can be retrieved by the *statistics* option with the following level
of granularity:

1. *--day [YEAR/MONTH/DAY]*: display day statistics summary. Users have the
option to search a specific date by passing an argument that follows the
YEAR/MONTH/DAY format. Not passing anything and gets info about today.

2. *--week [YEAR/MONTH/DAY]*: shows the week summary. If a user does not pass
any parameter kw will show the current week statistics. However, users can pass
a random date (YEAR/MONTH/DAY) and let kw take care to provide a summary
related to the week related to the target date.

3. *--month [YEAR/MONTH]*: this option shows a report regarding a specific
month. Users can search for data related to a specific month by providing a
parameter in the YEAR/MONTH format. If the user does not pass any parameter, kw
displays the current month data.

4. *--year [YEAR]*: exhibits the current year summary if the user does not
specify a year.

df, diff [OPTIONS] FILE1 FILE2
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
This is a wrapper to some useful usage of diff command. By default, it shows
diff files side-by-side in an interactive way. This command provides the
following set of options:

1. --no-interactive: This option displays all diff in two columns at once.

2. --help: Show the help options.

h, help
~~~~~~~
Show basic help.

version, --version, -v
~~~~~~~~~~~~~~~~~~~~~~
Show kworkflow version.

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

kernel_img_name=KERNEL_IMAGE_NAME
---------------------------------
Use this option as a way to indicate to kw the kernel image name. This is the
file present in the directory `arch/*/boot/`; keep in mind that the kernel
image name might change based on the user config file or target architecture.

cross_compile=CROSS_COMPILE_TOOLCHAIN_NAME
------------------------------------------
Kw supports cross compile setup, use this option to indicate the target
toolchain.

menu_config=MENU_OPTION
-----------------------
Default kernel menu used by kw.

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

default_deploy_target
---------------------
By default, **kw** deploys in the VM; however, you can change this behavior
with this variable. The available options are: vm, local, and remote.

reboot_remote_by_default
------------------------
Reboot machine after the deploy finish

gui_on=COMMAND
--------------
This option is disabled by default, if enabled, it requires a command that
instructs kw to turn on the GUI.

gui_off=COMMAND
---------------
This option is disabled by default, if enabled, it requires a command that
instructs kw to turn off the GUI.

EXAMPLE
=======
For these examples, we suppose the fields in your *kworkflow.config* file is
already configured.

First, if you are working in a specific kernel module, and if you want to
install your recent changes in your VM you can use::

    cd /KERNEL/PATH
    kw d --vm --modules

.. note::
   Turn off your VM before use the *intall* command.

For building and installing a new module version based on the current kernel
version, you can use::

  cd /KERNEL/PATH
  kw bd

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

  kw g --list

You can turn on your VM with::

  kw u

After you start your VM you can ssh into it with::

  kw s -c="dmesg -wH"
  kw s

You can see data related to your kw usage by using the statistics option, see
some examples below::

  kw statistics --day
  kw statistics --week
  kw statistics --month
  kw statistics --year

You can also request a specific day, week, month, or year. For example::

  kw statistics --day 2020/05/12
  kw statistics --week 2020/02/29
  kw statistics --month 2020/04
  kw statistics --year 1984

If you are working with DRM drivers, you can take advantage of load and unload
commands combined with GUI control commands. For example::

  kw drm --load-module='amdgpu' --gui-on # Load a driver and trigger the user GUI
  kw drm --unload-module='amdgpu' # Turn off user GUI and unload the driver

.. note::
   You have to wait for the sshd to become ready.

