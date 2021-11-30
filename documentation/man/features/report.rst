=========
kw-report
=========

.. _report-doc:

SYNOPSIS
========
| *kw* (*r* | *report*) [\--year [<year>]] [\--output <file-path>]
| *kw* (*r* | *report*) [\--month [<year>/<month>]] [\--output <file-path>]
| *kw* (*r* | *report*) [\--week [<year>/<month>/<day>]] [\--output <file-path>]
| *kw* (*r* | *report*) [\--day [<year>/<month>/<day>]] [\--output <file-path>]

DESCRIPTION
===========
**kw** keeps track of some data operations; the most prominent example is the
Pomodoro feature. This feature intends to keep all procedures related to data
processing that will end up as a report for the user.

OPTIONS
=======
\--day[=<year>/<month>/<day>]:
  Display day summary. Users have the option to search a specific date by
  passing an argument that follows the *<year>/<month>/<day>* format. Not
  passing anything and gets info about today.

\--week[=<year>/<month>/<day>]:
  Shows the week summary. If a user does not pass any parameter kw will show
  the current week statistics. However, users can pass a random date
  *<year>/<month>/<day>* and let **kw** take care to provide a summary
  related to the week related to the target date.

\--month[=<year>/<month>]:
  This option shows a report regarding a specific month. Users can search for
  data related to a specific month by providing a parameter in the
  *<year>/<month>* format. If the user does not pass any parameter, **kw**
  displays the current month data.

\--year[=<year>]:
  Exhibits the current year summary if the user does not specify *<year>*.

\--output <file-path>:
  Save the output of the report to *<file-path>*.

EXAMPLES
========
You can see data related to your kw usage by using the report option, see
some examples below:

  kw report
  kw report --day
  kw report --week
  kw report --month
  kw report --year

You can also request a specific day, week, month, or year. For example::

  kw report --day=2020/05/12
  kw report --week=2020/02/29
  kw report --month=2020/04
  kw report --year=1984
