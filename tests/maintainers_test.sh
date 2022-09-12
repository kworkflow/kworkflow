#!/bin/bash

include './src/maintainers.sh'
include './tests/utils.sh'

# TODO: make maintainers_main's tests cover more corner cases?

# The following variables hold the the lines print_files_authors should
# print when given the file samples/print_file_author_test_dir directory
# and samples/print_file_author_test_dir/code1.c file, respectively.
CORRECT_DIR_MSG="=========================================================
MODULE AUTHORS:
code1.c: John Doe <johndoe@community.com>, Caesar Doe <caesar@community.com>, Michael Doe <michael@community.com>
code2.c: Bob Hilson <bob@opensource.com>"
CORRECT_FILE_MSG="=========================================================
MODULE AUTHORS:
code1.c: John Doe <johndoe@community.com>, Caesar Doe <caesar@community.com>, Michael Doe <michael@community.com>"

# The following variables hold the the lines maintainers_main
# should print when given the path tests/.tmp and tests/.tmp/fs,
# respectively.
CORRECT_TMP_MSG="=========================================================
HERE:
Jane Doe <jane@email.com>,kernel@list.org"
CORRECT_TMP_FS_MSG="=========================================================
HERE:
John Doe <john@email.com>,Jane Doe <jane@email.com>,fs@list.org,kernel@list.org"

# The following variables hold the lines maintainers_main should
# print when given the option -u or --update-patch and the file
# tests/.tmp/update_patch_test and tests.tmp/update_patch_test2,
# respectively
CORRECT_TMP_PATCH_MSG="=========================================================
Patch update_patch_test.patch updated with the following maintainers:
Jane Doe <jane@email.com>,kernel@list.org"
CORRECT_TMP_PATCH2_MSG="=========================================================
Patch update_patch_test2.patch updated with the following maintainers:
Jane Doe <jane@email.com>,kernel@list.org"

# Same as above but when the maintainers list is already in the patch
CORRECT_TMP_PATCH_ALREADY_IN_MSG="=========================================================
Maintainers already in 'To:' field of update_patch_test.patch"

FAKE_KERNEL="tests/.tmp"

function oneTimeSetUp()
{
  # This creates tests/.tmp which should mock a kernel tree root. A .git
  # dir is also created inside tests/.tmp so that get_maintainer.pl thinks
  # it is a git repo. This is done in order to avoid some warnings that
  # get_maintainer.pl prints when no .git is found.
  local original_dir="$PWD"
  mk_fake_kernel_root "$FAKE_KERNEL"
  cp -f tests/samples/MAINTAINERS "$FAKE_KERNEL"/MAINTAINERS
  cp -f tests/external/get_maintainer.pl "$FAKE_KERNEL"/scripts/
  cp -f tests/samples/update_patch_test{_model,}{,2}.patch "$FAKE_KERNEL"/
  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  touch fs/some_file
  git init --quiet
  git add fs/some_file
  git commit --quiet -m "Test message"
  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  parse_configuration "$KW_CONFIG_SAMPLE"
}

function oneTimeTearDown()
{
  rm -rf "$FAKE_KERNEL"
}

function test_print_files_authors()
{
  local -r ret=$(print_files_authors "tests/samples/print_file_author_test_dir/code1.c")
  multilineAssertEquals "$ret" "$CORRECT_FILE_MSG"
}

function test_print_files_authors_from_dir()
{
  local -r ret=$(print_files_authors "tests/samples/print_file_author_test_dir")
  multilineAssertEquals "$ret" "$CORRECT_DIR_MSG"
}

function test_maintainers_main()
{
  local ret
  local -r original_dir="$PWD"

  ret="$(maintainers_main tests/.tmp)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_MSG"

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  ret="$(maintainers_main .)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_MSG"

  ret="$(maintainers_main fs)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_FS_MSG"

  cd fs || {
    fail "($LINENO) It was not possible to move to fs directory"
    return
  }
  ret="$(maintainers_main ..)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_MSG"

  ret="$(maintainers_main .)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_FS_MSG"
  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function test_maintainers_main_patch()
{
  local original_dir="$PWD"
  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  ret="$(maintainers_main update_patch_test.patch)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_MSG"

  # test -u
  cp -f update_patch_test.patch{,.bak}
  ret="$(maintainers_main -u update_patch_test.patch)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_PATCH_MSG"
  assertFileEquals update_patch_test{,_model}.patch
  cp -f update_patch_test.patch{.bak,}

  # test --update-patch
  ret="$(maintainers_main --update-patch update_patch_test.patch)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_PATCH_MSG"
  assertFileEquals update_patch_test{,_model}.patch

  # test for already existing maintainers
  ret="$(maintainers_main -u update_patch_test.patch)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_PATCH_ALREADY_IN_MSG"
  assertFileEquals update_patch_test{,_model}.patch

  # test for already existing "To:" field without maintainers
  ret="$(maintainers_main -u update_patch_test2.patch)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_PATCH2_MSG"
  assertFileEquals update_patch_test{,_model}2.patch

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

invoke_shunit
