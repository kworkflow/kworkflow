=====================
  kw coding style
=====================

.. _coding-style:

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Overview
--------

This is a short document describing the kw preferred coding style. It is
important to highlight that we got inspiration from Linux_ and Git_ code
style, for this reason, we copied-and-pasted many pieces from both projects.

.. _Git: https://github.com/git/git/blob/master/Documentation/CodingGuidelines#L41
.. _Linux: https://github.com/torvalds/linux/blob/master/Documentation/process/coding-style.rst

.. _shfmt-label:

shfmt
_____

To help us enforce our codestyle decisions we utilize the
`shfmt <https://github.com/mvdan/sh>`_ code formatter in our CI pipeline.
Please refer to the shfmt repository for instructions on how to install it
on your specific linux distribution, it is available as a package for most
distributions and as a plugin for most IDEs and text editors.
To format a file using shfmt::

  shfmt -w -i=2 -ln=bash -fn -ci -sr FILE

To check a file and error with a diff when the formatting differs::

  shfmt -d -i=2 -ln=bash -fn -ci -sr FILE

Indentation
-----------

We adopt two whitespace indentations.

Avoid tricky expression
-----------------------

We try to keep things as simple as possible in kw, for this reason, we try to
**avoid**:

* Multiple assignments on a single line;
* Using more than 10 local variables per function.

.. note::
  Of course, we value the code legibility, for this reason, we accept a few
  exceptions.


Breaking long lines and strings
-------------------------------

The default limit on the length of lines is 80 columns and this is a strongly
preferred limit. This is not a rule to be blindly followed, we understand that
in some cases we need more columns; however, try to do you best for keeping the
code under 80 characters.

Sometimes long strings are a bit cumbersome to keep under 80 columns, in kw we
adopt string concatenation for this case as the example below illustrates::

  my_long_string="kw ran into an unrecoverable error while trying to parse your file."
  my_long_string+=" Do you wish to continue anyway [Y/n]?"

Placing Optional Bash Keywords and Spaces
-----------------------------------------

Some of the bash keywords may accept or not the reserved word `then` or `do`
which can be added at the end of the expression or in the next line. In kw we
put the then statement at the end of the expression (after the semicolon), as
the example below illustrates::

  if [[ EXPRESSION ]]; then
    do_something
  fi

The same idea applies for loops::

  for EXPRESSION; do
    do_something
  done

or::

  while EXPRESSION; do
    do_something
  done

For the `case` statement, we add one level of indentation after the `case`
statement::

  case VALUE in
    option1)
      do_something1
      ;;
    option2)
      do_something2
      ;;
    *)
      exit 22
      ;;
  esac

Functions
---------

.. note::
  Our approach for implementing function is really similar to the ones
  adopted by the Linux Kernel, the description here is an adaptation of the
  Linux Kernel codestyle documentation.

Functions should be short and sweet, and do just one thing. They should fit on
one or two screenfuls of text (the ISO/ANSI screen size is 80x24, as we all
know), and do one thing and do that well.

The maximum length of a function is inversely proportional to the complexity
and indentation level of that function. So, if you have a conceptually simple
function that is just one long (but simple) case-statement, where you have to
do lots of small things for a lot of different cases, it’s OK to have a longer
function.

However, if you have a complex function, and you suspect that a
less-than-gifted first-year high-school student might not even understand what
the function is all about, you should adhere to the maximum limits all the more
closely. Use helper functions with descriptive names.

Another measure of the function is the number of local variables. They
shouldn’t exceed 5-10, or you’re doing something wrong. Re-think the function,
and split it into smaller pieces. A human brain can generally easily keep track
of about 7 different things, anything more and it gets confused. You know
you’re brilliant, but maybe you’d like to understand what you did 2 weeks from
now.

Bash supports function declarations with or without the parentheses and with or
without the reserved word `function`. In kw source code, we **always** add the
`function` reserved word and the parentheses even if the function does not have
any parameter (without an extra space). Additionally, we add the curly braces
in a single line. For example::

  function modules_install_to()
  {
    [..]
  }

For the function returning we try to respect the errno codes, for example::

  function mk_list_installed_kernels
  {
    [..]
      if [ "$?" != 0 ] ; then
        complain "Did you check if your VM is running?"
        return 125 # ECANCELED
      fi
    [..]
  }

