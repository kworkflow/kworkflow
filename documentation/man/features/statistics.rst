=============
kw-statistics
=============

.. _statistics-doc:

SYNOPSIS
========
| *kw* *statistics* [(\--year [<year>]) | (\--month [<year>/<month>]) |
|                    (\--week [<year>/<month>/<day>]) | (\--day [<year>/<month>/<day>])]

DESCRIPTION
===========
kw keeps track of metadata regarding utilization of features. This data is
used to show kw usage statistics. In summary, kw keeps track of:

1. **Build**

2. **Deploy** (included list and uninstall)

For all the data tracked by kw, users can retrieve the total amount of time
spent by a specific command, the average time consumed by the feature and the
shortest and highest time required for executing the feature. All of this
information can be retrieved by the **statistics** command, the options define
the levels of granularity.

OPTIONS
=======
\--day [<year>/<month>/<day>]:
  Display day statistics summary. Users have the option to search a specific
  date by passing an argument that follows the *<year>/<month>/<day>* format.
  Not passing anything and gets info about today.

\--week [<year>/<month>/<day>]:
  Shows the week summary. If a user does not pass any parameter kw will show
  the current week statistics. However, users can pass a random date
  *<year>/<month>/<day>* and let **kw** take care to provide a summary
  related to the week related to the target date.

\--month [<year>/<month>]:
  Shis option shows a report regarding a specific month. Users can search for
  data related to a specific month by providing a parameter in the
  *<year>/<month>* format. If the user does not pass any parameter, **kw**
  displays the current month data.

\--year [<year>]:
  Exhibits the current year summary if the user does not specify *<year>*.

EXAMPLES
========
For these examples, we suppose the fields in your **kworkflow.config** file are
already configured.

You can see data related to your kw usage by using the statistics option, see
some examples below::

  kw statistics --day
  kw statistics --week
  kw statistics --month
  kw statistics --year

You can also request a specific day, week, month, or year. For example::

  kw statistics --day 2020/05/12
  kw statistics --week 2020/02/29
  kw statistics --month 2020/04
  kw statistics --year 1984
