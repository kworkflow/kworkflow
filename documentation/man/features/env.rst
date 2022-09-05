======
kw-env
======

.. _env-doc:

SYNOPSIS
========
| *kw* (*env*) [(-c | \--create) <NAME>]
| *kw* (*env*) [(-u | \--use) <NAME>]
| *kw* (*env*) [(-l | \--list)]


DESCRIPTION
===========
When working with the Linux kernel, we might want to run different tests to fix
some specific issues. One typical example is when a developer works with 64-bit
architecture but has to check if the 32-bit compilation works fine; this effort
requires changes in the config file and other parts. Another case is when a
developer uses the same kernel for a test machine with configuration X, but
they also need to check another device with configuration Y. kw env makes the
developer's life easier by isolating multiple contexts in their environment.

When you create a new env, kw will isolate:

1. All kw configs per env. This means that you can have one dedicated
configuration per env;

2. Associate the kernel config file with the new env. In other words, in the
same kernel, you can have different kernel configs file per env;

3. Isolate compiled file per env.

.. note::
  kw does not support the concept of global env. You must have one env per
  kernel repository.

OPTIONS
=======
-c, \--create <ENV_NAME>:
  The create parameter expects a string to be used as an env name. When kw
  create a new env it instantiates the current kw configurations to the new
  env.

-u, \--use <ENV_NAME>:
  Change from one env to another previously created.

-l, \--list:
  It shows all envs created via `\--create` option.

EXAMPLES
========
If you want to create a new env, you can use::

  cd <kernel-path>
  kw env --create MY_NEW_ENV
  kw env --create 32-BIT-COMPILATION

If you want to create a new env, you can use::

  kw env --use 32-BIT-COMPILATION

If you want to list the available envs::

  kw env --list
