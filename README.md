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
* Bash

> If you want to use the default alert system (for commands that may take longer
to run), you will also need to install:

* paplay
* notify-send

> For development, you will need the additional packages:

* dash

## Recommendations

If you want to use Qemu, we recommend the following steps:

1) Create an Qemu image as a qcow2;
2) Create a working directory: `/mnt/qemu`;
3) After you have your image, we recommend you to setup basic stuff (this
   can vary depends on the distribution you choose - kernel setup, ssh, etc);

# Install kw

> In the main directory, type:

```
./setup.sh -i
bash --login
```

> This command will install `kw` in
`~/.config/kw`, and add the following lines at the end of
your `.bashrc`:

```
# kw
PATH=$PATH:/home/<user>/.config/kw
source /home/<user>/.config/kw/src/bash_autocomplete.sh
```

> If you use another shell (`ksh`, for example), you will need to manually add
the path to `kw` to `PATH` environment variable.

> To check if the installations was ok, type:

```
kw help
```

> Finally, everytime that you want to update your `kw` just
pull from this repository and install again (`./setup -i` remove legacy files
and intall new one).

# Global configuration file

> All the default configurations used by kworflow can be seen at
"~/.config/kw/etc/kworkflow.config"; this config file has a comment on each
configuration option. Finally, it is important to highlight that kw loads de
default configurations; next, it tries to find a local configuration file
(detailed ahead) and overwrite the global option by the ones read from the
local config file.

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
kw help|h
```

> Build a Kernel and install in the Qemu image:

```
kw bi
```

> Mount Qemu image to transfer data:

```
kw mount|mo
```

> Umount Qemu image:

```
kw umount|um
```

> Show variable status used by `kw`:

```
kw vars|v
```

> Turn on vm:

```
kw up|u
```

> Run checkpatch in a target (directory of file):

```
kw codestyle|c <DIRECTORY_PATH | FILE_PATH>
```

> Get maintainers (directory or file):
> The option [-a|--authors] will print the file author of FILE_PATH or
> the authors of the files under DIRECTORY_PATH (non-recursively). Files
> with more than one author will have their authors separated by ",".
> Use with care, because sometimes, authors include also "," in their
> names (e.g. "Company X, Inc.").
```
kw maintainers|m [-a|--authors] <DIRECTORY_PATH | FILE_PATH>
```

> Search for a regex in a directory or file:

```
kw explore <EXPRESSION> <DIRECTORY_PATH | FILE_PATH>
```

> Search for a word added in a git commit:

```
kw explore log <EXRESSION> [-p] <DIRECTORY_PATH | FILE PATH>
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
kw prepare|p
```

> Some commands take considerable time to execute. So kw gives you an option to
> be notified when they finish. That way, you can do something else while they
> run. The commands with this feature available are: prepare, build, install,
> mount, umount, new and bi. To enable the notification, use the option
> "--alert=vs", e.g.:

```
kw prepare --alert=vs
```

> There are four options to --alert=, which are vs|sv, v, s, n.
- v enables visual notification
- s enables sound notification
- vs or sv enables both
- n (or any other option) disable notifications

> The default option, when --alert= is not given is n. It can be configured at
> the kworflow.config file.

# Tests

> Tests rely on `shunit2`. The `run_tests.sh` automatically uses a
> `shunit2` executable if detected in `$PATH` (as is the case for
> package distributions).  Otherwise, a `shunit2` script is expected to
> be present at `tests/` (downloadable from https://github.com/kward/shunit2).

> You can either run all tests with:

```
run_tests.sh
```

> List all available test files:

```
run_tests.sh list
```

> Or run individual test files:

```
run_tests.sh test tfile1 tfile2 tfile3
```

> Tests rely on some external files, that are downloaded automatically when you
> first try to run a test. You can, however, force `run_tests.sh` to prepare
> the environment for running tests, with:

```
run_tests.sh prepare
```

> Also, if you already have the test's environment prepared but wants to update
> the external files, there's an option to upgrade the environment:

```
run_tests.sh prepare -f|--force-update
```

> Please note that run_tests.sh must be run from the directory it is in, i.e.
the root of the repository. Otherwise, it may not execute properly.
