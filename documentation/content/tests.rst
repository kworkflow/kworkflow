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

Kw is already prepared to run tests, build the documentation and check the
installation in the github workflow.
