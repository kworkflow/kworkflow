#!/usr/bin/env bash

include './src/kernel-tag.sh'
include './tests/unit/utils.sh'

# The variables below are holding the correct trailers
# with the outputs of the following command:
# git log --max-count <N> --format="%(trailers)"
#
# Where N is the number of commits to be printed.
# The above command's behavior is to print only the
# trailers. Also trailers from different commits are
# divided by an empty line.
#
# It's also important to mention that most variables holding
# trailer lines contain one additional trailer of a past commit
# that should not be affected by the operations, helping to
# indicate that we are not affecting older commits accidentaly.

# Correct trailers for --add-signed-off-by and -s
#
# This variable holds the trailers lines of the last 2 commits.
# The last one was reviewed as the first one was not.
CORRECT_SIGNED_HEAD='Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

# This variable holds the trailer lines of the last 4 commits.
# The last 3 were reviewed while the first one was not.
CORRECT_SIGNED_LOG='Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

# Correct trailers for --add-reviewed-by and -r
CORRECT_REVIEWED_HEAD='Signed-off-by: kw <kw@kwkw.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

CORRECT_REVIEWED_LOG='Signed-off-by: kw <kw@kwkw.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

# Often a maintainer will write both 'Reviewed-by' and
# 'Signed-off-by' trailer lines when they apply the changes
# presented in a patchset or pull/merge request. The two following
# variables are used to test this usual operation.
CORRECT_FULL_REVIEW_HEAD='Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

CORRECT_FULL_REVIEW_LOG='Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

# Correct trailers for --add-acked-by and -a
CORRECT_ACKED_HEAD='Signed-off-by: kw <kw@kwkw.xyz>
Acked-by: Michael Doe <michaeldoe@kwkw.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

CORRECT_ACKED_LOG='Signed-off-by: kw <kw@kwkw.xyz>
Acked-by: Michael Doe <michaeldoe@kwkw.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Acked-by: Michael Doe <michaeldoe@kwkw.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Acked-by: Michael Doe <michaeldoe@kwkw.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

# Correct trailers for --add-fixes and -f
#
# Writting the correct hash is needed. This has
# to be done during test runs, since hashes
# are randomly generated.
CORRECT_FIXES_HEAD='Signed-off-by: kw <kw@kwkw.xyz>
Fixes: <hash>

Signed-off-by: kw <kw@kwkw.xyz>'

# Correct trailers for --add-tested-by and -t
CORRECT_TESTED_HEAD='Signed-off-by: kw <kw@kwkw.xyz>
Tested-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

CORRECT_TESTED_LOG='Signed-off-by: kw <kw@kwkw.xyz>
Tested-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Tested-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Tested-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

# Correct trailers for --add-co-developed-by and -C
CORRECT_CO_DEVELOPED_HEAD='Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Bob Brown <bob.brown@mail.xyz>
Co-developed-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

CORRECT_CO_DEVELOPED_LOG='Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Bob Brown <bob.brown@mail.xyz>
Co-developed-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Bob Brown <bob.brown@mail.xyz>
Co-developed-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Bob Brown <bob.brown@mail.xyz>
Co-developed-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

# Correct trailers for --add-reported-by and -R
CORRECT_REPORTED_HEAD='Signed-off-by: kw <kw@kwkw.xyz>
Reported-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

CORRECT_REPORTED_LOG='Signed-off-by: kw <kw@kwkw.xyz>
Reported-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Reported-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Reported-by: Bob Brown <bob.brown@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

# Correct trailers when using once each:
# --add-acked-by    or -a
# --add-reviewed-by or -r
# --add-fixes       or -f
#
# This also requires a hash while running tests, assuming
# only the last commit fixes another one.
CORRECT_MULTI_CALL_LOG_1='Signed-off-by: kw <kw@kwkw.xyz>
Acked-by: Michael Doe <michaeldoe@kwkw.xyz>
Reviewed-by: John Doe <johndoe@kwkw.xyz>
Fixes: <hash>

Signed-off-by: kw <kw@kwkw.xyz>
Acked-by: Michael Doe <michaeldoe@kwkw.xyz>
Reviewed-by: John Doe <johndoe@kwkw.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Acked-by: Michael Doe <michaeldoe@kwkw.xyz>
Reviewed-by: John Doe <johndoe@kwkw.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

