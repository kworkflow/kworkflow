=========================
  kw kernel debug tools
=========================
.. _kernel-debug:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Introduction
------------

Linux Kernel provides multiple debug methods that can be handy to identify
problems and learn how some specific feature works. With this idea in mind, kw
tries to hide and standardize the complexity of dealing with the following
debug features:

* *Events*: Event tracepoints provide real-time information associated with some
  specific parts of the code. Developers can enable this trace when the target
  OS is running to collect data. If you want to know more about it, take a look
  at: https://www.kernel.org/doc/html/latest/trace/events.html
* Ftrace: Function callback traces can help identify some specific behavior
  when a target function is invoked. In particular, the function graph filter
  provides valuable information about the code sequence. If you want to learn
  more about this feature, take a look at:
  https://www.kernel.org/doc/html/v5.3/trace/ftrace-uses.html
* Dmesg: In a few words, it shows the message buffer from the kernel.

In particular, when we dive into events and ftrace we can abstract some common
steps required to use these debug tools, which can be summarized as follows:

#. Clean/Disable debugger::

    echo 0 > /sys/kernel/debug/tracing/tracing_on

#. Setup the target debug::

    echo 'TARGET' > /sys/kernel/debug/tracing/[current_tracer|events...]

#. Fine-tune the debug options::

    echo 'FINE-TUNE' >> /sys/kernel/debug/tracing/[set_ftrace_filter|events/TARGET/filter]

#. Enable the debug::

    echo 1 > /sys/kernel/debug/tracing/tracing_on

#. Collect the data::

    cat /sys/kernel/debug/tracing/trace_pipe

As you can see, we have multiple steps, and this situation can be worse when we
consider that sometimes we want to collect the debug data from a machine
connected to a local network or an external machine. Kw debug tries to hide
this complexity under the "debug" option. For detailed information about this
feature, check the man page, here we will provide a simple tutorial on how to
use it.

Common Options
--------------

The debug option provides a standard set of features that can be used with
``--dmesg``, ``--events``, and ``--ftrace``. To avoid explaining the same ideas
repeatedly, this section introduces the following shared behavior: ``--follow``,
``--history``, and ``--cmd``.

Follow log (`\--follow | -f`)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

If you want to follow the log in real-time, you probably want to use the
``--follow | -f`` option, which will keep polling the data and provide you with
a live feed of it.

Save (`\--history | -k`)
~~~~~~~~~~~~~~~~~~~~~~~~

This option will create a folder named ``kw_debug`` in the folder that you run
this command and a sub-folder that follows this pattern::

  <ID>_<YEAR-MONTH-DAY>

If you use this feature, kw will automatically save your debug log in the
folder as described above. This is useful if you want to compare debug when
changing some configuration.

Command (`\--cmd | -c`)
~~~~~~~~~~~~~~~~~~~~~~~

This option expects a parameter which is a command to be executed in the target
machine. The idea is something like this:

#. Clean the target log
#. Start logging
#. Run the command
#. Stop logging

Dmesg
-----

Imagine a scenario where you have a bug when you try to load a module, or you
have a custom kernel with ``pr_info()`` spread around and you want to see that
information in the kernel log; you can use the following command::

 kw debug --dmesg

However, a better solution could be::

 kw debug --dmesg --follow

Or::

 kw debug --dmesg --cmd "modprobe amdgpu" --history

Events
------

Let's say that you have a complex scenario to debug where you want to follow a
specific trace in real-time; in this case, you can use event trace. You can
start by listing all available traces::

 kw debug --list="events"

You will see something like this::

 alarmtimer      bpf_trace       dev             exceptions      fs_dax          hda_intel       initcall        irq_matrix      libata          mmc             netlink         page_pool       random          rpm             skb             syscalls        udp             x86_fpu
 amdgpu          cgroup          devfreq         ext4            ftrace          header_event    intel_iommu     irq_vectors     mce             module          nmi             percpu          ras             rseq            smbus           task            vmscan          xdp
 amdgpu_dm       clk             devlink         fib             gpio            header_page     iomap           jbd2            mdio            msr             nvme            power           raw_syscalls    rtc             sock            tcp             vsyscall        xen
 avc             cma             dma_fence       fib6            gpu_scheduler   huge_memory     iommu           kmem            migrate         napi            oom             printk          rcu             sched           spi             thermal         wbt             xhci-hcd
 block           compaction      drm             filelock        hda             hwmon           io_uring        kvm             mmap            neigh           page_isolation  pwm             regmap          scsi            swiotlb         timer           workqueue
 bpf_test_run    cpuhp           error_report    filemap         hda_controller  i2c             irq             kvmmmu          mmap_lock       net             pagemap         qdisc           regulator       signal          sync_trace      tlb             writeback

It is up to you to pick up one of the specific events to trace. For this
tutorial, let's say you want to debug something related to amdgpu driver; from
the above list, you will notice that we have two options: ``amdgpu`` and
``amdgpu_dm``. If you want to know more details about ``amdgpu_dm``, you can
use::

  kw debug --list="events:amdgpu_dm"

You should see something like this::

 Available events for the requested device:
      1  amdgpu_dc_performance
      2  amdgpu_dc_rreg
      3  amdgpu_dc_wreg
      4  amdgpu_dm_atomic_check_begin
      5  amdgpu_dm_atomic_check_finish
      6  amdgpu_dm_atomic_commit_tail_begin
      7  amdgpu_dm_atomic_commit_tail_finish
      8  amdgpu_dm_atomic_state_template
      9  amdgpu_dm_atomic_update_cursor
     10  amdgpu_dm_connector_atomic_check
     11  amdgpu_dm_crtc_atomic_check
     12  amdgpu_dm_dc_clocks_state
     13  amdgpu_dm_dce_clocks_state
     14  amdgpu_dm_dc_pipe_state
     15  amdgpu_dm_plane_atomic_check
     16  amdgpu_dmub_trace_high_irq
     17  amdgpu_refresh_rate_track
     18  dcn_fpu

Notice that you can put any specific event after ``events:``. Finally, let's
say that you want to debug the cursor parameters; you can use::

 kw debug --event "amdgpu_dm:amdgpu_dm_atomic_update_cursor" --follow

Note that the basic syntax to use event is something like
"TARGET_EVENT:SPECIFIC_EVENT". However, events also provide a filter mechanism
which you can specify to kw by using ``[]``, see the below example::

  kw debug --event "amdgpu_dm:amdgpu_dm_atomic_update_cursor[crtc_x < 1000]" --follow

For more details, check the man page.

Ftrace
------

Another powerful and valuable trace is the ``ftrace`` option. We have multiple
algorithms to be used with this trace, which you can list by using::

  kw debug --list="ftrace"

This will show something like this::

 1. hwlat
 2. blk
 3. mmiotrace
 4. function_graph
 5. wakeup_dl
 6. wakeup_rt
 7. wakeup
 8. function
 9. nop

Those are the ftrace algorithms that you can set; function_graph is probably
the most common one, and you can use it like this::

 kw debug --ftrace="function_graph:amdgpu_dm*" --follow
