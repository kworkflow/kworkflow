=====================
Tracing and Profiling
=====================

.. _tracing-and-profiling:

.. contents::
  :depth: 1
  :local:
  :backlinks: none

.. highlight:: console

The `kw` project offers two complimentary functionalities:

1. Production of tracing reports of `kw` executions.
2. Generation of execution profiles using a tracing report for deep analysis.

How to produce tracing reports
------------------------------
To produce tracing reports for every `kw` execution, you simply have to install
it like this::

  ./setup.sh --install --enable-tracing

By installing `kw` in this manner, every run of `kw` produces a directory
`${XDG_DATA_HOME}/kw/tracing/<timestamp>`, where `<timestamp>` corresponds to the
timestamp of when the run started in the format `YYYY-MM-DD_HH-MM-SS`. This
directory stores CSV files that form the tracing report.

As we can have an execution creating other parallel processes/threads, the
aforementioned directory houses a dedicated CSV file for each of these
processes/threads following the format `<thread_number>.csv`, with the main one
always being `0.csv`.

As an example, an execution that spins three other processes/threads, besides the
main one, and that started on October 18 2023 at 14:42:34 would produce the
following hierarchy::

  ${XDG_DATA_HOME}/kw/tracing/2023-10-18_14-42-34
                              |
                              -- 0.csv
                              |
                              -- 1.csv
                              |
                              -- 2.csv
                              |
                              -- 3.csv

What type of tracing report is produced?
----------------------------------------
The objective of the tracing report is to describe the flow of execution considering
**only** functions defined inside the `kw` project. Below, is an excerpt of the
tracing report of an execution::

  entry,include,1697650714354383739
  entry,include,1697650714357746065
  return,include,1697650714361935150
  entry,get_valid_signals,1697650714363833716
  return,get_valid_signals,1697650714372559137
  return,include,1697650714374769796

By the above, we can see that the execution made a first call to `include`, then
(inside the first call) made a second call to `include` and returned, then made a
call to `get_valid_signals` and returned, then, finally, returned from the first
call of `include`. The numbers at the end of each line are the timestamp of the
event in nanoseconds, which allows us to measure the time spent in each stage of
the flow of execution.

.. note::
  `include` and `get_valid_signals` are functions defined inside the `kw` project.

How to generate execution profiles
----------------------------------
To generate execution profiles of a tracing report produced by `kw`, use the
script `scripts/profiler.sh`, like the following::

  ./scripts/profiler.sh (--full|--summary) <tracing_report>

`<tracing_report>` is the path to a tracing report like the one described in the
above sections.

The `--full` and `--summary` options are the two types of profiles currently
supported. The former generates a more visual way to analyze the flow of execution
and the latter generates a summary of time spent (in nanoseconds) in each of the
functions the execution has passed through.

Using the tracing report excerpt shown in the last section, and considering that
it is stored in the path `$tracing_report`, running::

  ./scripts/profiler.sh --full "$tracing_report"

would generate::

  --> include
    3.362 milliseconds
    --> include
      4.189 milliseconds
    <-- include
    1.898 milliseconds
    --> get_valid_signals
      8.725 milliseconds
    <-- get_valid_signals
    2.210 milliseconds
  <-- include

while running::

  ./scripts/profiler.sh --summary "$tracing_report"

would generate::

  get_valid_signals,8725421
  include,11660800
