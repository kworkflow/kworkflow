# Kworkflow

# About

> This set of scripts have a simple mission: reduce the overhead with
infrastructure setup for Linux development. We export all the scripts
functionality via bashrc, to make the commands available in any place you want
to work.

> Kworkflow stands for Kernel Workflow.

# Package Dependencies

> You have to figure out the correct package name in your distro for the
following dependencies:

* libguestfs
* Qemu
* Ansible

## Recommendations

If you want to use Qemu, we recommend the following steps:

1) Create an Qemu image as a qcow2;
2) Create a working directory: `/mnt/qemu`;
3) After you have your image, we recommend you to setup basic stuff (this
   can vary depends on the distribution you choose - kernel setup, ssh, etc);

# Install kw

> In the main directory, type:

```
./setup -i
bash --login
```

> This command will install `kw` in
`~/.config/kw`, and add the following lines at the end of
your `.bashrc`:

```
# kw
source /home/<user>/.config/kw/kw.sh
```

> To check if the installations was ok, type:

```
kw help
```

> Finally, everytime that you want to update your `kw` just
pull from this repository and install again (`./setup -i` remove legacy files
and intall new one).

# Local configuration file

> One of the features of this project, it is the ability to set a specific set
of configuration per directory. For example, if you have a particular kernel
tree named 'drm-work' and want a different configuration from the default you
can follow these steps:

1) Copy `kw.config.example` as follows:

```
cp kworkflow.config.example /path/to/your/kernel/tree/drm-work/kworkflow.config
```
Note: the default name must be `kworkflow.config`

2) Change the options inside:

```
qemu_hw_options=-enable-kvm -daemonize -m 3G -smp cores=4,cpus=4
qemu_net_options=-net nic -net user,hostfwd=tcp::2222-:22,smb=$HOME
qemu_path_image=$HOME/p/virty.qcow2
```

3) Done, every time you execute any command in the root dir of drm-work the
configuration file will be read. If file does not exists, the default operation
will be used.

# How to

> Help commands:

```
kw help
```

> Build a Kernel and install in the Qemu image:

```
kw bi
```

> Mount Qemu image to transfer data:

```
kw mount
```

> Umount Qemu image:

```
kw umount
```

> If you want to use KBUILD_OUTPUT:

```
kw export
```

> Show variable status used by `kw`:

```
kw vars
```

> Turn on vm:

```
kw up
```

> Run checkpatch in a target (directory of file):

```
kw codestyle <DIRECTORY_PATH | FILE_PATH>
```

> Get maintainers (directory or file):

```
kw maintainers <DIRECTORY_PATH | FILE_PATH>
```

> You can put your VM in a status that is ready for work with the prepare
command. However, there is some basic steps for it work well:

1. Add your public key in the VM on the authorized_keys file;
2. Remove the requirement for password in the VM to became root. Something like
  that:

```
user ALL=(ALL) NOPASSWD: ALL
```

If you have everything set, just execute the command:

```
kw prepare
```

# Tests

> To run kw's unit tests, you have to install [shunit](https://github.com/kward/shunit2) at the `tests` folder. Then just run:

```
run_tests.sh
```