# Correct trailers when using:
# --add-co-developed-by or -C (twice)
# --add-reported-by     or -R
# --add-tested-by       or -t
# --add-reviewed-by     or -r
# --add-signed-off-by   or -s
#
# This variable helps to verify if trailers are being written
# in a typical expected order imposed by the kernel documentation
CORRECT_MULTI_CALL_LOG_2='Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Michael Doe <michaeldoe@mail.xyz>
Reported-by: Michael Doe <michaeldoe@mail.xyz>
Closes: http://link-to-bug.xyz.com
Co-developed-by: Michael Doe <michaeldoe@mail.xyz>
Signed-off-by: John Doe <johndoe@mail.xyz>
Co-developed-by: John Doe <johndoe@mail.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>
Tested-by: Jane Doe <janedoe@mail.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Michael Doe <michaeldoe@mail.xyz>
Reported-by: Michael Doe <michaeldoe@mail.xyz>
Closes: http://link-to-bug.xyz.com
Co-developed-by: Michael Doe <michaeldoe@mail.xyz>
Signed-off-by: John Doe <johndoe@mail.xyz>
Co-developed-by: John Doe <johndoe@mail.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>
Tested-by: Jane Doe <janedoe@mail.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>
Signed-off-by: Michael Doe <michaeldoe@mail.xyz>
Reported-by: Michael Doe <michaeldoe@mail.xyz>
Closes: http://link-to-bug.xyz.com
Co-developed-by: Michael Doe <michaeldoe@mail.xyz>
Signed-off-by: John Doe <johndoe@mail.xyz>
Co-developed-by: John Doe <johndoe@mail.xyz>
Signed-off-by: Jane Doe <janedoe@mail.xyz>
Tested-by: Jane Doe <janedoe@mail.xyz>
Reviewed-by: Jane Doe <janedoe@mail.xyz>

Signed-off-by: kw <kw@kwkw.xyz>'

# Hold the original directory to go back in every tear down
ORIGINAL_DIR="$PWD"

function setUp()
{
  cp --force 'tests/unit/samples/kernel-tag/patch_model.patch' "${SHUNIT_TMPDIR}/"
  cp --force 'tests/unit/samples/kernel-tag/patch_model_signed_off.patch' "${SHUNIT_TMPDIR}/"
  cp --force 'tests/unit/samples/kernel-tag/patch_model_full_review.patch' "${SHUNIT_TMPDIR}/"
  cp --force 'tests/unit/samples/kernel-tag/patch_model_reviewed.patch' "${SHUNIT_TMPDIR}/"
  cp --force 'tests/unit/samples/kernel-tag/patch_model_acked.patch' "${SHUNIT_TMPDIR}/"
  cp --force 'tests/unit/samples/kernel-tag/patch_model_fixes.patch' "${SHUNIT_TMPDIR}/"
  cp --force 'tests/unit/samples/kernel-tag/patch_model_tested.patch' "${SHUNIT_TMPDIR}/"
  cp --force 'tests/unit/samples/kernel-tag/patch_model_co_developed.patch' "${SHUNIT_TMPDIR}/"
  cp --force 'tests/unit/samples/kernel-tag/patch_model_reported.patch' "${SHUNIT_TMPDIR}/"
  cp --force 'tests/unit/samples/kernel-tag/patch_model_complete.patch' "${SHUNIT_TMPDIR}/"

  cd "$SHUNIT_TMPDIR" || {
    fail "(${LINENO}) It was not possible to move to temporary directory"
    return
  }

  # Setup git repository for test
  mk_fake_git

  # Start repository
  git config user.name kw
  git config user.email kw@kwkw.xyz
  mkdir fs
  touch fs/some_file
  git add patch_model.patch patch_model_reviewed.patch patch_model_acked.patch \
    patch_model_fixes.patch patch_model_tested.patch patch_model_co_developed.patch \
    patch_model_reported.patch patch_model_complete.patch
  git add fs/
  git commit --quiet --signoff --message 'Create files'

  # Simulate wrong change
  printf 'Wrong text' > fs/some_file
  git add fs/some_file
  git commit --quiet --signoff \
    --message 'fs: some_file: Fill file' \
    --message 'First'

  # Regular change
  touch fs/new_driver
  git add fs/new_driver
  git commit --quiet --signoff \
    --message 'fs: new_driver: Add new driver' \
    --message 'Second'

  # Bug fix
  printf 'Correct text' > fs/some_file
  git add fs/some_file
  git commit --quiet --signoff \
    --message 'fs: some_file: Fix bug' \
    --message 'Third'
}

