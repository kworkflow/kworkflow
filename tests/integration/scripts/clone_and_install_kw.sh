#!/usr/bin/env bash

# The primary purpose of this file is to install kw's dependencies in the  image
# we will built. This will save up time when installing the local copy of KW  in
# the running container.
#
# We clone kw and install the unstable branch in order for the base image of the
# container to have all required dependencies. Later, the local KW repo will  be
# copied to the container and installed, but the dependencies won't have  to  be
# installed again, which saves a lot of time.

kw_dir='/tmp/kw'

git clone https://github.com/kworkflow/kworkflow "${kw_dir}"
cd "$kw_dir" || exit 1
git checkout unstable
./setup.sh --full-installation --force --skip-docs
