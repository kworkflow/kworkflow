========
kw-debug
========

.. _debug-doc:

SYNOPSIS
========
| *kw* *debug* [(-e | \--event) <event-syntax> [(-d | \--disable)] [(-k | \--history)] [(-f | \--follow)] ]
| *kw* *debug* [(-t | \--ftrace)]
| *kw* *debug* [(-g | \--dmesg) [(-f | \--follow)] [(-c | \--cmd) "COMMAND"] ]
| *kw* *debug* [(-l | \--list)[=(<ftrace> | <events>)]] [(-e | \--event)]
| *kw* *debug* [(-h | \--help)]

DESCRIPTION
===========
Linux kernel provides multiple mechanisms for debugging; in particular, kw
tries to simplify the debug process for three of them: events, ftrace, and
dmesg. All the debug options intend to support remote and local targets.

EVENTS TRACE
------------

In order to take advantage of the event feature wrapped inside kw, it is
necessary to follow the small syntax described below:

 **event[:<specific-event[[filter]]>[,<specific-event[[filter]]>,...]][;event...]**

Let's detail the above syntax step-by-step:

* *event*: It should be an event available in the kernel, e.g.,
  */sys/kernel/debug/tracing/events/amdgpu_dm*. If you don't know what kind of
  events you have available for your debug task, you can use the list option.
  Notice that users can specify multiple events by separating them with ';'.

* *specific-event*: Inside each event (informed via event), users can specify
  which specific event they want to check. For example, inside *amdgpu_dm* we
  have *amdgpu_dm_dc_clocks_state*, which can be translated to
  "amdgpu_dm:amdgpu_dm_dc_clocks_state".

* *filter*: Usually, each event supports filters and users can specify it via
  kw debug by using the filter syntax. For example:
  *amdgpu_dm:amdgpu_dm_dce_clocks_state[sclk_khz > 0]*.

Notice that users have a flexible way of defining the events they want to trace
by using the event syntax. Additionally, the debug option provides other
features that simplify the work with debug data from Linux Kernel.

FTRACE TRACE
------------

The kernel provides a feature named ftrace that enables developers to have a
high-level view of the code execution. Kw wraps this feature under the
`\--ftrace` option. If the user does not provide any output, kw will display
all available ftrace options.

The ftrace debug feature provides different trace algorithms (you can see all
options by using the `\--list` option) and simplifies the output. The
`\--ftrace` option wraps these two configurations by using the following
syntax:

 **ftrace_type[:filter[,filter, ...]]**

Let's take a close look at the above syntax:

* *ftrace_type*: Use this option to indicate the ftrace algorithm that you
  want to use.

* *filter*: Ftrace allows users to filter its output. This option sets
  specific function names or even a pattern filtered by ftrace; notice that you
  can pass multiple filters separated by commas.

DMESG LOG
---------

Dmesg log is vital for debugging issues in the Linux kernel, and kw debug
provides the \--dmesg option to help developers quickly collect this
information. Notice that this feature work in the local and remote context.

LIST
----

There are multiple debug options available under ftrace and event. For this
reason, kw debug provides the list feature responsible for showing the
available options. If you use `\--list` with no parameters, kw will show all
ftrace algorithms and events options; you can provide the specific debug option
by using ftrace or event. In particular, if you want to list details about a
particular event, you can use `event:TARGET_EVENT`.

OPTIONS
=======
-d, \--disable:
  Disable all events specified inside `\--event ""` and `\--ftrace`. This
  feature does not apply to `\--dmesg` option.

-l, \--list[=(<ftrace> | <events>)]:
  If used together with the event option, it will list all available events. If
  a specific event is informed via *\--events "<event>"*, this option will only
  list specific events related to the "<event>".  This feature does not apply
  to \--dmesg option.

-k, \--history:
  Create a debug directory that keeps track of all debugs made by the users. It
  creates a directory and organizes it based on an ID and date.

-f, \--follow:
  Real time output.

-c, \--cmd:
  If this parameter is used combined with `\--event` or `\--ftrace`, the
  following sequence will happen: (1) Enable specific trace, (2) collect trace
  in background, (3) run the command, (4) disable traces. When used with
  `\--dmesg`, kw will (1) clean the dmesg log, (2) run the command, (3) and
  collect the log.

EXAMPLES
========

For this set of examples, let's suppose that you are debugging the AMD GPU
driver. You can start by trying to learn the options available to you via::

  kw debug --list

The above command will show all debug options available in the target kernel.
Now that you can see all the available options let's suppose that you have the
amdgpu driver; you can list its specific events by using::

  kw debug --list --event "amdgpu_dm"

You can also use::

  kw debug --list="ftrace"
  kw debug --list="events:amdgpu_dm"

Now that you found all the trace options available for your target driver, you
can enable that event trace and follow it in real-time by using something like
this::

  kw debug --event "amdgpu_dm:amdgpu_dm_atomic_update_cursor" --follow

If you want to save the trace output in a log file, you can use the flag
*\--history*::

  kw debug --event "amdgpu_dm:amdgpu_dm_atomic_update_cursor" --follow --history

If you interrupt the above command with Ctrl + C, kw will disable the target
event in the target machine. In other words, something similar to the below
command will be executed::

  kw debug --event "amdgpu_dm" --disable

Another powerful debug trick is the *\--cmd* option that makes kw enable the
target trace, execute a specific command, disable the trace at the end, and
bring the log to the host machine::

  kw debug --event "amdgpu_dm:amdgpu_dm_dce_clocks_state[sclk_khz > 0]" --cmd "DO SOMETHING"

If you want to see the dmesg log from the target machine, you can use::

  kw debug --dmesg

For keeping following the dmesg log and save it locally, you can use::

  kw debug --dmesg --follow --history

Let's say that you want to run a command in a remote machine and collect the
dmesg log after the command execution, you can use::

  kw debug --dmesg --cmd "/home/user/specific_app"

Suppose that you have an AMD and you want to track the display manager's
behavior. You can use the below command to achieve this goal::

  kw debug --ftrace="function_graph:amdgpu_dm*" --follow --history

If you want to run a command and capture the ftrace, you can use::

  kw debug --ftrace="function_graph:amdgpu_dm_*" --cmd="/root/igt-build/tests/kms_atomic --run-subtest test-only" --history
