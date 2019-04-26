=====================
  How to Contribute
=====================

.. contents::
   :depth: 1
   :local:
   :backlinks: none

.. highlight:: console

Overview
--------
The Linux Kernel and Git community inspired our contribution process. For
example, we copied-pasted part of the `Git documentation`__ related to the
“Signed-off-by” and modified it a little bit.

__ https://git-scm.com/docs/SubmittingPatches/2.3.5

Development Cycle and Branches
------------------------------
Our development cycle relies on two different branches:

1. **master**: We maintain the kw stable version in the master branch, and we
try our best to keep master working well for final users. If you only want to
use kw, this branch is perfect for you.

2. **ustable**: This branch has the kw latest version, and it is the
development branch. If you want to contribute to kw, base your work in this
branch.

.. warning::
   If you want to contribute to `kw`, use the **unstable** branch and send your
   pull requests to this branch.

From time to time, when we feel happy with the unstable version, we merge the
commit from the unstable version to master. The Figure below summarizes the
development cycle.

.. image:: ../images/dev_cycle.png
   :alt: Development cycle
   :align: center

.. note::
    One of our main goals it keeps kw stable, in this sense, **if you send a
    new patch do not forget to add tests**. If you want to know more about
    tests, take a look at `About Tests` page.

Certify Your Work by Adding Your "Signed-off-by: " Line
-------------------------------------------------------
.. seealso::
   The following text came from `git documentation`__, and it reflects the kw's
   view certify your work.

   __ https://git-scm.com/docs/SubmittingPatches/2.3.5

To improve tracking of who did what, we've borrowed the "sign-off" procedure
from the Linux kernel project on patches that are being emailed around.
Although core Git is a lot smaller project it is a good discipline to follow
it.

The sign-off is a simple line at the end of the explanation for the patch,
which certifies that you wrote it or otherwise have the right to pass it on as
an open-source patch.  The rules are pretty simple: if you can certify the
below Developer's Certificate of Origin (D-C-O):

.. important::
    By making a contribution to this project, I certify that:

    1. The contribution was created in whole or in part by me and I have the
    right to submit it under the open source license indicated in the file; or

    2. The contribution is based upon previous work that, to the best of my
    knowledge, is covered under an appropriate open source license and I have
    the right under that license to submit that work with modifications,
    whether created in whole or in part by me, under the same open source
    license (unless I am permitted to submit under a different license), as
    indicated in the file; or

    3. The contribution was provided directly to me by some other person who
    certified (a), (b) or (c) and I have not modified it.

    4. I understand and agree that this project and the contribution are public
    and that a record of the contribution (including all personal information I
    submit with it, including my sign-off) is maintained indefinitely and may
    be redistributed consistent with this project or the open source license(s)
    involved.

then you just add a line saying::

 Signed-off-by: Xpto Lalala Blabla <xpto@developer.example.org>

This line can be automatically added by Git if you run the git-commit
command with the `-s` option.

Notice that you can place your own Signed-off-by: line when forwarding somebody
else's patch with the above rules for D-C-O.  Indeed you are encouraged to do
so.  Do not forget to place an in-body "From: " line at the beginning to
properly attribute the change to its true author (see (2) above).

.. note::
  Also notice that a real name is used in the Signed-off-by: line. Please don't
  hide your real name.