As you can notice from the examples, we use snake case for function
definitions, this is valid for all the kw code.

Redirection
-----------

Redirection operators should be written with space before, but no space after
them. In other words, write ``printf '%s\n' test >"$file"`` instead of
``printf '%s\n' test> "$file"`` or ``printf '%s\n' test > "$file"``. Note that
even though it is not required by POSIX to double-quote the redirection target
in a variable (as shown above), our code does so because some versions of bash
issue a warning without the quotes::

    (incorrect)
    cat hello > world < universe
    printf '%s\n' hello >$world

    (correct)
    cat hello >world "$world"

Command substitution and arithmetic expression
----------------------------------------------

We prefer `$( ... )` for command substitution; unlike \`\`, it properly nests.
It should have been the way Bourne spelled it from day one, but unfortunately
isn't.

For arithmetic expansion we use `$(( ... ))`.

Check for command
-----------------

If you want to find out if a command is available on the user's
$PATH, you should use 'type ', instead of 'which '.
The output of 'which' is not machine parsable and its exit code
is not reliable across platforms.

How to include/import files
---------------------------
Do not source code using `.` or `source`. We have a helper function for that
named `include` in `kw_include.sh` and it should be used any and everytime a
file needs to be sourced, `. file.sh --source-only` should only be used to
source `include.sh` itself. The `include` function guarantees us that no file
will be sourced twice, making the kw dev life easier with one thing less to
worry about.

Test name
---------

Tests are an important part of kw, we only accept new features with tests, and
we prefer bug fixes that come with tests. For trying to keep the test
comprehensible, we adopt the following pattern for naming a test::

    test_target_function_name_[an_optional_description]()

To better illustrate this definition, see the example below::

    function test_detect_distro()

This function name indicates that we are testing `detect_distro` function.
Another example::

    function test_save_config_file_check_description()

The function `save_config_file` is tested with a focus on description
validation.

Resources for tests
-------------------

We encourage the use of the following features offered by shunit2, kworkflow's
unit test framework.

 - Functions `oneTimeSetUp` and `oneTimeTearDown`: If defined, these functions
   will be called once before and after any tests are run, respectively. Notice
   that shunit2 is sourced once for each test file, so the scope of
   these functions is effectively the test file (e.g. `help_test.sh`) in
   which they are defined.
 - Functions `setUp` and `tearDown`: If defined, these functions will be
   called before and after each test (i.e. a test function) is run, respectively.
 - Shunit2 offers a temporary directory that will be cleaned upon it's exit. The
   path to this directory is stored in the variable `SHUNIT_TMPDIR`. Note
   however that this directory is not cleaned up between tests, so you may
   need to clear it in the `tearDown` function.

We also encourage each assertion in each test to be identified with the variable
`LINENO`. This variable expands to the line number currently being executed.
This way the origin of an error message can quickly be identified by a
developer. For example::

   assertEquals "($LINENO)" "$output" "$expected_output"

Help functions
--------------
Each subcommand may have its help function that details its usage. This
function should be located as close as possible to the feature they document;
ideally, we want it in the same file. For example, you should find details on
using the `build` option in the mk.sh, and for `configm` in the file
config_manager.sh.

Handling Signals
----------------
It is natural for commands to set global variables or to create temporary files
during their execution. However, all commands should expect to receive signals
and be able to properly handle them. If you implement a new feature, take some
time to check if it pollutes the environment. If it does, make sure to handle
it's de-pollution upon receiving a SIGINT or a SIGTERM: an interrupted command
should always leave the environment in the same state as it was prior to its
invocation. Convenience functions for this purpose (setting and resetting
handlers for arbitrary signals) are implemented in `src/signal_manager`.

Use ``printf`` instead of ``echo``
----------------------------------
We stay away from ``echo`` as it is not always consistent with its output
depending on system and bash version. Therefore always use ``printf`` instead,
it stays consistent across mutliple platforms. If you need to add extra lines
while generating a string you can use the ``$'\n'`` literal to add a new line
character or other special characters.

Conclusion
----------

When in doubt of a coding style matter not specified in this file, it is always
a good idea to search how other sections of the codebase use the term you are
in doubt about. But be aware that some sections may unfortunately be at odds
with the specified style rules (and pull requests to correct them are very
welcome). Finally, feel free to also suggest modifications to this document --
to add absent rules -- or mention any style doubts in your pull request.
