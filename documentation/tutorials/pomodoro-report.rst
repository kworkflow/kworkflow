=====================================================
 How to use Pomodoro and report in an effective way
=====================================================

.. _pomodoro-report-tutorial:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Introduction
------------

Usually, when working on a kernel bug, new feature, or code refactor, we put a
considerable amount of work toward our goal; inevitably, developers will take
breaks in their tasks. A common technique to manage these periods of working
and resting is named Pomodoro. In a few words, developers define Z minutes to
fully focus on something and Y minutes to rest before another focus session
(for more details, read the `Wikipedia page
<https://en.wikipedia.org/wiki/Pomodoro_Technique>`_). Since this is a
widespread technique, kw added support to it with the `pomodoro` feature;
however, we also expanded it to enable developers to generate reports based on
their focus time.

At this point, you might ask yourself, "What is the advantage of tying Pomodoro
sessions to reports?". If you work as a developer, then chances are that you
have to write reports to your manager, company, a status update on your
website, or you might want to assess your productivity. No matter your reasons,
sooner or later, you will face a situation where you need a report, and if you
are not ready, you will probably prepare it hastily. Lastly, if you use kw
regularly, you probably have it as part of your workflow, making it easier to
adopt the pomodoro and report feature.

Ok, enough with the general explanation; this is the tutorial section, right?
For this tutorial, suppose that we have two situations, one where you are
working on a bug and another one that you are implementing a new feature. Later
you need a report with the details of your work.

Start a focus session
---------------------

Since you are working on a highly complex bug, you decide to dedicate 30
minutes to make sure that you know how to reproduce the issue; you can start
with::

  $ kw pomodoro --set-timer 30m --tag "Super weird bug" --description "Let's make sure that I know how to reproduce this bug..."

Notice that you can use the short version of the above command::

  $ kw p -t 30m -g "Super weird bug" -d "Let's make sure that I know how to reproduce this bug..."

.. note::
    From now on, this tutorial will use the short version

Now that you created this session, you can check how many minutes are left by
using::

  $ kw p --list # kw p -l


Now, forget about the world and focus on your task for 30 minutes; don't worry,
kw will notify you with a sound and a pop-up box (if you enable this in your
system) when your session finishes. After you complete one round, take a break
to refresh your energy and get back later.

Suppose that you already know how to reproduce that bug, and now you want to
implement a workaround to fix it; let's create a new focus session associated
with the same tag::

  $ kw p -t 30m -g "Super weird bug" -d "I know how to reproduce the bug! I'm going to try THIS WORKAROUND to see if it fixes the issue"

Notice that typing "Super weird bug" is tedious and error-prone, but don't
worry, kw provides a feature to list all tags and associates them with an ID.
To see all the tags that you already created, use this command::

  $ kw p -g
  1.Super weird bug

In other words, you can use::

  $ kw p -t 30m -g 1 -d "I know how to reproduce the bug! I'm going to try THIS WORKAROUND to see if it fixes the issue"

You can create as many focus sessions as you want at any time and day.

Generate a report
-----------------

At this point, you are already familiar with the basic functionality around the
Pomodoro feature, and you use it daily. However, now someone is asking you for
a report on your last week, and you worked on so many things that you don't
even know where to start; don't worry, kw has your back. It is now time to use
the report feature. If you want to get this week's summary, you can use::

  $ kw report --week

Or just::

  $ kw r --week

The report will look like this:

.. code-block:: md

    # Report: YYYY/MM/DDD
     * Total hours of focus: 48:43:00
     * Total focus session(s): 23

    ## Super weird bug
     - Total focus time: 04:20:00
     - Total repetitions: 22

    Summary:
     * [15:00:00-15:30:00][30m]: Let's make sure that I know how to reproduce this bug...
     ...
     * [17:00:00-17:30:00][30m]: I know how to reproduce the bug! I'm going to try THIS WORKAROUND to see if it fixes the issue

    ## Another Tag
     - Total focus time: HH:MM:SS
     - Total repetitions: 4

    Summary:
     * [08:15:50-08:45:50][30m]: More descriptions
    ...

As you can see, the report starts with a generic summary, and then displays a
breakdown of the sessions per tag. Each tag will receive its own section, and
each description will be put in order in the Summary part. This feature allows
you to generate reports with the following granularity:

* Day: Provide a day using the format YYYY/MM/DD.
* Week: You need to provide a target day (no matter the weekday), and kw will
  look for the first day of the week associated with that date and generate a
  report based on that.
* Month: Provide a month using YYYY/MM and kw will give you the report for the
  target month.
* Year: Provide the year as YYYY and kw will provide the summary for the entire
  year.

By default, if you do not provide specific dates, kw report will assume the
closest date; for example::

    $ kw report         # Shows today's report
    $ kw report --week  # Shows this week's report
    $ kw report --month # Shows this month's report
    $ kw report --year  # Shows this year's report

Conclusion
----------

As you can see, Pomodoro and report are very powerful tools to help you track
your work. If you use this feature regularly, there is a good chance that all
of this data is valuable to you; in this sense, we recommend you take a look
at kw backup feature since it creates a backup of all your Pomodoro data.
