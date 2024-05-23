#!/usr/bin/env bash

include './src/handle_trailer.sh'
include './tests/unit/utils.sh'

# Correct trailers for --add-reviewed-by and -r
CORRECT_REVIEWED_COMMIT="Signed-off-by: kw <kw@kw>
Reviewed-by: John Doe <johndoe@community.com>

Signed-off-by: kw <kw@kw>"

CORRECT_REVIEWED_LOG="Signed-off-by: kw <kw@kw>
Reviewed-by: John Doe <johndoe@community.com>

Signed-off-by: kw <kw@kw>
Reviewed-by: John Doe <johndoe@community.com>

Signed-off-by: kw <kw@kw>
Reviewed-by: John Doe <johndoe@community.com>

Signed-off-by: kw <kw@kw>"

# Correct trailers for --add-acked-by and -a
CORRECT_ACKED_COMMIT="Signed-off-by: kw <kw@kw>
Acked-by: Michael Doe <michaeldoe@community.com>

Signed-off-by: kw <kw@kw>"

CORRECT_ACKED_LOG="Signed-off-by: kw <kw@kw>
Acked-by: Michael Doe <michaeldoe@community.com>

Signed-off-by: kw <kw@kw>
Acked-by: Michael Doe <michaeldoe@community.com>

Signed-off-by: kw <kw@kw>
Acked-by: Michael Doe <michaeldoe@community.com>

Signed-off-by: kw <kw@kw>"

# Correct trailers for --add-fixes and -f
# Appending the correct hash is needed. This has
# to be done during test runs, since hashes
# are randomly generated.
CORRECT_FIXED_COMMIT="Signed-off-by: kw <kw@kw>
Fixes: <hash>

Signed-off-by: kw <kw@kw>"

# Correct trailers when using adding Acked-by, then
# adding Reviewed-by and then adding Fixes.
# This also requires a hash while running tests.
CORRECT_COMPLETE_LOG="Signed-off-by: kw <kw@kw>
Acked-by: Michael Doe <michaeldoe@community.com>
Reviewed-by: John Doe <johndoe@community.com>
Fixes: <hash>

Signed-off-by: kw <kw@kw>
Acked-by: Michael Doe <michaeldoe@community.com>
Reviewed-by: John Doe <johndoe@community.com>

Signed-off-by: kw <kw@kw>
Acked-by: Michael Doe <michaeldoe@community.com>
Reviewed-by: John Doe <johndoe@community.com>

Signed-off-by: kw <kw@kw>"