function tearDown()
{
  cd "$ORIGINAL_DIR" || {
    fail "(${LINENO}) It was not possible to go back to original directory"
    return
  }
  if is_safe_path_to_remove "$SHUNIT_TMPDIR"; then
    rm --recursive --force "$SHUNIT_TMPDIR"
    mkdir --parents "$SHUNIT_TMPDIR"
  else
    fail "(${LINENO}) It was not possible to safely remove temporary directory"
    return
  fi
}

function test_tag_patch_single_option()
{
  local head2_msg

  kernel_tag_main --add-signed-off-by='Jane Doe <janedoe@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_signed_off.patch'
  git restore patch_model.patch

  kernel_tag_main -s'Jane Doe <janedoe@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_signed_off.patch'
  git restore patch_model.patch

  kernel_tag_main --add-reviewed-by='Jane Doe <janedoe@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_reviewed.patch'
  git restore patch_model.patch

  kernel_tag_main -r'Jane Doe <janedoe@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_reviewed.patch'
  git restore patch_model.patch

  kernel_tag_main --add-acked-by='Michael Doe <michaeldoe@kwkw.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_acked.patch'
  git restore patch_model.patch

  kernel_tag_main -a'Michael Doe <michaeldoe@kwkw.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_acked.patch'
  git restore patch_model.patch

  kernel_tag_main --add-tested-by='Bob Brown <bob.brown@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_tested.patch'
  git restore patch_model.patch

  kernel_tag_main -t'Bob Brown <bob.brown@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_tested.patch'
  git restore patch_model.patch

  kernel_tag_main --add-co-developed-by='Bob Brown <bob.brown@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_co_developed.patch'
  git restore patch_model.patch

  kernel_tag_main -C'Bob Brown <bob.brown@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_co_developed.patch'
  git restore patch_model.patch

  kernel_tag_main --add-reported-by='Bob Brown <bob.brown@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_reported.patch'
  git restore patch_model.patch

  kernel_tag_main -R'Bob Brown <bob.brown@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_reported.patch'
  git restore patch_model.patch

  head2_msg="$(git rev-parse --short=12 HEAD~2) (\"fs: some_file: Fill file\")"

  kernel_tag_main --add-fixes='HEAD~2' patch_model.patch
  sed --in-place "s/<hash>/${head2_msg}/g" patch_model_fixes.patch
  assertFileEquals 'patch_model.patch' 'patch_model_fixes.patch'
  git restore patch_model.patch patch_model_fixes.patch

  kernel_tag_main -f'HEAD~2' patch_model.patch
  sed --in-place "s/<hash>/${head2_msg}/g" patch_model_fixes.patch
  assertFileEquals 'patch_model.patch' 'patch_model_fixes.patch'
  git restore patch_model.patch patch_model_fixes.patch
}

function test_tag_patch_single_option_default()
{
  git config user.name 'Jane Doe'
  git config user.email 'janedoe@mail.xyz'

  kernel_tag_main -s patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_signed_off.patch'
  git restore patch_model.patch

  kernel_tag_main -r patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_reviewed.patch'
  git restore patch_model.patch

  git config user.name 'Michael Doe'
  git config user.email 'michaeldoe@kwkw.xyz'

  kernel_tag_main -a patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_acked.patch'
  git restore patch_model.patch

  git config user.name 'Bob Brown'
  git config user.email 'bob.brown@mail.xyz'

  kernel_tag_main -t patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_tested.patch'
  git restore patch_model.patch

  kernel_tag_main -C patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_co_developed.patch'
  git restore patch_model.patch

  kernel_tag_main -R patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_reported.patch'
  git restore patch_model.patch
}

function test_tag_patch_multi_options()
{
  local head2_msg

  kernel_tag_main -s'Jane Doe <janedoe@mail.xyz>' patch_model.patch
  kernel_tag_main -r'Jane Doe <janedoe@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_full_review.patch'
  git restore patch_model.patch

  kernel_tag_main -r'Jane Doe <janedoe@mail.xyz>' -s'Jane Doe <janedoe@mail.xyz>' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_full_review.patch'
  git restore patch_model.patch

  head2_msg="$(git rev-parse --short=12 HEAD~2) (\"fs: some_file: Fill file\")"
  sed --in-place "s/<hash>/${head2_msg}/g" patch_model_complete.patch

  kernel_tag_main --add-acked-by='Michael Doe <michaeldoe@kwkw.xyz>' patch_model.patch
  kernel_tag_main --add-reviewed-by='John Doe <johndoe@kwkw.xyz>' patch_model.patch
  kernel_tag_main --add-fixes='HEAD~2' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_complete.patch'
  git restore patch_model.patch

  kernel_tag_main -r'John Doe <johndoe@kwkw.xyz>' -a'Michael Doe <michaeldoe@kwkw.xyz>' -f'HEAD~2' patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_complete.patch'
  git restore patch_model.patch

  git config user.name 'Jane Doe'
  git config user.email 'janedoe@mail.xyz'

  kernel_tag_main -r -s patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_full_review.patch'
  git restore patch_model.patch

  kernel_tag_main -s -r patch_model.patch
  assertFileEquals 'patch_model.patch' 'patch_model_full_review.patch'
  git restore patch_model.patch
}

