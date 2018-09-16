#!/bin/bash

. ./kw.sh --source only
. ./src/checkpatch_wrapper.sh --source only

function suite
{
  suite_addTest "testCheckpatch"
}

function testCheckpatch
{
  test -e $external_script_path/checkpatch.pl; assertEquals "File checkpatch.pl does not exist" $? 0
  tmp_path="/tmp/kw_test"
  mkdir -p $tmp_path && wget \
    "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/plain/kernel/exit.c" \
    -q -O "${tmp_path}/exit.c"
  [[ "$?" -ne 0 ]] && fail "Could not download test file from https://git.kernel.org/ to $tmp_path"
  res=$(execute_checkpatch "${tmp_path}/exit.c" 2>&1 | tail -n 1);\
    [[ "$?" -ne 0 ]] && fail "Could not execute first codestyle run on ${tmp_path}/exit.c"
  printf ' %.0s' {1..100} >> "${tmp_path}/exit.c"
  nres=$(execute_checkpath "${tmp_path}/exit.c" 2>&1 | tail -n 1);\
    [[ "$?" -ne 0 ]] && fail "Could not execute second codestyle run on ${tmp_path}/exit.c"
  [ "$res" == "$nres" ] && fail "Codestyle did not capture warnings"
  true # Reset return value
}

. ./tests/shunit2
