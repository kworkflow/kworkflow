=========
kw-backup
=========

.. _backup-doc:

SYNOPSIS
========
| *kw* *backup* [<path>]
| *kw* *backup* (-r | \--restore) <path> [(-f | \--force)]

DESCRIPTION
===========
  If you provide a path, a tar.gz file will be generated and stored in *<path>*,
  containing all the data found in the **KW_DATA_DIR** folder. If no path is
  provided, then the backup will be stored in the current directory.

OPTIONS
=======
-r, \--restore <path>:
  This option allows you to recover all the data from kw, by extracting a tar.gz
  file located in *<path>* and storing it back again in the **KW_DATA_DIR**
  folder. If files with the same name are found during the restoration process,
  then it will by default ask you on how to proceed. To simply replace all files
  from **KW_DATA_DIR** with the backup, you may use the `\--force` option.

EXAMPLES
========

To generate a backup file in your current directory, run::

  kw backup

You can also specify the directory to save the backup. Let's say you want to
save it into /documents/backup, then run::

  kw backup /documents/backup

To restore a backup, use the `\--restore` option. Suppose you want to restore the
backup stored in /documents/backup/kw-backup-from-yesterday.tar.gz, run::

  kw backup --restore /documents/backup/kw-backup-from-yesterday.tar.gz