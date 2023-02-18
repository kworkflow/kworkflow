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

Another help feature is the ``--statistics | -s`` option that keeps track of
metadata regarding utilization of features. This data is used to show **kw**
usage statistics. In summary, this feature keeps track of:

1. **Build**

2. **Deploy** (included list and uninstall)

For all the data tracked by **kw**, users can retrieve the total amount of time
spent by a specific command, the average time consumed by the feature and the
shortest and highest time required for executing the feature. All of this
information can be retrieved by the ``--statistics | -s`` option, the suboptions
define the levels of granularity.

The collection of the data processed and displayed by ``--statistics`` is
optional and can be disabled by disabling ``disable_statistics_data_track``
option in ``kworkflow.config``.

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

\--all:
  Display all information for the current date. You can choose the date and
  range with date options.

\--pomodoro:
  Display current date pomodoro report. You can choose the date and range
  with date options.

\--statistics:
  Display statistics for the current date. You can choose the date and range
  with date options.

\--output <file-path>:
  Save the output of the report to *<file-path>*.

EXAMPLES
========
First of all, for these examples, we suppose that you have the
disable_statistics_data_track option in your kworkflow.config enabled for a
while.

You can see data related to your kw usage by using the report option, see
some examples below::

  kw report
  kw report --day
  kw report --week
  kw report --month
  kw report --year

  kw report --all --day
  kw report --all --week
  kw report --all --month
  kw report --all --year

  kw report --pomodoro --day
  kw report --pomodoro --week
  kw report --pomodoro --month
  kw report --pomodoro --year

  kw report --statistics --day
  kw report --statistics --week
  kw report --statistics --month
  kw report --statistics --year

You can also request a specific day, week, month, or year. For example::

  kw report --day=2020/05/12
  kw report --week=2020/02/29
  kw report --month=2020/04
  kw report --year=1984

  kw report --all --day=2020/05/12
  kw report --all --week=2020/02/29
  kw report --all --month=2020/04
  kw report --all --year=1984

  kw report --pomodoro --day=2020/05/12
  kw report --pomodoro --week=2020/02/29
  kw report --pomodoro --month=2020/04
  kw report --pomodoro --year=1984

  kw report --statistics --day=2020/05/12
  kw report --statistics --week=2020/02/29
  kw report --statistics --month=2020/04
  kw report --statistics --year=1984
