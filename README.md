# Kworkflow

# About

> This set of scripts have a simple mission: reduce the overhead with
infrastructure setup for Linux development. We export all the scripts
functionality via bashrc, to make the commands available in any place you want
to work.

> Kworkflow stands for Kernel Workflow.

# Prerequisites:

* We only support Qemu and local workflow;
* Install nbd module and qemu-nbd;
* If you want to use Qemu, you have to create a Qemu image as a qcow2 and save
  it in `$HOME/p/virty.qcow2`.

## Recommendations

If you want to use Qemu, we recommend the following steps:

1) Create an Qemu image as a qcow2;
2) Create a working directory: `/mnt/qemu`;
3) After you have your image, we recommend you to setup basic stuff (this
   can vary depends on the distribution you choose - kernel setup, ssh, etc);

# Install kworkflow

> In the main directory, type:

```
./setup -i
bash --login
```

> This command will install `kworkflow` in
`~/.config/kworkflow`, and add the following lines at the end of
your `.bashrc`:

```
# kworkflow
source /home/<user>/.config/kworkflow/kworkflow.sh
```

> To check if the installations was ok, type:

```
kworkflow help
```

> Finally, everytime that you want to update your `kworkflow` just
pull from this repository and install again (`./setup -i` remove legacy files
and intall new one).

# Local configuration file

> One of the features of this project, it is the ability to set a specific set
of configuration per directory. For example, if you have a particular kernel
tree named 'drm-work' and want a different configuration from the default you
can follow these steps:

1) Copy `kworkflow.config.example` as follows:

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
kworkflow help
```

> Build a Kernel and install in the Qemu image:

```
kworkflow bi
```

> Mount Qemu image to transfer data:

```
kworkflow mount
```

> Umount Qemu image:

```
kworkflow umount
```

> If you want to use KBUILD_OUTPUT:

```
kworkflow export
```

> Show variable status used by `kworkflow`:

```
kworkflow vars
```

> Turn on vm:

```
kworkflow up
```

> Run checkpatch in a target (directory of file):

```
kworkflow codestyle <DIRECTORY_PATH | FILE_PATH>
```

> Get maintainers (directory or file):

```
kworkflow maintainers <DIRECTORY_PATH | FILE_PATH>
```
