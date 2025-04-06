#!/usr/bin/env bash

include './src/maintainers.sh'
include './tests/unit/utils.sh'

# TODO: make maintainers_main's tests cover more corner cases?

# The following variables hold the the lines print_files_authors should
# print when given the file samples/print_file_author_test_dir directory
# and samples/print_file_author_test_dir/code1.c file, respectively.
CORRECT_DIR_MSG="=========================================================
MODULE AUTHORS:
code1.c: John Doe <johndoe@community.com>, Caesar Doe <caesar@community.com>, Michael Doe <michael@community.com>
code2.c: Bob Hilson <bob@opensource.com>
multiline_authors_test.c: Martha Elsa <martha@opensource.com>, Verena Bert <vb@opensource.com>, Gabi Katinka <gabik@opensource.com>, Leonie Hildebert <leoni.hildebert@opensource.com>"
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

# Original directory path to go back before each test function
ORIGINAL_DIR="$PWD"

function oneTimeSetUp() {
  # This creates tests/.tmp which should mock a kernel tree root. A .git
  # dir is also created inside tests/.tmp so that get_maintainer.pl thinks
  # it is a git repo. This is done in order to avoid some warnings that
  # get_maintainer.pl prints when no .git is found.
  local original_dir="$PWD"
  mk_fake_kernel_root "$FAKE_KERNEL"
  cp -f tests/unit/samples/MAINTAINERS "$FAKE_KERNEL"/MAINTAINERS
  cp -f tests/unit/samples/external/get_maintainer.pl "$FAKE_KERNEL"/scripts/
  cp -f tests/unit/samples/update_patch_test{_model,}{,2}.patch "$FAKE_KERNEL"/
  cp --force 'tests/unit/samples/cover_letter_test.patch' "$FAKE_KERNEL"
  cd "$FAKE_KERNEL" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
  touch fs/some_file
  git init --quiet
  git add fs/some_file
  git config user.name kw
  git config user.email kw@kw
  git commit --quiet -m "Test message"
  cd "$original_dir" || {
    fail "(${LINENO}) It was not possible to move back from temp directory"
    return
  }

  parse_configuration "$KW_CONFIG_SAMPLE"
}

function oneTimeTearDown() {
  rm -rf "$FAKE_KERNEL"
}

function setUp() {
  # Ensure each test function starts running in ORIGINAL_DIR.
  cd "$ORIGINAL_DIR" || {
    fail "(${LINENO}) It was not possible to move to original dir"
    return
  }
}

function tearDown() {
  # Check if SHUNIT_TMPDIR can be safely removed and then remove it and remake it.
  is_safe_path_to_remove "$SHUNIT_TMPDIR"
  if [[ "$?" == 0 ]]; then
    rm --recursive --force "$SHUNIT_TMPDIR"
    mkdir --parents "$SHUNIT_TMPDIR"
  else
    fail 'It was not possible to safely remove SHUNIT tmp directory.'
  fi
}

function test_print_files_authors() {
  local -r ret=$(print_files_authors "tests/unit/samples/print_file_author_test_dir/code1.c")
  multilineAssertEquals "$CORRECT_FILE_MSG" "$ret"
}

function test_print_files_authors_from_dir() {
  local -r ret=$(print_files_authors "tests/unit/samples/print_file_author_test_dir")
  multilineAssertEquals "$CORRECT_DIR_MSG" "$ret"
}

function test_maintainers_main() {
  local ret

  ret="$(maintainers_main tests/.tmp)"
  multilineAssertEquals "$ret" "$CORRECT_TMP_MSG"

  cd "$FAKE_KERNEL" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
  ret="$(maintainers_main .)"
  multilineAssertEquals "$CORRECT_TMP_MSG" "$ret"

  ret="$(maintainers_main fs)"
  multilineAssertEquals "$CORRECT_TMP_FS_MSG" "$ret"

  cd fs || {
    fail "(${LINENO}) It was not possible to move to fs directory"
    return
  }
  ret="$(maintainers_main ..)"
  multilineAssertEquals "$CORRECT_TMP_MSG" "$ret"

  ret="$(maintainers_main .)"
  multilineAssertEquals "$CORRECT_TMP_FS_MSG" "$ret"
}

# This function tests expected behaviors for failure in
# parse_maintainers_options.
function test_parse_maintainers_options() {
  local return_status

  cd "$FAKE_KERNEL" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Invalid option (typo)
  unset options_values
  declare -gA options_values
  parse_maintainers_options --update-pacth # Messy argument
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"

  # Invalid option (even with a correct one following it)
  unset options_values
  declare -gA options_values
  parse_maintainers_options --update-patch --invalid-option
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"

  # Too many arguments
  unset options_values
  declare -gA options_values
  parse_maintainers_options --update-patch '.' 'some_file'
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
}

