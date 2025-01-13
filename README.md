<img src="images/kw_logo.png" width="600" alt="kworkflow">

![Build Status](https://github.com/kworkflow/kworkflow/actions/workflows/unit_tests.yml/badge.svg?branch=unstable)
[![codecov](https://codecov.io/gh/kworkflow/kworkflow/branch/unstable/graph/badge.svg?token=ZQ52EK8VWF)](https://codecov.io/gh/kworkflow/kworkflow)
# About

kw has a simple mission: reduce the setup overhead of working with the Linux
kernel and provide tools to support developers in their daily tasks. If you
have a set of repeatable tasks that you usually perform while working in your
favorite kernel subsystem or similar, consider adding it as a part of kw.

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

Finally, you can use your browser to look at the **index.html** page. For
example:

```
firefox build/index.html
```

# Contributing

We are happy that you want to help us! If you are looking for a good starting
point, check
[those issues](https://github.com/kworkflow/kworkflow/issues?q=is%3Aopen+label%3A%22good+first+issue%22+-label%3A%22done%3A+wait+for+stable%22)
and don't forget to read our
[Contribuitor's Guide](https://kworkflow.org/content/howtocontribute.html)
(or [howtocontribute file](documentation/content/howtocontribute.rst)).

# Reach Out

The best way to get help or make suggestions is by creating
[issues](https://github.com/kworkflow/kworkflow/issues) or making a
[pull request](https://github.com/kworkflow/kworkflow/pulls), someone is
likely to reply to these in little time.

# License

Kworkflow is under GPL-2.0+
