===========
kw-pomodoro
===========

.. _pomodoro-doc:

SYNOPSIS
========
| *kw* (*p* | *pomodoro*) (-t | \--set-timer) <integer>(h | m | s)
|                       [(-g | \--tag) [<str1> [(-d | \--description) <str2>]]]
| *kw* (*p* | *pomodoro*) (-l | \--list)

DESCRIPTION
===========
This feature provides a way for kernel developers to manage their time through
the Pomodoro technique.

One helpful feature associated with timers is the ``--tag | -g`` option since
it allows users to associate a simple tag to their timebox. Later, users can
generate a report that will display their focus time per tag. Users can
register a tag by simply use ``kw p --tag <name>``. The maximum length for this
tag is 32 characters. Optionally, users can provide an extra level of details
by associating a description to a specific tag by using ``--description | -d``.
It is recommended to use this option with the same tag and update the
description every time you work on a specific task; with that, kw can generate
a fine-grained report within a set of descriptions shown nested to a particular
tag.

Naturally, users might forget the tag name that they registered for a specific
task. For trying to help with this task, users can use ``kw p --tag`` to list
all tags created by them; the output also provides the tag id.

.. note:: It is highly recommended to use tags and descriptions with a timebox.

OPTIONS
=======
-t <integer>(h | m | s), \--set-timer <integer>(h | m | s):
  This option expects an *<integer>* that indicates the timer for the
  Pomodoro timebox. It is **mandatory** to add a suffix that indicates the time
  unit, which can be **h** (hour), **m** (minutes), or **s** (seconds).

-g [<string>], \--tag [<string>]:
  Associate a tag to the timebox. If *<string>* is not supplied all existing
  tags are listed. Max length 32 characters.

-d <string>, \--description <string>:
  When used with the ``--tag`` option allows for more descriptive text
  associated with the timer. Max length 512 characters.

-l, \--list:
  This command shows information associated with each Pomodoro timebox created
  by the user.
