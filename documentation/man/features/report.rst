=========
kw-report
=========

.. _report-doc:

SYNOPSIS
========
| *kw* (*r* | *report*) [(\--year [<year>]) | (\--month [<year>/<month>]) |
|           (\--week [<year>/<month>/<day>]) | (\--day [<year>/<month>/<day>])]
|           [\--output <file-path>]

DESCRIPTION
===========
**kw** keeps track of some data operations; the most prominent example is the
Pomodoro feature. This feature intends to keep all procedures related to data
processing that will end up as a report for the user.

OPTIONS
=======
\--day [<year>/<month>/<day>]:
  Display day summary. Users have the option to search a specific date by
  passing an argument that follows the *<year>/<month>/<day>* format. Not
  passing anything and gets info about today.

\--week [<year>/<month>/<day>]:
  Shows the week summary. If a user does not pass any parameter kw will show
  the current week statistics. However, users can pass a random date
  *<year>/<month>/<day>* and let **kw** take care to provide a summary
  related to the week related to the target date.

\--month [<year>/<month>]:
  This option shows a report regarding a specific month. Users can search for
  data related to a specific month by providing a parameter in the
  *<year>/<month>* format. If the user does not pass any parameter, **kw**
  displays the current month data.

\--year [<year>]:
  Exhibits the current year summary if the user does not specify *<year>*.

\--output <file-path>:
  Save the output of the report to *<file-path>*.
