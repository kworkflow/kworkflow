============================
kw-drm - DRM subsystem tools
============================

.. _drm-doc:

SYNOPSIS
========
| *kw* *drm* [\--local | \--remote [<remote>:<port>]]
|            [\--load-module=<module>[:<param1>,...][;<module>:...] |
|            \--unload-module=<module>[;<module>;...] |
|            \--gui-on | \--gui-off | \--conn-available | \--modes | \--verbose]

DESCRIPTION
===========
Linux kernel has multiple subsystems that expose operations via sysfs or
provide mechanisms for userspace to interact with the driver. For this reason,
kw offers some options that target some specific subsystems for providing
facilities for users to interact with a particular subsystem. Currently, we
only support drm.

This feature is responsible to deal with DRM features.

OPTIONS
=======
\--local, \--remote [<remote>:<port>]:
  This option specifies the target device for the drm action, it can be a
  remote or local machine. If these options are not explicitly passed via
  command line, **kw** is going to take the target set in the variable
  *default_deploy_target* (**deploy.config**) for identifying the target.
  It is important to highlight that the drm feature **does not support VM**.

-lm, \--load-module=<module>[:<param1>,...][;<module>:...]:
  Allow user to specify one or more modules to be load with or without
  parameters. If you want to indicate more than one module, you have to
  separate them using ';'. Additionally, if users wish to provide specific
  parameters for the target module, they have to use ':' and separate each
  parameter with ','. This option can be combined with ``--gui-on``, **kw**
  will make sure that the target module will be load first and after that
  trigger the GUI.

-um=<module>[;<module>;...], \--unload-module=<module>[;<module>;...]:
  This option allows users to unload one or more DRM drivers. Users can provide
  a single module to be unloaded or a list separated by ';'. This command first
  disables the user interface and, after that, unloads the module.

\--gui-on:
  This option provides a mechanism for turn-on the GUI, by default
  it uses systemctl operation; however, users are free to add any specific
  command for activating their preferred GUI in the variable *gui_on* on the
  **kworkflow.config** file.

\--gui-off:
  Turn off the target GUI in the specified target, by default, it uses the
  systemctl operation but users can change this behavior by set *gui_off* with
  a specific command in the **kworkflow.config** file with the specific command.

\--gui-on-after-reboot:
  This option sets the GUI to turn on automatically after the next reboot. By default,
  it uses systemctl operation; however, users are free to add any specific
  command for activating their preferred GUI in the variable *gui_on_after_reboot*
  in the **kworkflow.config** file.
  Note: This change will take effect only after the system is rebooted. To enable
  the GUI immediately, use the --gui-on option.

\--gui-off-after-reboot:
  This option sets the GUI to turn off automatically after the next reboot. By default,
  it uses systemctl operation; however, users are free to add any specific
  command for deactivating their GUI in the variable *gui_off_after_reboot*
  in the **kworkflow.config** file.
  Note: This change will take effect only after the system is rebooted. To disable
  the GUI immediately, use the --gui-off option.

\--conn-available:
  Show all connectors available in the target machine. The ones marked with '*'
  are enabled.

\--modes:
  Show all available modes per card.

\--verbose:
  Verbose mode is an option that causes the kw program to display debug messages to track
  its progress. This functionality is very useful during the debugging process, allowing
  you to identify possible errors more easily.

EXAMPLES
========
For these examples, we assume that the relevant fields in your configuration 
files (located by default in **.kw/**) have already been setup. We recommend
the use of ``kw config`` for managing your local and global configurations.

If you are working with DRM drivers, you can take advantage of load and unload
commands combined with GUI control commands. For example::

  kw drm --load-module='amdgpu' --gui-on # Load a driver and trigger the user GUI
  kw drm --unload-module='amdgpu' # Turn off user GUI and unload the driver

.. note:: You have to wait for the sshd to become ready.