function test_tag_patch_repetition_avoidance()
{
  local output_msg

  output_msg="$(kernel_tag_main -s'Jane Doe <janedoe@mail.xyz>' -s'Jane Doe <janedoe@mail.xyz>' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_signed_off.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Signed-off-by: Jane Doe <janedoe@mail.xyz>'" "$output_msg"
  git restore patch_model.patch

  output_msg="$(kernel_tag_main -r'Jane Doe <janedoe@mail.xyz>' -r'Jane Doe <janedoe@mail.xyz>' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_reviewed.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Reviewed-by: Jane Doe <janedoe@mail.xyz>'" "$output_msg"
  git restore patch_model.patch

  output_msg="$(kernel_tag_main -r'Jane Doe <janedoe@mail.xyz>' -s'Jane Doe <janedoe@mail.xyz>' -r'Jane Doe <janedoe@mail.xyz>' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_full_review.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Reviewed-by: Jane Doe <janedoe@mail.xyz>'" "$output_msg"
  git restore patch_model.patch

  output_msg="$(kernel_tag_main -r'Jane Doe <janedoe@mail.xyz>' -s'Jane Doe <janedoe@mail.xyz>' -s'Jane Doe <janedoe@mail.xyz>' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_full_review.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Signed-off-by: Jane Doe <janedoe@mail.xyz>'" "$output_msg"
  git restore patch_model.patch

  output_msg="$(kernel_tag_main -a'Michael Doe <michaeldoe@kwkw.xyz>' -a'Michael Doe <michaeldoe@kwkw.xyz>' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_acked.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Acked-by: Michael Doe <michaeldoe@kwkw.xyz>'" "$output_msg"
  git restore patch_model.patch

  output_msg="$(kernel_tag_main -t'Bob Brown <bob.brown@mail.xyz>' -t'Bob Brown <bob.brown@mail.xyz>' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_tested.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Tested-by: Bob Brown <bob.brown@mail.xyz>'" "$output_msg"
  git restore patch_model.patch

  output_msg="$(kernel_tag_main -C'Bob Brown <bob.brown@mail.xyz>' -s'Bob Brown <bob.brown@mail.xyz>' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_co_developed.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Signed-off-by: Bob Brown <bob.brown@mail.xyz>'" "$output_msg"
  git restore patch_model.patch

  output_msg="$(kernel_tag_main -s'Bob Brown <bob.brown@mail.xyz>' -C'Bob Brown <bob.brown@mail.xyz>' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_co_developed.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Signed-off-by: Bob Brown <bob.brown@mail.xyz>'" "$output_msg"
  git restore patch_model.patch

  output_msg="$(kernel_tag_main -R'Bob Brown <bob.brown@mail.xyz>' -R'Bob Brown <bob.brown@mail.xyz>' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_reported.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Reported-by: Bob Brown <bob.brown@mail.xyz>'" "$output_msg"
  git restore patch_model.patch

}

function test_tag_patch_repetition_avoidance_default()
{
  local output_msg
  local head2_msg

  head2_msg="$(git rev-parse --short=12 HEAD~2) (\"fs: some_file: Fill file\")"
  sed --in-place "s/<hash>/${head2_msg}/g" patch_model_complete.patch

  git config --local user.name 'John Doe'
  git config --local user.email 'johndoe@kwkw.xyz'

  output_msg="$(kernel_tag_main -r -a'Michael Doe <michaeldoe@kwkw.xyz>' -r -f'HEAD~2' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_complete.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Reviewed-by: John Doe <johndoe@kwkw.xyz>'" "$output_msg"
  git restore patch_model.patch

  output_msg="$(kernel_tag_main -r -a'Michael Doe <michaeldoe@kwkw.xyz>' -a'Michael Doe <michaeldoe@kwkw.xyz>' -f'HEAD~2' patch_model.patch)"
  assertFileEquals 'patch_model.patch' 'patch_model_complete.patch'
  assertEquals "(${LINENO})" "Skipping duplicated trailer line: 'Acked-by: Michael Doe <michaeldoe@kwkw.xyz>'" "$output_msg"
  git restore patch_model.patch
}

