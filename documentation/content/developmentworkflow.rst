========================
  Development workflow
========================

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

kw is developed using Git and is hosted at Github. If you want to understand
our development workflow better, clone the repository to have a local copy::

  git clone https://github.com/kworkflow/kworkflow.git

Install
-------
Installing kw is one of the first steps to understanding its development
workflow. After cloning the repository, read the page related to
:ref:`installing and removing<install-and-remove-kw>`.

Tests
-----
To make sure our code is working as it is supposed to, we add
:ref:`tests<tests>` to check that.

All our tests can be found in the `tests` folder. Notice that every test file
name ends with test before the .sh extension (i.e. `build_test.sh` and
`statistics_test.sh`). This is done so that the `run_tests.sh` file can detect
those tests and run or list them.

Unit tests
==========
Unit testing is an essential part of our development workflow and we use the
`shUnit2 <https://github.com/kward/shunit2/>`_ framework to write our tests.
Ideally, every new function should have a test related to it. So, if you're
working on a new feature, added a new function, or changed the behavior of an
existing one, it's fundamental to make the necessary adjustments related to
testing.

To see how to run individual test files, check our :ref:`page on that<tests>`.

Run kw without installing it
----------------------------
Apart from using the installed version of kw, you can also use your local
version by going into it and running `./kw` with any other option you want,
just like you would do when you run kw that is installed in your machine.

For instance, suppose you changed the `help.sh` file and want to see if
everything's working as expected. Inside the kw directory you're working on,
you can just invoke::

  ./kw help

This is a convenient option when you're developing for kw and don't want to
install it every time you make a new change to see the result. Running `./kw b`
or `./kw d` won't work, though, since these two options require you to be inside
a repository.

Documentation
-------------
As important as writing tests is documenting things. Our documentation is
located in the `documentation` folder, and we use
`Sphinx <https://www.sphinx-doc.org/en/master/>`_ to create it.

Whether you changed the way a command behaves or added a new feature, modify
the documentation accordingly and preferably with examples. Also, in the source
code, we tend to comment on top of each function, explaining its usage.

ShellCheck and shfmt
--------------------
kw follows its own :ref:`code style guide<coding-style>`, and makes use of
tools, such as ShellCheck and :ref:`shfmt<shfmt-label>`, to make sure this code
style is being followed.

Git pre-commit hook
===================
A very handy way to ensure that your code is well-formatted and follows our
standards is to have a pre-commit hook configured to run the aforementioned
tools before committing. This may, for example, prevent code with bad syntax and
wrong formatting from even being committed before having these things fixed.

To configure this Git pre-commit hook:

0. Have shellcheck installed on your computer.

1. Install `pre-commit <https://pre-commit.com/>`_.

2. Create a file named `.pre-commit-config.yaml` in your local kw repository
   with the following YAML code:

  .. code-block:: yaml

    repos:
    - repo: local
      hooks:
        - id: shfmt
          name: shfmt
          minimum_pre_commit_version: 2.4.0
          language: golang
          additional_dependencies: [mvdan.cc/sh/v3/cmd/shfmt@v3.3.0]
          entry: shfmt
          args: [-w, -i=2, -ln=bash, -fn, -ci, -sr]
          types: [shell]
        - id: shellcheck
          name: shellcheck
          language: script
          entry: /usr/bin/env shellcheck
          args: [-e, "SC2016,SC2181,SC2034,SC2154,SC2001,SC1090,SC1091,SC2120", -x, --shell=bash]
          types: [shell]

  .. note::
      Notice that the pre-commit hook above sets a shfmt version, which is the
      same one we use in the Github actions.

3. Then, run::

    pre-commit install

The next time you try to commit your work, your pre-commit hook will run both
shellcheck and shfmt, and warn you of any errors you may have made.

Kwreview
========

Another way to have your code checked against ``shfmt`` and ``shellcheck`` is to
use ``scripts/kwreview.sh``. By default, it will check your current patch (i.e.
what has changed since the branch unstable) and print ``shellcheck``'s warnings
and ``shfmt``'s warnings as diffs. Use ``kwreview -w`` to apply ``shfmt``'s
changes to the files. If you supply it with path to shell files, it will analyse
those. Make sure you have ``shfmt``, ``shellcheck`` and ``reviewdog`` installed
(see :ref:`dependencies_label`).

For vim users, it is possible to use ``kwreview.sh`` to populate the
`quickfix <http://vimdoc.sourceforge.net/htmldoc/quickfix.html>`_ (or locations)
window, making it easy to navigate the warnings and errors. As an example,
consider adding the following lines to your ``.vimrc``::

  function Kwreview(...)
    let arg = get(a:, 1, "")
    let &l:makeprg="scripts/kwreview.sh " . arg
    make
    execute ":e"
  endfunction

  command -nargs=* Kwreview :call Kwreview(<q-args>)

Now you can call ``kwreview.sh`` with the vim command ``:Kwreview``
(notice the upper case initial) and navigate the errors/warnings with
``:copen``, ``:cn``, ``:cp``, etc.

.. _dependencies_label:

Dependencies
============

Installing ShellCheck
~~~~~~~~~~~~~~~~~~~~~
Shellcheck is available as a package for most distributions. On Debian based
distros, use ``sudo apt install shellcheck``. On Arch based distros, use ``sudo
pacman -S shellcheck``.

Installing shfmt
~~~~~~~~~~~~~~~~

To install shfmt, ``go`` must be installed. On Debian based distros::

  sudo apt install golang

On arch based distros::

  sudo pacman -S go

With go installed, run the following command to install shfmt::

  GO111MODULE=on go get mvdan.cc/sh/v3/cmd/shfmt

More information can be found in their `github page <https://github.com/mvdan/sh>`__.

Installing pre-commit
~~~~~~~~~~~~~~~~~~~~~
``pre-commit`` is available as a package for some distributions. On Debian based
distros, try using ``sudo apt install pre-commit``. On Arch based distros, use
``sudo pacman -S python-pre-commit``. If that doesn't work, you can install it
using pip with ``pip install pre-commit``.

Installing reviewdog
~~~~~~~~~~~~~~~~~~~~
To install reviewdog, run the following command::

  curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b <path>

This will install reviewdog in the directory at ``path``. Make sure this
directory is in your ``PATH`` environmental variable, so that reviewdog
is executable from any directory. For example, you can install it in::

  $HOME/bin/

And add the following line to you shell configuration file (e.g.
``~/.profile``)::

  if [ -d "$HOME/bin" ] ; then
      PATH="$HOME/bin:$PATH"
  fi

Check out reviewdog's `github page
<https://github.com/reviewdog/reviewdog#installation>`__ for other
installation options.