function setUp()
{
  local -r current_path="$PWD"

  cp -r tests/unit/samples/handle_trailer_patch_samples/*.patch "$SHUNIT_TMPDIR"/

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  # Setup git repository for test
  mk_fake_git

  # Start repository
  git config user.name kw
  git config user.email kw@kw
  mkdir fs
  touch fs/some_file
  git add fs/
  git commit --quiet -s -m "fs: some_file: Fill file" -m "First"

  # Simulate wrong change
  echo 'Wrong text' > fs/some_file
  git add fs/some_file
  git commit --quiet -s -m "fs: some_file: Fill file" -m "First"

  # Regular change
  touch fs/new_driver
  git add fs/new_driver
  git commit --quiet -s -m "fs: new_driver: Add new driver" -m "Second"

  # Bug fix
  echo 'Correct text' > fs/some_file
  git add fs/some_file
  git commit --quiet -s -m "fs: some_file: Fix bug" -m "Third"

  cd "$current_path" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

function tearDown()
{
  rm -rf "$SHUNIT_TMPDIR"
  mkdir -p "$SHUNIT_TMPDIR"
}

# This function tests 'handle_trailer_main' for
# cases where the given argument is a patch.
function test_handle_trailer_main_patch()
{
  local original_dir="$PWD"
  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }

  # Testing --add-reviewed-by and -r with patch
  handle_trailer_main --add-reviewed-by "John Doe <johndoe@community.com>" patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_reviewed.patch'
  git restore patch_model.patch

  handle_trailer_main -r "John Doe <johndoe@community.com>" patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_reviewed.patch'
  git restore patch_model.patch

  # Testing --add-acked-by and -a with patch
  handle_trailer_main --add-acked-by "Michael Doe <michaeldoe@community.com>" patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_acked.patch'
  git restore patch_model.patch

  handle_trailer_main -a "Michael Doe <michaeldoe@community.com>" patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_acked.patch'
  git restore patch_model.patch

  # Testing --add-fixed and -f with patch
  head2_msg="$(git rev-parse --short=12 HEAD~2) (\"fs: some_file: Fill file\")"

  handle_trailer_main --add-fixes HEAD~2 patch_model.patch
  sed -i "s/<hash>/$head2_msg/g" patch_model_fixes.patch # Write trailer value with correct hash
  assertFileEquals 'patch_model.patch' 'patch_model_fixes.patch'
  git restore patch_model.patch patch_model_fixes.patch

  handle_trailer_main -f HEAD~2 patch_model.patch
  sed -i "s/<hash>/$head2_msg/g" patch_model_fixes.patch # Write trailer value with correct hash
  assertFileEquals 'patch_model.patch' 'patch_model_fixes.patch'
  git restore patch_model.patch patch_model_fixes.patch

  # Testing for multiple calls of handle_trailer_main with patch
  handle_trailer_main --add-reviewed-by "John Doe <johndoe@community.com>" patch_model.patch
  handle_trailer_main --add-acked-by "Michael Doe <michaeldoe@community.com>" patch_model.patch
  handle_trailer_main --add-fixes HEAD~2 patch_model.patch
  sed -i "s/<hash>/$head2_msg/g" patch_model_complete.patch # Write trailer value with correct hash
  assertFileEquals 'patch_model.patch' 'patch_model_complete.patch'
  git restore patch_model.patch patch_model_complete.patch

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }
}

# This function tests 'handle_trailer_main' for
# cases where the given argument is either empty
# (default behavior) or a valid commit reference.
function test_handle_trailer_main_commit()
{
  local original_dir="$PWD"
  local original_commit

  cd "$SHUNIT_TMPDIR" || {
    fail "($LINENO) It was not possible to move to temporary directory"
    return
  }
  # Save SHA from current commit allowing tests to reset the repository
  original_commit="$(git rev-parse HEAD)"

  # Testing --add-reviewed-by and -r for commits
  handle_trailer_main --add-reviewed-by "John Doe <johndoe@community.com>"
  current_log="$(git log -n 2 --format="%(trailers)")"
  assertEquals "($LINENO)" "$CORRECT_REVIEWED_COMMIT" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  handle_trailer_main -r "John Doe <johndoe@community.com>"
  current_log="$(git log -n 2 --format="%(trailers)")"
  assertEquals "($LINENO)" "$CORRECT_REVIEWED_COMMIT" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  handle_trailer_main --add-reviewed-by "John Doe <johndoe@community.com>" HEAD~3
  current_log="$(git log -n 4 --format="%(trailers)")"
  assertEquals "($LINENO)" "$CORRECT_REVIEWED_LOG" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  handle_trailer_main -r "John Doe <johndoe@community.com>" HEAD~3
  current_log="$(git log -n 4 --format="%(trailers)")"
  assertEquals "($LINENO)" "$CORRECT_REVIEWED_LOG" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  # Testing add-acked-by and -a for commits
  handle_trailer_main --add-acked-by "Michael Doe <michaeldoe@community.com>"
  current_log="$(git log -n 2 --format="%(trailers)")"
  assertEquals "($LINENO)" "$CORRECT_ACKED_COMMIT" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  handle_trailer_main -a "Michael Doe <michaeldoe@community.com>"
  current_log="$(git log -n 2 --format="%(trailers)")"
  assertEquals "($LINENO)" "$CORRECT_ACKED_COMMIT" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  handle_trailer_main --add-acked-by "Michael Doe <michaeldoe@community.com>" HEAD~3
  current_log="$(git log -n 4 --format="%(trailers)")"
  assertEquals "($LINENO)" "$CORRECT_ACKED_LOG" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  handle_trailer_main -a "Michael Doe <michaeldoe@community.com>" HEAD~3
  current_log="$(git log -n 4 --format="%(trailers)")"
  assertEquals "($LINENO)" "$CORRECT_ACKED_LOG" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  # Testing --add-fixes and -f for commits
  handle_trailer_main --add-fixes HEAD~2
  current_log="$(git log -n 2 --format="%(trailers)")"
  correct_fixed_value="$(git rev-parse --short=12 HEAD~2) (\"fs: some_file: Fill file\")"
  correct_output="$(sed "s/<hash>/$correct_fixed_value/g" <<< "$CORRECT_FIXED_COMMIT")"
  assertEquals "($LINENO)" "$correct_output" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  handle_trailer_main -f HEAD~2
  current_log="$(git log -n 2 --format="%(trailers)")"
  correct_fixed_value="$(git rev-parse --short=12 HEAD~2) (\"fs: some_file: Fill file\")"
  correct_output="$(sed "s/<hash>/$correct_fixed_value/g" <<< "$CORRECT_FIXED_COMMIT")"
  assertEquals "($LINENO)" "$correct_output" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  # Testing for multiple calls of handle_trailer_main with commits
  handle_trailer_main --add-acked-by "Michael Doe <michaeldoe@community.com>" HEAD~3
  handle_trailer_main --add-reviewed-by "John Doe <johndoe@community.com>" HEAD~3
  handle_trailer_main --add-fixes HEAD~2
  current_log="$(git log -n 4 --format="%(trailers)")"
  correct_fixed_value="$(git rev-parse --short=12 HEAD~2) (\"fs: some_file: Fill file\")"
  correct_output="$(sed "s/<hash>/$correct_fixed_value/g" <<< "$CORRECT_COMPLETE_LOG")"
  assertEquals "($LINENO)" "$correct_output" "$current_log"
  git reset --hard "$original_commit" > /dev/null

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back from temp directory"
    return
  }

  tearDown
}

invoke_shunit
