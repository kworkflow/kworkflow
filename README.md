<img src="images/kw_logo.png" width="600" alt="kworkflow">

[![Build Status](https://travis-ci.org/kworkflow/kworkflow.svg?branch=master)](https://travis-ci.org/kworkflow/kworkflow)
[![codecov](https://codecov.io/gh/kworkflow/kworkflow/branch/master/graph/badge.svg?token=ZQ52EK8VWF)](https://codecov.io/gh/kworkflow/kworkflow)
# About

This set of scripts have a simple mission: reduces the environment and setup
overhead for developing for GNU/Linux. Kw is composed of different scripts
unified in a single interface after the installation, kw commands become
available in the command line interface.

Kworkflow stands for Kernel Workflow.

# Install

Take a look at
[Install and Uninstall](documentation/content/installanduninstall.rst).

# How to

If you want to know more about kw's usage and its commands, take a look at
[Kw man](documentation/man/kw.rst) or, with kw installed, run `kw man`.

# Tests

If you want to know more about kw's tests take a look at
[kw tests](documentation/content/tests.rst).

# Generate Sphinx Documentation

If you want to generate the Sphinx documentation, you can use:

```
./setup.sh --docs
``` 

Finally, you can use your browser to look the index.html page. For example:

```
firefox build/index.html
```

# Contributing

We are happy that you want to help us! If you are looking for a good starting
point, check
[those issues](https://github.com/kworkflow/kworkflow/labels/good%20first%20issue)
and don't forget to read our
[Contribuitor's Guide](https://flusp.ime.usp.br/doc/kw/content/howtocontribute.html)
(or [howtocontribute file](documentation/content/howtocontribute.rst)).

# License

Kworkflow is under GPL-2.0+
