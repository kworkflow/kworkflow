===============================
  How to Install a New Kernel
===============================
.. _deploy-kernel:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Deploy Overview
---------------

Alright, at this point, we expect that you have already learned how to compile
the :ref:`Linux kernel from the source<buildlinux>` and :ref:`manage your config file<kernel-config-manager-tutorial>`
as described in the previous tutorials (if not, please, read those tutorials
first). Now that you know how to compile your new kernel, you probably want to
know how to install it to a Linux-based system. Don't worry, kw is here to
rescue you.

One of the most important features associated with kw is managing the
deployment of new kernels to a target machine. We have three types of target
machines

1. Remote: Any machine you can access as a root via ssh.
2. Local: A machine that you have direct access to. E.g., your laptop or
   desktop.
3. Virtual Machine (VM): A QEMU virtual machine whose image file you can
   access.

Don't worry; you will learn how to handle each of these targets!

Kw Deploy Limitations
---------------------

Let's start by setting the expectations around `kw deploy` and describing its
current limitations:

* The target machine must be Debian, Fedora or Arch Linux family (by family, we are
  talking about derivative distros). For example, Ubuntu and Mint are derivated
  from Debian, meaning that kw supports those distros.
* Right now, kw only supports the GRUB2 bootloader.

Notice that these limitations can change in the future; consider helping us to
improve this in the future.

Tutorial Assumptions
--------------------

Now that you know kw limitations, we also assume the following tasks are
completed:

* You already compiled your kernel
* You have a working `.config` file
* For deploying remotely, you need to have root access to the target machine
  via ssh.
* All commands in this tutorial must be executed inside a kernel tree.

.. note::
    We artificially defined those assumptions to make this tutorial smaller.
    Still, `kw deploy` has many features, do not hesitate to look at the man
    page more for more details.

Remote Machine Deploy
---------------------

Before trying to deploy your new kernel, let's first update
`kworkflow.config` and `remote.config` by making sure that you set the following
options correctly::

  kw remote add my-x86-test-system root@<IP or NAME>:<PORT>

.. note::
   If you don't know anything about `kworkflow.config` or `remote.config`, take
   a look at :ref:`kw configuration<setup-tutorial>` and
   :ref:`kw-remote<remote-doc>`.

Now, make sure that you can use kw to login into your target machine::

  kw ssh

If you cannot ssh to the machine, stop here and figure out why you cannot ssh
to the target machine; then, come back.

.. note::
   If it is your first time trying to ssh to the remote machine, try the
   following command inside it:
   `sed -i '/#PermitRootLogin without-password/c\PermitRootLogin yes' /etc/ssh/sshd_config && systemctl restart sshd`

If your ssh key has a password, we recommend you to use the below commands
before you try to deploy your new kernel::

  ssh-agent bash
  ssh-add ~/.ssh/id_rsa

Since this is the first time that you deploy a new kernel using kw, let's start
with a command that configures your target machine::

  kw deploy --setup

.. note::
   The steps above represent a one-time setup.

Under the hood, the command above will:

- Make sure that the ssh config is correct.
- Install required packages in the target machine.
- Install a small part of kw in the remote.

After the previous command completes, you can deploy any changes by issuing::

 kw deploy

Or, if you prefer, you can use the short version of the deploy command, which
is::

 kw d

That's it, kernel installed! You just need to reboot your target system and
select your new kernel in the GRUB2 menu.

Local Machine Deploy
--------------------

In this scenario, a target kernel might be the one in your host machine. For
example, suppose that you want to install the latest stable kernel from
Torvalds' tree in your laptop; in this case, kw deploy `\--local` is what you are
looking for.

Ok, in this case, let's start by entering in your kernel code::

 cd /path/to/kernel

Now, you can use::

 kw deploy --local

.. note::
   This requires using sudo, and you will need to select the target kernel
   after rebooting your system.

If you only deploy your kernel to a local machine, you can change the option
`default_deploy_target` to `local` in your `.kw/kworflow.config` file.

Improving your Workflow
-----------------------

If you are working on something and you need to build and deploy new kernel
versions constantly, you can speed up your workflow with these two changes:

1. Open your `.kw/kworflow.config` and set `reboot_after_deploy` to `yes`.
2. Use `kw bd` which will build your kernel and deploy after that.

In summary with these two changes, your workflow will be:

1. Change something in the kernel code.
2. Run `kw bd`.
3. Validate your change in the target machine.
4. Go back to step 1 if you are not happy with your change.

Keep in Mind
------------

Remember that we just scratched the surface in this tutorial, and you can learn
more by reading kw's man page. Additionally, consider helping us to make this
feature more generic and robust to other users.
