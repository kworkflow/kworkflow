to run), you will also need to install:

* paplay
* notify-send

> For development, you will need the additional packages:

* dash
* shunit2

## Recommendations

If you want to use Qemu, we recommend the following steps:

1) Create a Qemu image in the qcow2 format;
2) Create a working directory: `/mnt/qemu`;
3) After you have your image, we recommend you to setup basic stuff (this
   can vary depending on the distribution you choose - kernel setup, ssh, etc);

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

> Finally, everytime that you want to update your `kw`, just
pull from this repository and install again (`./setup -i` removes legacy files
and installs new ones).

# Global configuration file

> All the default configurations used by kworflow can be seen at
"~/.config/kw/etc/kworkflow.config"; this config file has a comment on each
configuration option. Finally, it is important to highlight that kw loads the
default configurations; next, it tries to find a local configuration file
(detailed ahead) and overwrites the global options with the ones read from the
local config file.

# Local configuration file

> One of the features of this project is the ability to set a specific set
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
configuration file will be read. If the file does not exist, the default operation
will be used.

# How to

> If you want to know more about kw's usage and its commands, take a look at
> `documentation/man/kw.rst` or, with kw installed, run `kw man`.

# Tests

> Tests rely on `shunit2`. The `run_tests.sh` automatically uses a
> `shunit2` executable if detected in `$PATH` (as is the case for
> package distributions).  Otherwise, a `shunit2` script is expected to
> be present in `tests/` (downloadable from https://github.com/kward/shunit2).

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

> Also, if you already have the test's environment prepared but want to update
> the external files, there's an option to upgrade the environment:

```
run_tests.sh prepare -f|--force-update
```

> Please note that run_tests.sh must be run from the directory it is in, i.e.
the root of the repository. Otherwise, it may not execute properly.

# License

Kworkflow is under GPL-2.0+