function test_tag_commit_single_option()
{
  local original_commit
  local current_log
  local correct_fixed_value

  # Save SHA from current commit allowing tests to reset the repository
  original_commit="$(git rev-parse HEAD)"

  kernel_tag_main -s'Jane Doe <janedoe@mail.xyz>'
  current_log="$(git log --max-count 2 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_SIGNED_HEAD" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -s'Jane Doe <janedoe@mail.xyz>' 'HEAD~3'
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_SIGNED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -r'Jane Doe <janedoe@mail.xyz>'
  current_log="$(git log --max-count 2 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_REVIEWED_HEAD" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -r'Jane Doe <janedoe@mail.xyz>' 'HEAD~3'
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_REVIEWED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -a'Michael Doe <michaeldoe@kwkw.xyz>'
  current_log="$(git log --max-count 2 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_ACKED_HEAD" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -a'Michael Doe <michaeldoe@kwkw.xyz>' 'HEAD~3'
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_ACKED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -t'Bob Brown <bob.brown@mail.xyz>'
  current_log="$(git log --max-count 2 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_TESTED_HEAD" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -t'Bob Brown <bob.brown@mail.xyz>' 'HEAD~3'
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_TESTED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -C'Bob Brown <bob.brown@mail.xyz>'
  current_log="$(git log --max-count 2 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_CO_DEVELOPED_HEAD" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -C'Bob Brown <bob.brown@mail.xyz>' 'HEAD~3'
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_CO_DEVELOPED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -R'Bob Brown <bob.brown@mail.xyz>'
  current_log="$(git log --max-count 2 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_REPORTED_HEAD" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -R'Bob Brown <bob.brown@mail.xyz>' 'HEAD~3'
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_REPORTED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -f'HEAD~2'
  current_log="$(git log --max-count 2 --format="%(trailers)")"
  correct_fixed_value="$(git rev-parse --short=12 HEAD~2) (\"fs: some_file: Fill file\")"
  assertEquals "(${LINENO})" "${CORRECT_FIXES_HEAD//<hash>/$correct_fixed_value}" "$current_log"
  git reset --quiet --hard "$original_commit"
}

function test_tag_commit_single_option_default()
{
  local original_commit
  local current_log

  # Save SHA from current commit allowing tests to reset the repository
  original_commit="$(git rev-parse HEAD)"

  git config user.name 'Jane Doe'
  git config user.email 'janedoe@mail.xyz'

  kernel_tag_main -s HEAD~3
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_SIGNED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -r HEAD~3
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_REVIEWED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  git config user.name 'Michael Doe'
  git config user.email 'michaeldoe@kwkw.xyz'

  kernel_tag_main -a HEAD~3
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_ACKED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  git config user.name 'Bob Brown'
  git config user.email 'bob.brown@mail.xyz'

  kernel_tag_main -t HEAD~3
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_TESTED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -C HEAD~3
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_CO_DEVELOPED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -R HEAD~3
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_REPORTED_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"
}

function test_tag_commit_multi_options()
{
  local original_commit
  local current_log
  local correct_fixed_value

  # Save SHA from current commit allowing tests to reset the repository
  original_commit="$(git rev-parse HEAD)"

  kernel_tag_main -r'Jane Doe <janedoe@mail.xyz>' -s'Jane Doe <janedoe@mail.xyz>'
  current_log="$(git log --max-count 2 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_FULL_REVIEW_HEAD" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -r'Jane Doe <janedoe@mail.xyz>' -s'Jane Doe <janedoe@mail.xyz>' HEAD~3
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_FULL_REVIEW_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -a'Michael Doe <michaeldoe@kwkw.xyz>' -r'John Doe <johndoe@kwkw.xyz>' HEAD~3
  kernel_tag_main -f'HEAD~2'
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  correct_fixed_value="$(git rev-parse --short=12 HEAD~2) (\"fs: some_file: Fill file\")"
  assertEquals "(${LINENO})" "${CORRECT_MULTI_CALL_LOG_1//<hash>/$correct_fixed_value}" "$current_log"
  git reset --quiet --hard "$original_commit"

  kernel_tag_main -R'Michael Doe <michaeldoe@mail.xyz>;Closes=http://link-to-bug.xyz.com' \
    -C'Michael Doe <michaeldoe@mail.xyz>' \
    -C'John Doe <johndoe@mail.xyz>' \
    -t'Jane Doe <janedoe@mail.xyz>' \
    -r'Jane Doe <janedoe@mail.xyz>' \
    -s'Jane Doe <janedoe@mail.xyz>' HEAD~3
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_MULTI_CALL_LOG_2" "$current_log"
  git reset --quiet --hard "$original_commit"

  git config user.name 'Jane Doe'
  git config user.email 'janedoe@mail.xyz'

  kernel_tag_main -r -s HEAD~3
  current_log="$(git log --max-count 4 --format="%(trailers)")"
  assertEquals "(${LINENO})" "$CORRECT_FULL_REVIEW_LOG" "$current_log"
  git reset --quiet --hard "$original_commit"
}

