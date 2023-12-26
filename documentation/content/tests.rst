===============
  About Tests
===============

.. _tests:

Kw's tests rely on `shunit2`. The `run_tests.sh` script automatically detects
`shunit2` in `$PATH` in case it is installed in your system. Alternatively, you
can have shunit2 source code in `tests/` (you can clone it from
https://github.com/kward/shunit2).

In order to run the integration tests, it is necessary to install Podman and  to
configure it to run in `rootless` mode. Podman  is  available  via  the  default
package manager of popular distros, such as Arch, Debian, Fedora and those based
on them.

If you want to run all the tests, try::

  ./run_tests.sh

List all available test files::

  ./run_tests.sh list

Or run individual tests with::

  ./run_tests.sh test TESTFILE1 ...

To limit the scope of the tests, pass the flag `--unit` or `--integration` as
the first argument to any of the examples above. So, the syntax is::

  ./run_tests.sh [scope] [command] [args]

Where `[scope]` can be `--unit` or `--integration`. The placeholder  `[command]`
can be either `list`, `test` or simply omited in order to run  all  tests.  Here
are some examples:

  ./run_tests.sh --unit                       # run all unit tests
  ./run_tests.sh --unit list                  # list all unit tests
  ./run_tests.sh --unit test device           # test device unit test
  ./run_tests.sh --integration                # run all integration tests
  ./run_tests.sh --integration list           # list all integration tests
  ./run_tests.sh --integration test device    # test device integration test
  ./run_tests.sh                              # run all tests
  ./run_tests.sh list                         # list all tests
  ./run_tests.sh test device                  # run all device tests

The integration tests can take over 10 minutes to run in the first time  because
podman is building the container images to be used in the tests, which  requires
installing kw's dependencies in the supported distros.  After  the  images  have
been built and cached, running the integration tests  should  take  only  a  few
seconds each time.

Then, the local kw repo is copied to the containers and installed  again,  which
takes very few seconds. For optimization purposes,  the  containers  are  reused
accross tests. If you add a new commit or checkout to another branch, such  that
HEAD points to another commit, the containers  will  be  destroyed  and  created
again in order to install the current local version of kw.

Kw is already prepared to run tests, build the documentation and check the
installation in the github workflow.