function test_maintainers_main_update_patch_invalid_inputs() {
  local return_status
  local output_from_maintainers_main

  cd "$FAKE_KERNEL" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  output_from_maintainers_main="$(maintainers_main --update-patch 'fs/some_file')"
  return_status="$?"
  assertEquals "(${LINENO})" 'Option --update-patch was passed but given path is not a patch.' "$output_from_maintainers_main"
  assertEquals "(${LINENO})" 1 "$return_status"

  output_from_maintainers_main="$(maintainers_main --update-patch 'cover_letter_test.patch')"
  return_status="$?"
  assertEquals "(${LINENO})" 'Option --update-patch was passed but given path is not a patch.' "$output_from_maintainers_main"
  assertEquals "(${LINENO})" 1 "$return_status"
}

# This function tests cases where the maintainers_main is called outside
# of a kernel tree and the given path is not in a kernel tree either.
function test_maintainers_main_no_kernel() {
  local return_status
  local output_from_maintainers_main

  # Going outside of a kernel tree
  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }
  mkdir 'not-a-kernel'

  # Testing with default value
  output_from_maintainers_main="$(maintainers_main)"
  return_status="$?"
  assertEquals "(${LINENO})" 'Neither the given path nor the working path is in a kernel tree.' "$output_from_maintainers_main"
  assertEquals "(${LINENO})" 1 "$return_status"

  # Testing while giving a path
  output_from_maintainers_main="$(maintainers_main ./not-a-kernel)"
  return_status="$?"
  assertEquals "(${LINENO})" 'Neither the given path nor the working path is in a kernel tree.' "$output_from_maintainers_main"
  assertEquals "(${LINENO})" 1 "$return_status"
}

# This function tests cases where the maintainers_main is called inside
# a kernel tree, but the given path is not a patch and is outside a kernel tree.
function test_maintainers_main_path_out_of_tree() {
  local return_status
  local output_from_maintainers_main

  cd "$FAKE_KERNEL" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  output_from_maintainers_main="$(maintainers_main ..)"
  return_status="$?"
  assertEquals "(${LINENO})" 'The given file is not a patch and is outside a kernel tree.' "$output_from_maintainers_main"
  assertEquals "(${LINENO})" 1 "$return_status"
}

# This function tests cases where the given paths to maintainers_main are invalid
function test_maintainers_main_invalid_paths() {
  local return_status
  local output_from_maintainers_main

  cd "$FAKE_KERNEL" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Test for files that don't exist in current directory
  output_from_maintainers_main="$(maintainers_main 'file-does-not-exist.c')"
  return_status="$?"
  assertEquals "(${LINENO})" 'Invalid path' "$output_from_maintainers_main"
  assertEquals "(${LINENO})" 1 "$return_status"

  # Test for files that don't exist in an other existing directory
  output_from_maintainers_main="$(maintainers_main "$SHUNIT_TMPDIR/not-a-file.c")"
  return_status="$?"
  assertEquals "(${LINENO})" 'Invalid path' "$output_from_maintainers_main"
  assertEquals "(${LINENO})" 1 "$return_status"
}

function test_maintainers_main_patch() {
  local return_status

  cd "$FAKE_KERNEL" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  return_status="$(maintainers_main update_patch_test.patch)"
  multilineAssertEquals "$CORRECT_TMP_MSG" "$return_status"

  # test -u
  cp -f update_patch_test.patch{,.bak}
  return_status="$(maintainers_main -u update_patch_test.patch)"
  multilineAssertEquals "$CORRECT_TMP_PATCH_MSG" "$return_status"
  assertFileEquals update_patch_test{,_model}.patch
  cp -f update_patch_test.patch{.bak,}

  # test --update-patch
  return_status="$(maintainers_main --update-patch update_patch_test.patch)"
  multilineAssertEquals "$CORRECT_TMP_PATCH_MSG" "$return_status"
  assertFileEquals update_patch_test{,_model}.patch

  # test for already existing maintainers
  return_status="$(maintainers_main -u update_patch_test.patch)"
  multilineAssertEquals "$CORRECT_TMP_PATCH_ALREADY_IN_MSG" "$return_status"
  assertFileEquals update_patch_test{,_model}.patch

  # test for already existing "To:" field without maintainers
  return_status="$(maintainers_main -u update_patch_test2.patch)"
  multilineAssertEquals "$CORRECT_TMP_PATCH2_MSG" "$return_status"
  assertFileEquals update_patch_test{,_model}2.patch
}

invoke_shunit
