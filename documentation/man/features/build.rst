========
kw-build
========

.. _build-doc:

SYNOPSIS
========
| *kw* (*b* | *build*) [(-i | \--info)] [\--alert=(s | v | (sv | vs) | n)]
| *kw* (*b* | *build*) [(-n | \--menu)] [\--alert=(s | v | (sv | vs) | n)]
| *kw* (*b* | *build*) [(-d | \--doc)] [\--alert=(s | v | (sv | vs) | n)]
| *kw* (*b* | *build*) [\--ccache] [\--alert=(s | v | (sv | vs) | n)]
| *kw* (*b* | *build*) [(-c | \--cpu-scaling)] <percentage> [\--alert=(s | v | (sv | vs) | n)]
| *kw* (*b* | *build*) [(-w | \--warnings)] [warning-levels] [\--alert=(s | v | (sv | vs) | n)]
| *kw* (*b* | *build*) [(-s | \--save-log-to)] <path> [\--alert=(s | v | (sv | vs) | n)]
| *kw* (*b* | *build*) [\--llvm] [\--alert=(s | v | (sv | vs) | n)]

DESCRIPTION
===========
If users invoke this option without parameters, *kw* will look at the local
Makefile and, based on that, start to build the project. This option tries to
take advantage of your hardware by using the ``-j`` option with the appropriate
parameter.

This command can be used in conjunction with :ref:`deploy<deploy-doc>` by
invoking ``kw bd``.

.. note::
  This command must be run inside of a kernel tree.

OPTIONS
=======
-i, \--info:
  The info option, makes so the build information such as the kernel release
  name and the total number of modules compiled will be displayed.

-n, \--menu:
  The menu option invokes the kernel menuconfig. Notice that the default menu
  config can be changed in the **kworkflow.config** file by setting a different
  option in *menu_config*. If the user is working in a *cross-compile*
  environment, it is recommended to use this option to avoid messing with the
  config file manually.

-d, \--doc:
  The doc option provides a mechanism for building the kernel-doc; by default,
  it will build htmldocs. Users can change the default documentation output by
  changing the parameter *doc_type* in the **kworkflow.config** file.

-c, \--cpu-scaling:
  The cpu-scaling option lets the user set whichever CPU usage they want from
  their CPU, basically setting the ``-j`` flag accordingly.

\--ccache:
  This option allows the user to enable ``ccache`` usage during compilation
  tasks, which should improve compile times in subsequent compilations. If you
  want, you can set this option in the build.config file.

-w, \--warnings (1 | 2 | 3 | 12 | 13 | 23 | 123):
  This can be used to enable compilation warnings accordingly. You can set the
  default log level via `build.config` file under the option `warning_level`.
  Please check the kernel's ``make help`` for more info.

-s, \--save-log-to=path:
  This option will save the full compilation log with the enabled warnings to
  the specified path. You can set the default log path in the `build.config`
  file via `log_path` option.

\--llvm:
  This option can be set to enable the usage of the LLVM toolchain during
  compilation/linking tasks. You can enable it by default via `use_llvm` option
  in the `build.config` file.

\--alert=(s | v | (sv | vs) | n):
  Defines the alert behaviour upon the command completion.
    | **s** enables sound notification.
    | **v** enables visual notification.
    | **sv** or **vs** enables both.
    | **n** (or any other option) disables notifications (this is the default).

EXAMPLES
========
For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

For building and installing a new module version based on the current kernel
version, you can use::

  cd <kernel-path>
  kw bd

If you want that kw become more verbose about the compilation warning, you can
use::

  kw build --warnings=1

Let's say that you are doing something else and don't want that your CPU cores
to be super busy during the compilation; you can tell kw how much of the CPU
utilization you are willing to give for the kernel compilation::

  kw b --cpu-scaling=50

If you like to use ccache to build your kernel, you can use::

  kw b --ccache

If you want to ensure that your change does not add any relevant warning, you
can use::

  kw b --warnings

If you want to see other warning levels, you can change the log level by
using::

  kw b --warnings 2

Sometimes we have a lot of error message that does not fit in the terminal
buffer; in these cases it is helpful to save all logs in a file::

  kw b --warnings 123 --save-log-to=ALL_WARNINGS.log

If you want to use llvm::

  kw b --llvm
