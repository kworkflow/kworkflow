===========
kw-pomodoro
===========

.. _pomodoro-doc:

SYNOPSIS
========
| *kw* (*p* | *pomodoro*) (-t | \--set-timer) <time>(h | m | s) [(-g | \--tag) <tag> [(-d | \--description) <desc>] [\--verbose]]
| *kw* (*p* | *pomodoro*) (-c | \--check-timer) [\--verbose]
| *kw* (*p* | *pomodoro*) (-s | \--show-tags) [\--verbose]

DESCRIPTION
===========
This feature provides a way for kernel developers to manage their time through
the Pomodoro technique.

One helpful feature associated with timers is the ``--tag | -g`` option since
it allows users to associate a simple tag to their timebox. Later, users can
generate a report that will display their focus time per tag. Users can
register a tag by simply use ``kw pomodoro --tag <name>``. The maximum length for
this tag is 32 characters. Optionally, users can provide an extra level of details
by associating a description to a specific tag by using ``--description | -d``.
It is recommended to use this option with the same tag and update the
description every time you work on a specific task; with that, kw can generate
a fine-grained report within a set of descriptions shown nested to a particular
tag.

Naturally, users might forget the tag name that they registered for a specific
task. For trying to help with this task, users can use ``kw pomodoro --show-tags``
to show all tags registered; the output also provides the tag ID.

.. note:: It is highly recommended to use tags and descriptions with a timebox.

OPTIONS
=======
-t <time>(h | m | s), \--set-timer <time>(h | m | s):
  This option expects an integer *<time>* that indicates the timer for the
  Pomodoro timebox. It is **mandatory** to add a suffix that indicates the time
  unit, which can be **h** (hour), **m** (minutes), or **s** (seconds).

-g <tag>, \--tag <tag>:
  Associate a tag to the timebox. If *<tag>* is an integer, kw will try to match
  it with an existent tag ID and translate it to the corresponding tag name. This
  option needs to be used in conjunction with ``--set-timer``

-d <desc>, \--description <desc>:
  This option allows for more descriptive text associated with the timer. The max
  length is 512 characters and this option needs to be used in conjunction with
  ``--tag`` and ``--set-timer``.

-c, \--check-timer:
  This option shows information associated of each active Pomodoro timebox.

-s, \--show-tags:
  This option shows all the registered tags.

\--verbose:
  Display commands executed under the hood.

EXAMPLES
========
Create a Pomodoro timebox of 10 minutes without tags::

  kw pomodoro --set-timer 10m

Show active Pomodoro timeboxes::

  kw pomodoro --check-timer

Show all registered tags::

  kw pomodoro --show-tags

Create a Pomodoro timebox of 1 hour with tag name 'kernel-dev' and description
'amd-gfx patch reviews'::

  kw pomodoro --set-timer 1h --tag 'kernel-dev' --description 'amd-gfx patch reviews'

Create a Pomodoro timebox of 99 seconds with tag name corresponding to the tag
of ID 42::

  kw pomodoro --set-timer 99s --tag 'kernel-dev
