===============
  About Tests
===============

.. _tests:

Kw's tests rely on `shunit2`. The `run_tests.sh` script automatically detects
`shunit2` in `$PATH` in case it is installed in your system. Alternatively, you
can have shunit2 source code in `tests/` (you can clone it from
https://github.com/kward/shunit2).

If you want to run all the tests, try::

  ./run_tests.sh

List all available test files::

  ./run_tests.sh list

Or run individual tests with::

  ./run_tests.sh test TESTFILE1 ...

Tests rely on some external files. These files are automatically downloaded
when you first try to run a test. You can, however, force `run_tests.sh` to
prepare the environment for running tests with::

  ./run_tests.sh prepare

Also, if you already have the test's environment prepared but want to update
the external files, you can use::

  ./run_tests.sh prepare -f|--force-update

.. note::
   `run_tests.sh` script must be run from the directory it is in,
   i.e. the root of the repository. Otherwise, it may not execute properly.

Kw is already prepared to run tests, build the documentation and check the
installation in `travis-ci <https://travis-ci.org/>`_ . To have it continuously
test your fork of kw on GitHub, upon pushes and pull requests, simply enable
the travis-ci builds for it at https://travis-ci.org/account/repositories.