# Simulating non-configured user.name and user.email by setting local empty values.
# This has to be tested this way because we CAN NOT unset git config using:
# 'git config --global --unset ( user.name | user.email )'
# Since this would affect user's global git configuration outside tests.
function test_tag_no_user_or_email_config()
{
  local output_msg
  local return_status

  git config user.name ''
  git config user.email ''

  output_msg="$(kernel_tag_main --add-signed-off-by)"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" \
    "You must configure your user.name and user.email with git to use --add-signed-off-by | -s without an argument" \
    "$output_msg"

  output_msg="$(kernel_tag_main --add-reviewed-by)"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" \
    "You must configure your user.name and user.email with git to use --add-reviewed-by | -r without an argument" \
    "$output_msg"

  output_msg="$(kernel_tag_main --add-acked-by)"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" \
    "You must configure your user.name and user.email with git to use --add-acked-by | -a without an argument" \
    "$output_msg"

  output_msg="$(kernel_tag_main --add-tested-by)"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" \
    "You must configure your user.name and user.email with git to use --add-tested-by | -t without an argument" \
    "$output_msg"

  output_msg="$(kernel_tag_main --add-co-developed-by)"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" \
    "You must configure your user.name and user.email with git to use --add-co-developed-by | -C without an argument" \
    "$output_msg"

  output_msg="$(kernel_tag_main --add-reported-by)"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" \
    "You must configure your user.name and user.email with git to use --add-reported-by | -R without an argument" \
    "$output_msg"
}

function test_tag_invalid_tag_format()
{
  local output_msg
  local return_status
  local expected_msg

  output_msg="$(kernel_tag_main --add-signed-off-by='Jane Doe <@mail.com>')"
  return_status="$?"
  expected_msg="$(printf 'Invalid email: @mail.com\nInvalid email format: Jane Doe <@mail.com>')"
  assertEquals "(${LINENO})" 74 "$return_status"
  assertEquals "(${LINENO})" "$expected_msg" "$output_msg"

  output_msg="$(kernel_tag_main --add-reviewed-by='<janedoe@mail.com>')"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" 'Invalid tag format: <janedoe@mail.com>' "$output_msg"

  output_msg="$(kernel_tag_main --add-acked-by='Jane Doe')"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" 'Invalid tag format: Jane Doe' "$output_msg"

  output_msg="$(kernel_tag_main --add-tested-by='Jane Doe janedoe@mail.com')"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" 'Invalid tag format: Jane Doe janedoe@mail.com' "$output_msg"

  output_msg="$(kernel_tag_main --add-co-developed-by='Jane Doe <janedoe@mailcom>')"
  return_status="$?"
  expected_msg="$(printf 'Invalid email: janedoe@mailcom\nInvalid email format: Jane Doe <janedoe@mailcom>')"
  assertEquals "(${LINENO})" 74 "$return_status"
  assertEquals "(${LINENO})" "$expected_msg" "$output_msg"
}

function test_tag_invalid_commit_reference()
{
  local output_msg
  local return_status

  output_msg="$(kernel_tag_main --add-fixes)"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" 'The option --add-fixes | -f demands an argument' "$output_msg"

  output_msg="$(kernel_tag_main --add-fixes='8ac76z12wac3')"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" 'Invalid commit reference with --add-fixes | -f: 8ac76z12wac3' "$output_msg"

  output_msg="$(kernel_tag_main --add-fixes='HEAD~9999')"
  return_status="$?"
  assertEquals "(${LINENO})" 22 "$return_status"
  assertEquals "(${LINENO})" 'Invalid commit reference with --add-fixes | -f: HEAD~9999' "$output_msg"
}

invoke_shunit
