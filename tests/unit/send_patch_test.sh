#!/usr/bin/env bash

include './src/send_patch.sh'
include './tests/unit/utils.sh'

function oneTimeSetUp()
{
  declare -gr ORIGINAL_DIR="$PWD"
  declare -gr FAKE_GIT="$SHUNIT_TMPDIR/fake_git/"
  declare -gr FAKE_KERNEL="$FAKE_GIT/fake_kernel/"
  declare -ga test_config_opts=('test0' 'test1' 'test2' 'user.name' 'sendemail.smtpuser')

  export KW_ETC_DIR="$SHUNIT_TMPDIR/etc/"
  export KW_CACHE_DIR="$SHUNIT_TMPDIR/cache/"

  mk_fake_kernel_root "$FAKE_KERNEL"
  mkdir --parents "$KW_ETC_DIR/mail_templates/"

  touch "$KW_ETC_DIR/mail_templates/test1"
  printf '%s\n' 'sendemail.smtpserver=smtp.test1.com' > "$KW_ETC_DIR/mail_templates/test1"

  touch "$KW_ETC_DIR/mail_templates/test2"
  printf '%s\n' 'sendemail.smtpserver=smtp.test2.com' > "$KW_ETC_DIR/mail_templates/test2"

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git dir"
    exit "$ret"
  }

  mk_fake_git

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function oneTimeTearDown()
{
  rm --recursive --force "$FAKE_GIT"
}

function setUp()
{
  declare -gA options_values
  declare -gA set_confs
  declare -g _original_kw_cache_dir="$KW_CACHE_DIR"
  declare -g _checkpatch_test_cache="${SHUNIT_TMPDIR}/checkpatch_test_cache"
  mkdir --parents "${_checkpatch_test_cache}/patches"

  export KW_CACHE_DIR="$_checkpatch_test_cache"
  configurations['checkpatch_opts']=''
}

function tearDown()
{
  unset options_values
  unset set_confs
  rm --force "${FAKE_KERNEL}/scripts/checkpatch.pl"
  rm --recursive --force "$_checkpatch_test_cache"
  export KW_CACHE_DIR="$_original_kw_cache_dir"
}

# Installs @sample_script (from tests/unit/samples/scripts/) as the fake
# checkpatch.pl used by run_checkpatch_on_patches/mail_send during tests.
function install_fake_checkpatch()
{
  local sample_script="$1"
  local fake_checkpatch="${FAKE_KERNEL}/scripts/checkpatch.pl"

  cp "${SAMPLES_DIR}/scripts/${sample_script}" "$fake_checkpatch"
  chmod +x "$fake_checkpatch"
}

function test_validate_encryption()
{
  local ret

  # invalid values
  validate_encryption 'xpto' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$ret"

  validate_encryption 'rsa' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$ret"

  validate_encryption 'tlss' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$ret"

  validate_encryption 'ssll' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$ret"

  validate_encryption &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$ret"

  # valid values
  validate_encryption 'ssl'
  ret="$?"
  assert_equals_helper 'Expected no error for ssl' "$LINENO" 0 "$ret"

  validate_encryption 'tls'
  ret="$?"
  assert_equals_helper 'Expected no error for tls' "$LINENO" 0 "$ret"
}

function test_validate_email()
{
  local expected
  local output
  local ret

  # invalid values
  output="$(validate_email 'invalid email')"
  ret="$?"
  expected='Invalid email: invalid email'
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$ret"

  output="$(validate_email 'lalala')"
  ret="$?"
  expected='Invalid email: lalala'
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$ret"

  # valid values
  validate_email 'test@email.com'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" 0 "$ret"

  validate_email 'test123@serious.gov'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" 0 "$ret"
}

function test_find_commit_references()
{
  local output
  local ret

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Failed to move to temp dir"
    exit "$ret"
  }

  find_commit_references
  ret="$?"
  assert_equals_helper 'No arguments given' "$LINENO" 22 "$ret"

  find_commit_references @^
  ret="$?"
  assert_equals_helper 'Outside git repo should return 125' "$LINENO" 125 "$ret"

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  output="$(find_commit_references invalid_ref)"
  ret="$?"
  assert_equals_helper 'Invalid ref should not work' "$LINENO" 22 "$ret"
  assertTrue "($LINENO) Invalid ref should be empty" '[[ -z "$output" ]]'

  output="$(find_commit_references '@^..@')"
  ret="$?"
  assert_equals_helper '@^..@ should be a valid reference' "$LINENO" 0 "$ret"
  assertTrue "($LINENO) @^..@ should generate a reference" '[[ -n "$output" ]]'

  output="$(find_commit_references @)"
  ret="$?"
  assert_equals_helper '@ should be a valid reference' "$LINENO" 0 "$ret"
  assertTrue "($LINENO) @ should generate a reference" '[[ -n "$output" ]]'

  output="$(find_commit_references some args @ around)"
  ret="$?"
  assert_equals_helper '@ should be a valid reference' "$LINENO" 0 "$ret"
  assertTrue "($LINENO) @ should generate a reference" '[[ -n "$output" ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_validate_email_list()
{
  local expected
  local output
  local ret

  # invalid values
  output="$(validate_email_list 'invalid email')"
  ret="$?"
  expected='The given recipient: invalid email does not contain a valid e-mail.'
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$ret"

  output="$(validate_email_list 'lalala')"
  ret="$?"
  expected='The given recipient: lalala does not contain a valid e-mail.'
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$expected" "$output"
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$ret"

  output="$(validate_email_list 'name1@lala.com,name2@lala.xpto,LastName, FirstName <last.first@lala.com>,test123@serious.gov')"
  ret="$?"
  expected='The given recipient: LastName does not contain a valid e-mail.'
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$ret"

  # valid values
  validate_email_list 'test@email.com'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" 0 "$ret"

  validate_email_list 'name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>,test123@serious.gov'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" 0 "$ret"
}

function test_reposition_commit_count_arg()
{
  local output
  local expected

  output="$(reposition_commit_count_arg --any --amount --of --args)"
  expected=' "--any" "--amount" "--of" "--args"'
  assert_equals_helper 'Should not change arguments' "$LINENO" "$expected" "$output"

  output="$(reposition_commit_count_arg --arg='some options, lala')"
  expected=' "--arg=some options, lala"'
  assert_equals_helper 'Should correctly quote arguments' "$LINENO" "$expected" "$output"

  output="$(reposition_commit_count_arg -375)"
  expected=' -- -375'
  assert_equals_helper 'Should place count argument at the end' "$LINENO" "$expected" "$output"

  output="$(reposition_commit_count_arg --arg='some options, lala' -375)"
  expected=' "--arg=some options, lala" -- -375'
  assert_equals_helper 'Should handle multiple arguments' "$LINENO" "$expected" "$output"
}

function test_remove_blocked_recipients()
{
  local output
  local expected
  local recipients=$'test@mail.com\nXpto Lala <xpto@mail.com>\nlala@mail.com\n'
  recipients+=$'xpto.lala@mail.com'

  output="$(remove_blocked_recipients '' test)"
  assertTrue "($LINENO) Empty recipients." '[[ -z "$output" ]]'

  output="$(remove_blocked_recipients "$recipients" test)"
  expected="$recipients"
  multilineAssertEquals "($LINENO) Expected no change." "$expected" "$output"

  output="$(remove_blocked_recipients "$recipients" test@mail.com)"
  expected=$'Xpto Lala <xpto@mail.com>\nlala@mail.com\nxpto.lala@mail.com'
  multilineAssertEquals "($LINENO) Removing one email." "$expected" "$output"

  output="$(remove_blocked_recipients "$recipients" lala@mail.com)"
  expected=$'test@mail.com\nXpto Lala <xpto@mail.com>\nxpto.lala@mail.com'
  multilineAssertEquals "($LINENO) Removing one email." "$expected" "$output"

  output="$(remove_blocked_recipients "$recipients" test@mail.com,xpto@mail.com)"
  expected=$'lala@mail.com\nxpto.lala@mail.com'
  multilineAssertEquals "($LINENO) Removing two emails." "$expected" "$output"
}

function test_get_git_editor()
{
  local editor

  # Prefer git var GIT_EDITOR resolution; if the resolved editor is available,
  # it must be executable. Empty is also valid (no editors on the system).
  editor="$(get_git_editor)"
  if [[ -n "$editor" ]]; then
    assertTrue "($LINENO) Editor should be an available command" \
      'command -v "${editor%% *}" >/dev/null 2>&1'
  fi
}

function test_get_git_editor_fallback()
{
  local editor

  # Mock git so that git var GIT_EDITOR fails; function should fall back to
  # common editors available in PATH, or return empty if none found.
  # shellcheck disable=SC2329
  git()
  {
    [[ "$1" == var && "$2" == GIT_EDITOR ]] && return 1
    command git "$@"
  }

  editor="$(get_git_editor)"
  if [[ -n "$editor" ]]; then
    assertTrue "($LINENO) Editor should be one of the common editors" \
      '[[ " vim vi nano " =~ " $editor " ]]'
  fi

  unset -f git
}

function test_handle_cover_letter_post_send()
{
  local output ret save_path
  local edited_cov="${KW_CACHE_DIR}/.cov_letter_edited"
  local template_cov="${KW_CACHE_DIR}/.cov_letter_template"
  local flags_repr=" --to=test@email.com"

  # Setup: create directories and test files
  mkdir -p "${KW_CACHE_DIR}/patches"
  save_path="${SHUNIT_TMPDIR}/0000-cover-letter.patch"

  # Create edited and template files with different content
  printf 'template content\n' > "$template_cov"
  printf 'user edited cover letter\n' > "$edited_cov"

  # Test 1: simulate mode with edited cover letter → should save
  output=$(handle_cover_letter_post_send '--dry-run' '0' 'cover-letter' \
    "$edited_cov" "$template_cov" "$save_path" "$flags_repr" '0')
  ret="$?"
  assert_equals_helper "($LINENO) Simulate should save" "$LINENO" 0 "$ret"
  assertTrue "($LINENO) File should be saved" '[[ -f "$save_path" ]]'
  local file_content
  file_content=$(< "$save_path")
  assert_equals_helper "($LINENO) Saved content should match edited" "$LINENO" \
    'user edited cover letter' "$file_content"
  assertTrue "($LINENO) Output should mention saved path" \
    '[[ "$output" =~ "saved to" ]]'
  assertTrue "($LINENO) Output should include flags" \
    '[[ "$output" =~ "$flags_repr" ]]'

  # Test 2: failure mode with edited cover letter → should save (different message)
  rm -f "$save_path"
  output=$(handle_cover_letter_post_send '' '1' 'cover-letter' \
    "$edited_cov" "$template_cov" "$save_path" "$flags_repr" '0')
  ret="$?"
  assert_equals_helper "($LINENO) Failure should save" "$LINENO" 0 "$ret"
  assertTrue "($LINENO) File should be saved on failure" '[[ -f "$save_path" ]]'
  assertTrue "($LINENO) Output should mention failure" \
    '[[ "$output" =~ "sending failed" ]]'

  # Test 3: unedited (same content as template) → should NOT save
  cp "$template_cov" "$edited_cov"
  rm -f "$save_path"
  output=$(handle_cover_letter_post_send '--dry-run' '0' 'cover-letter' \
    "$edited_cov" "$template_cov" "$save_path" "$flags_repr" '0')
  ret="$?"
  assert_equals_helper "($LINENO) Unedited should not save" "$LINENO" 1 "$ret"
  assertTrue "($LINENO) File should NOT exist" '[[ ! -f "$save_path" ]]'

  # Test 4: no cover letter → should NOT save
  printf 'content' > "$edited_cov"
  rm -f "$save_path"
  output=$(handle_cover_letter_post_send '--dry-run' '0' '' \
    "$edited_cov" "$template_cov" "$save_path" "$flags_repr" '0')
  ret="$?"
  assert_equals_helper "($LINENO) No cover letter should not save" "$LINENO" 1 "$ret"

  # Test 5: success (no simulate, no failure) → should NOT save
  cp "$template_cov" "$edited_cov" # reset edited to different content
  printf 'different content\n' > "$edited_cov"
  rm -f "$save_path"
  output=$(handle_cover_letter_post_send '' '0' 'cover-letter' \
    "$edited_cov" "$template_cov" "$save_path" "" '0')
  ret="$?"
  assert_equals_helper "($LINENO) Success should not save" "$LINENO" 1 "$ret"

  # Test 6: edited file doesn't exist → should NOT save
  rm -f "$edited_cov"
  rm -f "$save_path"
  output=$(handle_cover_letter_post_send '--dry-run' '0' 'cover-letter' \
    "$edited_cov" "$template_cov" "$save_path" "" '0')
  ret="$?"
  assert_equals_helper "($LINENO) No edited file should not save" "$LINENO" 1 "$ret"

  # Test 7: name collision, user answers No → timestamp-prefixed file saved
  printf 'user edited cover letter\n' > "$edited_cov"
  printf 'template content\n' > "$template_cov"
  printf 'existing cover letter\n' > "$save_path"
  output=$(printf 'n\n' | handle_cover_letter_post_send '--dry-run' '0' 'cover-letter' \
    "$edited_cov" "$template_cov" "$save_path" "$flags_repr" '0')
  ret="$?"
  assert_equals_helper "($LINENO) Collision (no) should save" "$LINENO" 0 "$ret"
  assertTrue "($LINENO) Original file should still exist" \
    '[[ -f "$save_path" ]]'
  local original_content
  original_content=$(< "$save_path")
  assert_equals_helper "($LINENO) Original file should be unchanged" "$LINENO" \
    'existing cover letter' "$original_content"
  local _dir _found
  _dir="${save_path%/*}"
  _found=''
  for f in "$_dir"/0000-cover-letter.kw-*.patch; do
    [[ -f "$f" ]] && _found="$f" && break
  done
  assertTrue "($LINENO) Timestamped file should exist" '[[ -n "$_found" ]]'
  assertTrue "($LINENO) Output should mention timestamped path" \
    '[[ "$output" =~ "0000-cover-letter.kw-"[0-9][0-9]"-"[0-9][0-9]"-"[0-9][0-9]"_"[0-9][0-9][0-9][0-9][0-9][0-9]".patch" ]]'

  # Test 8: name collision, user answers Yes → overwrite existing file
  rm -f "$_found"
  printf 'user edited cover letter\n' > "$edited_cov"
  printf 'different template\n' > "$template_cov"
  printf 'existing cover letter\n' > "$save_path"
  output=$(printf 'y\n' | handle_cover_letter_post_send '--dry-run' '0' 'cover-letter' \
    "$edited_cov" "$template_cov" "$save_path" "$flags_repr" '0')
  ret="$?"
  assert_equals_helper "($LINENO) Collision (yes) should save" "$LINENO" 0 "$ret"
  assertTrue "($LINENO) File should be overwritten" '[[ -f "$save_path" ]]'
  local overwritten_content
  overwritten_content=$(< "$save_path")
  assert_equals_helper "($LINENO) Overwritten content should match edited" "$LINENO" \
    'user edited cover letter' "$overwritten_content"

  # Test 9: name collision, user-provided file → no prompt, overwrite
  printf 'user edited cover letter\n' > "$edited_cov"
  printf 'different template\n' > "$template_cov"
  printf 'previous content\n' > "$save_path"
  output=$(handle_cover_letter_post_send '--dry-run' '0' 'cover-letter' \
    "$edited_cov" "$template_cov" "$save_path" "$flags_repr" '1')
  ret="$?"
  assert_equals_helper "($LINENO) User-provided should save" "$LINENO" 0 "$ret"
  assertTrue "($LINENO) User-provided should overwrite" '[[ -f "$save_path" ]]'
  local ov_content
  ov_content=$(< "$save_path")
  assert_equals_helper "($LINENO) User-provided content should match" "$LINENO" \
    'user edited cover letter' "$ov_content"
  assertTrue "($LINENO) Should NOT show override prompt for user-provided" \
    '! [[ "$output" =~ "Will save cover letter as" ]]'

  # Cleanup
  rm -f "$edited_cov" "$template_cov" "$save_path" "$(dirname "$save_path")"/0000-cover-letter.kw-*.patch
}

function test_mail_send_cover_letter_auto_save_on_simulate()
{
  local output saved_opts

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git dir"
    exit "$ret"
  }

  # Setup: multi-patch range + simulate
  saved_opts="${send_patch_config[send_opts]}"
  send_patch_config[send_opts]='--annotate --cover-letter --no-chain-reply-to --thread'
  parse_mail_options '--simulate' '@^^'

  # Pre-create the edited and template files (simulates what the GIT_EDITOR
  # wrapper would have created during a real git send-email execution)
  printf 'template text\n' > "${KW_CACHE_DIR}/.cov_letter_template"
  printf 'user edited cover letter content\n' > "${KW_CACHE_DIR}/.cov_letter_edited"

  output=$(mail_send 'TEST_MODE')

  # The cover letter should be saved to $PWD
  assertTrue "($LINENO) Cover letter should be saved to PWD" \
    '[[ -f "$PWD/0000-cover-letter.patch" ]]'

  local file_content
  file_content=$(< "$PWD/0000-cover-letter.patch")
  assert_equals_helper "($LINENO) Saved content mismatch" "$LINENO" \
    'user edited cover letter content' "$file_content"

  assertTrue "($LINENO) Output should mention saved message" \
    '[[ "$output" =~ "cover letter written" ]]'

  # Restore original config
  send_patch_config[send_opts]="$saved_opts"

  # Cleanup
  rm -f "$PWD/0000-cover-letter.patch"
  rm -f "${KW_CACHE_DIR}/.cov_letter_template" \
    "${KW_CACHE_DIR}/.cov_letter_edited"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_mail_send_cover_letter_auto_save_not_on_success()
{
  local output saved_opts

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git dir"
    exit "$ret"
  }

  # Setup: multi-patch range, NO simulate
  saved_opts="${send_patch_config[send_opts]}"
  send_patch_config[send_opts]='--annotate --cover-letter --no-chain-reply-to --thread'
  parse_mail_options '@^^'

  printf 'user edited cover letter content\n' > "${KW_CACHE_DIR}/.cov_letter_edited"
  printf 'template text\n' > "${KW_CACHE_DIR}/.cov_letter_template"

  output=$(mail_send 'TEST_MODE')

  # Cover letter should NOT be saved (successful send, no --simulate)
  assertTrue "($LINENO) Cover letter should NOT be saved on success" \
    '[[ ! -f "$PWD/0000-cover-letter.patch" ]]'

  assertTrue "($LINENO) Output should NOT contain saved message" \
    '[[ ! "$output" =~ "saved to" ]]'

  # Restore original config
  send_patch_config[send_opts]="$saved_opts"

  # Cleanup
  rm -f "${KW_CACHE_DIR}/.cov_letter_template" \
    "${KW_CACHE_DIR}/.cov_letter_edited"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}
function test_mail_send_no_available_editor()
{
  local output saved_opts _saved_func

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git dir"
    exit "$ret"
  }

  # Save and override get_git_editor to simulate no editor available
  _saved_func=$(declare -f get_git_editor)
  # shellcheck disable=SC2329
  get_git_editor()
  {
    return 1
  }

  saved_opts="${send_patch_config[send_opts]}"
  send_patch_config[send_opts]='--annotate --cover-letter --no-chain-reply-to --thread'
  parse_mail_options '@^^'

  output=$(mail_send 'TEST_MODE' 2>&1)

  # No wrapper should be created
  assertTrue "($LINENO) Wrapper should not exist" \
    '[[ ! -f "${KW_CACHE_DIR}/.editor_wrapper.sh" ]]'

  # Command should still run (warning suppressed in TEST_MODE)
  assertTrue "($LINENO) git send-email command should be in output" \
    '[[ "$output" =~ "git send-email" ]]'

  # Restore original environment
  send_patch_config[send_opts]="$saved_opts"
  if [[ -n "$_saved_func" ]]; then
    eval "$_saved_func"
  fi

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back"
    exit "$ret"
  }
}

function test_mail_parser()
{
  local output
  local expected
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git dir"
    exit "$ret"
  }

  # Invalid options
  parse_mail_options '-t' '--smtpuser'
  ret="$?"
  assert_equals_helper 'Option without argument' "$LINENO" 22 "$ret"

  output=$(parse_mail_options '--name' 'Xpto')
  ret="$?"
  assert_equals_helper 'Option without --setup' "$LINENO" 95 "$ret"

  parse_mail_options '--smtpLalaXpto' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option passed' "$LINENO" 22 "$ret"

  parse_mail_options '--wrongOption' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option passed' "$LINENO" 22 "$ret"

  # valid options
  parse_mail_options some -- extra -1 args HEAD^
  expected='some extra args HEAD^ -1'
  assert_equals_helper 'Set passthrough options' "$LINENO" "$expected" "${options_values['PASS_OPTION_TO_SEND_EMAIL']}"
  assert_equals_helper 'Set passthrough options' "$LINENO" '-1 HEAD^' "${options_values['COMMIT_RANGE']}"

  parse_mail_options -- --subject-prefix="PATCH i-g-t" HEAD^
  expected="'--subject-prefix=PATCH i-g-t' HEAD^"
  assert_equals_helper 'Set passthrough options with space' "$LINENO" "$expected" "${options_values['PASS_OPTION_TO_SEND_EMAIL']}"

  parse_mail_options -s -- 0000-cover-letter.kw-26-07-29_122608.patch
  expected='0000-cover-letter.kw-26-07-29_122608.patch'
  assert_equals_helper '-26 in filename should not be parsed as commit count' "$LINENO" \
    "$expected" "${options_values['PASS_OPTION_TO_SEND_EMAIL']}"
  assert_equals_helper '-26 in filename should not set COMMIT_RANGE' "$LINENO" \
    '' "${options_values['COMMIT_RANGE']}"

  parse_mail_options -375
  expected='-375'
  assert_equals_helper 'Set commit count option' "$LINENO" "$expected" "${options_values['PASS_OPTION_TO_SEND_EMAIL']}"
  assert_equals_helper 'Set commit count option' "$LINENO" "$expected " "${options_values['COMMIT_RANGE']}"

  parse_mail_options -v3
  expected='-v3'
  assert_equals_helper 'Set version option' "$LINENO" "$expected" "${options_values['PATCH_VERSION']}"

  expected='-v3 @^'
  assert_equals_helper 'Set version option' "$LINENO" "$expected" "${options_values['PASS_OPTION_TO_SEND_EMAIL']}"
  assert_equals_helper 'Set version option' "$LINENO" '@^' "${options_values['COMMIT_RANGE']}"

  # version flag must precede commit count so git send-email accepts it
  parse_mail_options -8 -v3
  expected='-v3'
  assert_equals_helper 'Set version with commit count: PATCH_VERSION' "$LINENO" "$expected" "${options_values['PATCH_VERSION']}"
  expected='-v3 -8'
  assert_equals_helper 'Set version with commit count: PASS_OPTION_TO_SEND_EMAIL' "$LINENO" "$expected" "${options_values['PASS_OPTION_TO_SEND_EMAIL']}"

  # The trailing space in '-8 ' comes from send_patch.sh appending a space after the commit count
  # (options_values['COMMIT_RANGE']+="$commit_count "). reposition_commit_count_arg injects '--'
  # before '-8' when no '--' is explicitly passed, which triggers that code path.
  assert_equals_helper 'Set version with commit count: COMMIT_RANGE' "$LINENO" '-8 ' "${options_values['COMMIT_RANGE']}"

  parse_mail_options '--no-checkpatch'
  assert_equals_helper 'Set no-checkpatch flag' "$LINENO" 1 "${options_values['NO_CHECKPATCH']}"

  parse_mail_options '--send'
  assert_equals_helper 'Set send flag' "$LINENO" 1 "${options_values['SEND']}"

  parse_mail_options '--verbose'
  assert_equals_helper 'Set verbose option' "$LINENO" 1 "${options_values['VERBOSE']}"

  parse_mail_options '--private'
  expected='--suppress-cc=all'
  assert_equals_helper 'Set private flag' "$LINENO" "$expected" "${options_values['PRIVATE']}"

  parse_mail_options '--rfc'
  expected='--rfc'
  assert_equals_helper 'Set rfc flag' "$LINENO" "$expected" "${options_values['RFC']}"

  parse_mail_options '--to=some@mail.com'
  expected='some@mail.com'
  assert_equals_helper 'Set to flag' "$LINENO" "$expected" "${options_values['TO']}"

  parse_mail_options '--cc=some@mail.com'
  expected='some@mail.com'
  assert_equals_helper 'Set cc flag' "$LINENO" "$expected" "${options_values['CC']}"

  parse_mail_options '--simulate'
  expected='--dry-run'
  assert_equals_helper 'Set simulate flag' "$LINENO" "$expected" "${options_values['SIMULATE']}"

  parse_mail_options '--keep-patch-files'
  expected=1
  assert_equals_helper 'Set keep-patch-files flag' "$LINENO" "$expected" "${options_values['KEEP_PATCH_FILES']}"

  parse_mail_options '-k'
  expected=1
  assert_equals_helper 'Set keep-patch-files short flag' "$LINENO" "$expected" "${options_values['KEEP_PATCH_FILES']}"

  parse_mail_options '--to=name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>'
  expected='name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>'
  assert_equals_helper 'Set to flag' "$LINENO" "$expected" "${options_values['TO']}"

  parse_mail_options '--setup'
  expected=1
  assert_equals_helper 'Set setup flag' "$LINENO" "$expected" "${options_values['SETUP']}"

  parse_mail_options '--force'
  expected=1
  assert_equals_helper 'Set force flag' "$LINENO" "$expected" "${options_values['FORCE']}"

  parse_mail_options '--verify'
  expected_result=1
  assert_equals_helper 'Set verify flag' "$LINENO" "$expected_result" "${options_values['VERIFY']}"

  parse_mail_options '--template'
  expected_result=':'
  assert_equals_helper 'Template without options' "$LINENO" "$expected_result" "${options_values['TEMPLATE']}"

  parse_mail_options '--template=test'
  expected_result=':test'
  assert_equals_helper 'Set template flag' "$LINENO" "$expected_result" "${options_values['TEMPLATE']}"

  parse_mail_options '--template=  Test '
  expected_result=':test'
  assert_equals_helper 'Set template flag, case and spaces' "$LINENO" "$expected_result" "${options_values['TEMPLATE']}"

  parse_mail_options '--interactive'
  expected_result='parser'
  assert_equals_helper 'Set interactive flag' "$LINENO" "$expected_result" "${options_values['INTERACTIVE']}"

  parse_mail_options '--no-interactive'
  expected_result=1
  assert_equals_helper 'Set no-interactive flag' "$LINENO" "$expected_result" "${options_values['NO_INTERACTIVE']}"

  expected=''
  assert_equals_helper 'Unset local or global flag' "$LINENO" "$expected" "${options_values['CMD_SCOPE']}"

  expected='local'
  assert_equals_helper 'Unset local or global flag' "$LINENO" "$expected" "${options_values['SCOPE']}"

  parse_mail_options '--local'
  assert_equals_helper 'Set local flag' "$LINENO" "$expected" "${options_values['SCOPE']}"
  assert_equals_helper 'Set local flag' "$LINENO" "$expected" "${options_values['CMD_SCOPE']}"

  parse_mail_options '--global'
  expected='global'
  assert_equals_helper 'Set global flag' "$LINENO" "$expected" "${options_values['SCOPE']}"
  assert_equals_helper 'Set global flag' "$LINENO" "$expected" "${options_values['CMD_SCOPE']}"

  parse_mail_options '-t' '--name' 'Xpto Lala'
  expected='Xpto Lala'
  assert_equals_helper 'Set name' "$LINENO" "$expected" "${options_values['user.name']}"

  parse_mail_options '-t' '--email' 'test@email.com'
  expected='test@email.com'
  assert_equals_helper 'Set email' "$LINENO" "$expected" "${options_values['user.email']}"

  parse_mail_options '-t' '--smtpuser' 'test@email.com'
  expected='test@email.com'
  assert_equals_helper 'Set smtp user' "$LINENO" "$expected" "${options_values['sendemail.smtpuser']}"

  parse_mail_options '-t' '--smtpencryption' 'tls'
  expected='tls'
  assert_equals_helper 'Set smtp encryption to tls' "$LINENO" "$expected" "${options_values['sendemail.smtpencryption']}"

  parse_mail_options '-t' '--smtpencryption' 'ssl'
  expected='ssl'
  assert_equals_helper 'Set smtp encryption to ssl' "$LINENO" "$expected" "${options_values['sendemail.smtpencryption']}"

  parse_mail_options '-t' '--smtpserver' 'test.email.com'
  expected='test.email.com'
  assert_equals_helper 'Set smtp server' "$LINENO" "$expected" "${options_values['sendemail.smtpserver']}"

  parse_mail_options '-t' '--smtpserverport' '123'
  expected='123'
  assert_equals_helper 'Set smtp serverport' "$LINENO" "$expected" "${options_values['sendemail.smtpserverport']}"

  parse_mail_options '-t' '--smtppass' 'verySafePass'
  expected='verySafePass'
  assert_equals_helper 'Set smtp pass' "$LINENO" "$expected" "${options_values['sendemail.smtppass']}"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }

}

function test_mail_send()
{
  local expected
  local output
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  parse_mail_options

  output=$(mail_send 'TEST_MODE')
  expected='git send-email @^'
  assert_equals_helper 'Testing send without options' "$LINENO" "$expected" "$output"

  parse_mail_options '--to=mail@test.com'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" @^'
  assert_equals_helper 'Testing send with to option' "$LINENO" "$expected" "$output"

  parse_mail_options '--to=name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>,test123@serious.gov'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>,test123@serious.gov" @^'
  assert_equals_helper 'Testing send with to option' "$LINENO" "$expected" "$output"

  parse_mail_options '--cc=mail@test.com'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --cc="mail@test.com" @^'
  assert_equals_helper 'Testing send with c option' "$LINENO" "$expected" "$output"

  parse_mail_options '--cc=name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>,test123@serious.gov'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --cc="name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>,test123@serious.gov" @^'
  assert_equals_helper 'Testing send with cc option' "$LINENO" "$expected" "$output"

  parse_mail_options '--simulate'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --dry-run @^'
  assert_equals_helper 'Testing send with simulate option' "$LINENO" "$expected" "$output"

  parse_mail_options '--private'

  output=$(mail_send 'TEST_MODE')
  expected="git send-email --suppress-cc=all @^"
  assert_equals_helper 'Testing send with to option' "$LINENO" "$expected" "$output"

  parse_mail_options '--rfc'

  output=$(mail_send 'TEST_MODE')
  expected="git send-email --rfc @^"
  assert_equals_helper 'Testing send with rfc option' "$LINENO" "$expected" "$output"

  parse_mail_options '--to=mail@test.com' 'HEAD~'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" HEAD~'
  assert_equals_helper 'Testing send with patch option' "$LINENO" "$expected" "$output"

  parse_mail_options '--to=mail@test.com' -13 -v2 extra_args -- --other_arg

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" -v2 extra_args --other_arg -13'
  assert_equals_helper 'Testing no options option' "$LINENO" "$expected" "$output"

  parse_mail_options '--to=mail@test.com'

  parse_configuration "$KW_MAIL_CONFIG_SAMPLE" send_patch_config
  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" --annotate  --no-chain-reply-to --thread @^'
  assert_equals_helper 'Testing default option' "$LINENO" "$expected" "$output"

  parse_mail_options '--to=mail@test.com' '@^^'
  parse_configuration "$KW_CONFIG_SAMPLE"

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" --annotate --cover-letter --no-chain-reply-to --thread @^^'
  assert_equals_helper 'Testing default option' "$LINENO" "$expected" "$output"

  # Test with --keep-patch-files (single patch, no cover letter)
  local saved_opts
  saved_opts="${send_patch_config[send_opts]}"
  send_patch_config[send_opts]=''
  parse_mail_options '--keep-patch-files'
  output=$(mail_send 'TEST_MODE')
  expected="git send-email @^"
  expected+=$'\n'"git format-patch --output-directory=$PWD @^"
  expected+=$'\n'"Patch files saved to $PWD"
  assert_equals_helper 'Testing keep-patch-files option' "$LINENO" "$expected" "$output"

  # Test with --keep-patch-files and --to (single patch)
  parse_mail_options '--keep-patch-files' '--to=mail@test.com'
  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" @^'
  expected+=$'\n'"git format-patch --output-directory=$PWD @^"
  expected+=$'\n'"Patch files saved to $PWD"
  assert_equals_helper 'Testing keep-patch-files with --to option' "$LINENO" "$expected" "$output"
  send_patch_config[send_opts]="$saved_opts"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_mail_send_keep_patch_files_with_existing_patches()
{
  local output ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    return "$ret"
  }

  cat > '0001-fake.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH] test

diff --git a/file b/file
index 0000000..1111111 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-old
+new
EOF

  parse_mail_options -k -- 0001-fake.patch
  output=$(mail_send 'TEST_MODE')

  assertTrue "($LINENO) Should include the .patch file" \
    '[[ "$output" =~ 0001-fake\.patch ]]'
  assertTrue "($LINENO) Should include format-patch command" \
    '[[ "$output" =~ "git format-patch" ]]'
  assertTrue "($LINENO) Should show saved message" \
    '[[ "$output" =~ "Patch files saved" ]]'
  assertTrue "($LINENO) Should NOT include @^ as default range" \
    '! [[ "$output" =~ "@\^" ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to return to original dir"
    return "$ret"
  }
}

function test_run_checkpatch_on_patches_missing_script()
{
  run_checkpatch_on_patches "$FAKE_KERNEL" 'TEST_MODE' &> /dev/null
  assert_equals_helper 'Missing checkpatch.pl should return 0' "$LINENO" 0 "$?"
}

function test_run_checkpatch_on_patches_empty_cache()
{
  install_fake_checkpatch 'checkpatch_pass.pl'

  run_checkpatch_on_patches "$FAKE_KERNEL" 'TEST_MODE' &> /dev/null
  assert_equals_helper 'No patches should return 0' "$LINENO" 0 "$?"
}

function test_run_checkpatch_on_patches_passing()
{
  local output
  local fake_patch="${_checkpatch_test_cache}/patches/0001-fake.patch"
  local expected_checkpatch
  expected_checkpatch="$(join_path "$FAKE_KERNEL" 'scripts/checkpatch.pl')"

  install_fake_checkpatch 'checkpatch_pass.pl'

  printf 'Subject: [PATCH] fake patch\n---\ndiff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1 +1 @@\n' > "$fake_patch"
  output=$(run_checkpatch_on_patches "$FAKE_KERNEL" 'TEST_MODE')
  assert_equals_helper 'Should call checkpatch on patch' "$LINENO" \
    "Running checkpatch on: 0001-fake.patch"$'\n'"perl $expected_checkpatch $fake_patch" "$output"
}

function test_run_checkpatch_on_patches_with_opts()
{
  local output
  local fake_patch="${_checkpatch_test_cache}/patches/0001-fake.patch"
  local expected_checkpatch
  expected_checkpatch="$(join_path "$FAKE_KERNEL" 'scripts/checkpatch.pl')"

  configurations['checkpatch_opts']='--no-tree'
  install_fake_checkpatch 'checkpatch_pass.pl'

  printf 'Subject: [PATCH] fake patch\n---\ndiff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1 +1 @@\n' > "$fake_patch"
  output=$(run_checkpatch_on_patches "$FAKE_KERNEL" 'TEST_MODE')
  assert_equals_helper 'Should pass checkpatch_opts to checkpatch' "$LINENO" \
    "Running checkpatch on: 0001-fake.patch"$'\n'"perl $expected_checkpatch --no-tree $fake_patch" "$output"
}

function test_run_checkpatch_on_patches_with_multiple_opts()
{
  local output
  local fake_patch="${_checkpatch_test_cache}/patches/0001-fake.patch"
  local expected_checkpatch
  expected_checkpatch="$(join_path "$FAKE_KERNEL" 'scripts/checkpatch.pl')"

  # shellcheck disable=SC2034 # read by run_checkpatch_on_patches
  configurations['checkpatch_opts']='--no-tree --quiet'
  install_fake_checkpatch 'checkpatch_pass.pl'

  printf 'Subject: [PATCH] fake patch\n---\ndiff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1 +1 @@\n' > "$fake_patch"
  output=$(run_checkpatch_on_patches "$FAKE_KERNEL" 'TEST_MODE')
  assert_equals_helper 'Should pass multiple checkpatch_opts to checkpatch' "$LINENO" \
    "Running checkpatch on: 0001-fake.patch"$'\n'"perl $expected_checkpatch --no-tree --quiet $fake_patch" "$output"
}

function test_run_checkpatch_on_patches_failing()
{
  local fake_patch="${_checkpatch_test_cache}/patches/0001-fake.patch"

  install_fake_checkpatch 'checkpatch_fail.pl'

  printf 'Subject: [PATCH] fake patch\n---\ndiff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1 +1 @@\n' > "$fake_patch"
  run_checkpatch_on_patches "$FAKE_KERNEL" 'SILENT' &> /dev/null
  assert_equals_helper 'Failing checkpatch should return 1' "$LINENO" 1 "$?"
}

function test_run_checkpatch_on_patches_multiple_failing()
{
  local output
  local fake_patch="${_checkpatch_test_cache}/patches/0001-fake.patch"
  local fake_patch2="${_checkpatch_test_cache}/patches/0002-fake.patch"

  install_fake_checkpatch 'checkpatch_fail.pl'

  printf 'Subject: [PATCH] fake patch\n---\ndiff --git a/f b/f\n--- a/f\n+++ b/f\n@@ -1 +1 @@\n' > "$fake_patch"
  printf 'Subject: [PATCH 2/2] second fake patch\n---\ndiff --git a/g b/g\n--- a/g\n+++ b/g\n@@ -1 +1 @@\n' > "$fake_patch2"

  output=$(run_checkpatch_on_patches "$FAKE_KERNEL" 'SILENT')
  assert_equals_helper 'Multiple failing patches should return 1' "$LINENO" 1 "$?"
  assertTrue "(${LINENO}) First patch should be checked" '[[ "${output}" =~ "0001-fake.patch" ]]'
  assertTrue "(${LINENO}) Second patch should be checked" '[[ "${output}" =~ "0002-fake.patch" ]]'
}

function test_mail_send_checkpatch()
{
  local output
  local ret

  cd "$FAKE_KERNEL" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake kernel"
    exit "$ret"
  }

  install_fake_checkpatch 'checkpatch_fail.pl'

  # Failing checkpatch: user declines to proceed, should abort
  parse_mail_options '--private' '@^'
  send_patch_config['checkpatch_before_send']='yes'
  printf 'n\n' | mail_send 'SILENT' &> /dev/null
  assert_equals_helper 'Should abort when checkpatch fails and user says no' "$LINENO" 1 "$?"

  # Failing checkpatch: user chooses to proceed anyway, send should go through
  parse_mail_options '--private' '@^'
  send_patch_config['checkpatch_before_send']='yes'
  output=$(printf 'y\n' | mail_send 'TEST_MODE' 2> /dev/null)
  assertTrue "(${LINENO}) Should proceed when checkpatch fails and user says yes" \
    '[[ "${output}" =~ "git send-email" ]]'

  # --no-checkpatch should bypass checkpatch and proceed to send
  parse_mail_options '--private' '--no-checkpatch' '@^'
  send_patch_config['checkpatch_before_send']='yes'
  output=$(mail_send 'TEST_MODE')
  assertTrue "(${LINENO}) --no-checkpatch should bypass checkpatch and proceed" \
    '[[ "${output}" =~ "git send-email" ]]'

  # checkpatch_before_send=no should bypass checkpatch and proceed to send
  parse_mail_options '--private' '@^'
  send_patch_config['checkpatch_before_send']='no'
  output=$(mail_send 'TEST_MODE')
  assertTrue "(${LINENO}) checkpatch_before_send=no should bypass checkpatch and proceed" \
    '[[ "${output}" =~ "git send-email" ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_get_configs()
{
  local output
  local expected
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  options_values['CMD_SCOPE']=''

  git config --local sendemail.smtpuser ''
  git config --local sendemail.smtppass safePass

  get_configs

  output=${set_confs['local_user.name']}
  expected='Xpto Lala'
  assert_equals_helper 'Checking local name' "$LINENO" "$expected" "$output"

  output=${set_confs['local_user.email']}
  expected='test@email.com'
  assert_equals_helper 'Checking local email' "$LINENO" "$expected" "$output"

  output=${set_confs['local_sendemail.smtppass']}
  expected='********'
  assert_equals_helper 'Checking local smtppass' "$LINENO" "$expected" "$output"

  output=${set_confs['local_sendemail.smtpuser']}
  expected='<empty>'
  assert_equals_helper 'Checking local smtpuser' "$LINENO" "$expected" "$output"

  git config --local --unset sendemail.smtpuser

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_missing_options()
{
  local -a output
  local -a expected_arr

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  parse_mail_options --local
  get_configs

  mapfile -t output < <(missing_options 'essential_config_options')
  expected_arr=('sendemail.smtpuser' 'sendemail.smtpserver' 'sendemail.smtpserverport')
  compare_array_values 'expected_arr' 'output' "$LINENO"

  mapfile -t output < <(missing_options 'optional_config_options')
  # shellcheck disable=SC2034 # used via string reference in compare_array_values
  expected_arr=('sendemail.smtpencryption')
  compare_array_values 'expected_arr' 'output' "$LINENO"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_config_values()
{
  local -A output
  local -A expected

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  get_configs

  options_values['user.name']='Loaded Name'

  config_values 'output' 'user.name'

  expected['local']='Xpto Lala'
  expected['loaded']='Loaded Name'

  assert_equals_helper 'Checking local name' "$LINENO" "${expected['local']}" "${output['local']}"
  assert_equals_helper 'Checking loaded name' "$LINENO" "${expected['loaded']}" "${output['loaded']}"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_add_config()
{
  local output
  local expected
  local ret

  options_values['test.opt']='value'
  options_values['CMD_SCOPE']='global'

  # test default values
  output=$(add_config 'test.opt' '' '' 'TEST_MODE')
  expected="git config --global test.opt 'value'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$expected" "$output"

  output=$(add_config 'test.option' 'test_value' 'local' 'TEST_MODE')
  expected="git config --local test.option 'test_value'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$expected" "$output"
}

function test_mail_setup()
{
  local expected
  local output
  local ret

  local -a expected_results=(
    "git config -- sendemail.smtpencryption 'ssl'"
    "git config -- sendemail.smtppass 'verySafePass'"
    "git config -- sendemail.smtpserver 'test.email.com'"
    "git config -- sendemail.smtpuser 'test@email.com'"
    "git config -- user.email 'test@email.com'"
    "git config -- user.name 'Xpto Lala'"
  )

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  # prepare options for testing
  parse_mail_options '-t' '--force' '--smtpencryption' 'ssl' '--smtppass' 'verySafePass' \
    '--email' 'test@email.com' '--name' 'Xpto Lala' \
    '--smtpuser' 'test@email.com' '--smtpserver' 'test.email.com'

  output=$(mail_setup 'TEST_MODE' | sort -d)
  compare_command_sequence '' "$LINENO" 'expected_results' "$output"

  unset options_values
  declare -gA options_values

  get_configs

  parse_mail_options '-t' '--name' 'Xpto Lala'

  output=$(mail_setup 'TEST_MODE')
  expected="git config -- user.name 'Xpto Lala'"
  assert_equals_helper 'Testing config with same value' "$LINENO" "$expected" "$output"

  parse_mail_options '-t' '--name' 'Lala Xpto'

  output=$(printf 'n\n' | mail_setup 'TEST_MODE' | tail -n 1)
  expected='No configuration options were set.'
  assert_equals_helper 'Operation should be skipped' "$LINENO" "$expected" "$output"

  output=$(printf 'y\n' | mail_setup 'TEST_MODE' | tail -n 1)
  expected="git config -- user.name 'Lala Xpto'"
  assert_equals_helper 'Testing confirmation' "$LINENO" "$expected" "$output"

  unset options_values
  declare -gA options_values

  parse_mail_options '-t' '--local' '--smtpserverport' '123'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --local sendemail.smtpserverport '123'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$expected" "$output"

  options_values['sendemail.smtpserverport']=''
  options_values['user.name']='Xpto Lala'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --local user.name 'Xpto Lala'"
  assert_equals_helper 'Testing config with same value' "$LINENO" "$expected" "$output"

  unset options_values
  declare -gA options_values

  parse_mail_options '-t' '--local' '--smtpuser' 'username'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --local sendemail.smtpuser 'username'"
  assert_equals_helper 'Testing smtpuser option' "$LINENO" "$expected" "$output"

  unset options_values
  declare -gA options_values

  # we need to force in case the user has set config at a global scope
  parse_mail_options '-t' '--force' '--global' '--smtppass' 'verySafePass'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --global sendemail.smtppass 'verySafePass'"
  assert_equals_helper 'Testing global option' "$LINENO" "$expected" "$output"

  cd "$SHUNIT_TMPDIR" || {
    ret="$?"
    fail "($LINENO): Failed to move to shunit temp dir"
    exit "$ret"
  }

  unset options_values
  declare -gA options_values

  # we need to force in case the user has set config at a global scope
  parse_mail_options '-t' '--force' '--global' '--smtppass' 'verySafePass'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --global sendemail.smtppass 'verySafePass'"
  assert_equals_helper 'Testing global option outside git' "$LINENO" "$expected" "$output"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_interactive_prompt()
{
  local expected
  local output

  local -a inputs=(
    ''          # test essential check
    'y'         # skip test0
    'value1'    # input test1
    'Lala Xpto' # input name
    'n'         # don't accept change
    'Lala Xpto' # input name
    'y'         # accept change
    'n'         # don't change smtpuser
  )

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  parse_mail_options
  options_values['test2']='value2'
  options_values['sendemail.smtpuser']='test@email.com'
  smtpuser_autoset=1
  get_configs

  output="$(printf '%s\n' "${inputs[@]}" | interactive_prompt 'test_config_opts')"
  # shellcheck disable=SC2034 # used cross-file by get_configs (reset state)
  smtpuser_autoset=0

  expected='Skipping test0...'
  assertTrue "($LINENO) Testing test0 skipped" '[[ $output =~ "$expected" ]]'

  expected='[local] Setup your test1:'
  assertTrue "($LINENO) Testing test1" '[[ $output =~ "$expected" ]]'

  expected='[local] Setup your test2:'
  assertTrue "($LINENO) test2 shouldn't prompt" '[[ ! $output =~ "$expected" ]]'

  expected='[local] Setup your name:'
  assertTrue "($LINENO) Testing user.name" '[[ $output =~ "$expected" ]]'

  expected='Xpto Lala --> Lala Xpto'
  assertTrue "($LINENO) Testing user.name proposed" '[[ $output =~ "$expected" ]]'

  expected='kw will set this option to test@email.com'
  assertTrue "($LINENO) Testing smtpuser autoset" '[[ $output =~ "$expected" ]]'

  # Testing options_values is not working, I suspect it has something to do with
  # the way bash handles variables and subshells
  # TODO: fix these tests
  # expected='value1'
  # assert_equals_helper 'Testing test1 value' "$LINENO" "$expected" "${options_values['test1']}"

  # expected='value2'
  # assert_equals_helper 'Testing test2 value' "$LINENO" "$expected" "${options_values['test2']}"

  # expected='Lala Xpto'
  # assert_equals_helper 'Testing user.name value' "$LINENO" "$expected" "${options_values['user.name']}"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_interactive_setup()
{
  local expected
  local output
  local ret

  local -a inputs=(
    'y'             # list
    '1'             # pick first template; loads smtpserver
    'y'             # accept name change
    ''              # user.email
    'user@smtp.com' # smtpuser
    '123'           # smtpserverport
    'ssl'           # smtpencryption
    ''              # smtppass
  )

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  parse_mail_options '-i' '--name' 'Lala Xpto'
  get_configs

  output=$(printf '%s\n' "${inputs[@]}" | interactive_setup 'TEST_MODE' 2>&1)

  # printf '***\n%s\n***' "$output" 1>&2

  expected="[local: Xpto Lala]"
  assertTrue "($LINENO) Testing user.name on list" '[[ $output =~ "$expected" ]]'

  expected="[local] 'user.name' was set to: Lala Xpto"
  assertTrue "($LINENO) Testing user.name config" '[[ $output =~ "$expected" ]]'

  expected="[local] 'sendemail.smtpuser' was set to: user@smtp.com"
  assertTrue "($LINENO) Testing sendemail.smtpuser config" '[[ $output =~ "$expected" ]]'

  expected="[local] 'sendemail.smtpserver' was set to: smtp.test1.com"
  assertTrue "($LINENO) Testing sendemail.smtpserver config" '[[ $output =~ "$expected" ]]'

  expected="[local] 'sendemail.smtpserverport' was set to: 123"
  assertTrue "($LINENO) Testing sendemail.smtpserverport config" '[[ $output =~ "$expected" ]]'

  expected="[local] 'sendemail.smtpencryption' was set to: ssl"
  assertTrue "($LINENO) Testing smtpencryption config" '[[ $output =~ "$expected" ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_load_template()
{
  local output
  local expected
  local ret

  output=$(load_template 'invalid' &> /dev/null)
  ret="$?"
  expected=22
  assert_equals_helper 'Invalid template' "$LINENO" "$expected" "$ret"

  load_template 'test1'
  expected='smtp.test1.com'
  assert_equals_helper 'Load template 1' "$LINENO" "$expected" "${options_values['sendemail.smtpserver']}"

  tearDown
  setUp

  load_template 'test2'
  expected='smtp.test2.com'
  assert_equals_helper 'Load template 2' "$LINENO" "$expected" "${options_values['sendemail.smtpserver']}"

  parse_mail_options -t --smtpserver 'user.given.server'

  load_template 'test2'
  expected='user.given.server'
  assert_equals_helper 'Load template 2 should not overwrite user given values' "$LINENO" "$expected" "${options_values['sendemail.smtpserver']}"
}

function test_template_setup()
{
  local output
  local expected

  local -a expected_results=(
    'You may choose one of the following templates to start your configuration.'
    '(enter the corresponding number to choose)'
    '1) Test1'
    '2) Test2'
    '3) Exit kw send-patch'
    '#?'
  )

  # empty template flag should trigger menu
  output=$(printf '1\n' | template_setup 2>&1)
  # couldn't find a way to test the loaded values
  compare_command_sequence '' "$LINENO" 'expected_results' "$output"

  options_values['TEMPLATE']=':test1'

  template_setup
  expected='smtp.test1.com'
  assert_equals_helper 'Load template 1' "$LINENO" "$expected" "${options_values['sendemail.smtpserver']}"

  options_values['TEMPLATE']=':test2'
  options_values['sendemail.smtpserver']=''

  template_setup
  expected='smtp.test2.com'
  assert_equals_helper 'Load template 2' "$LINENO" "$expected" "${options_values['sendemail.smtpserver']}"

  parse_mail_options --smtpserver 'user.input' --template='test2'

  template_setup
  expected='user.input'
  assert_equals_helper 'Load template 2' "$LINENO" "$expected" "${options_values['sendemail.smtpserver']}"
}

# This test can only be done on a local scope, as we have no control over the
# user's system
function test_mail_verify()
{
  local expected
  local output
  local ret

  local -a expected_results=(
    'Missing configurations required for send-email:'
    'sendemail.smtpuser'
    'sendemail.smtpserver'
    'sendemail.smtpserverport'
  )

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  parse_mail_options '--local'

  get_configs

  output=$(mail_verify)
  ret="$?"
  assert_equals_helper 'Failed verify expected an error' "$LINENO" 22 "$ret"
  compare_command_sequence '' "$LINENO" 'expected_results' "$output"

  unset options_values
  unset set_confs
  declare -gA options_values
  declare -gA set_confs

  # fulfill required options
  parse_mail_options '-t' '--local' '--smtpuser' 'test@email.com' '--smtpserver' \
    'test.email.com' '--smtpserverport' '123'
  mail_setup &> /dev/null
  get_configs

  expected_results=(
    'It looks like you are ready to send patches as:'
    'Xpto Lala <test@email.com>'
    ''
    'If you encounter problems you might need to configure these options:'
    'sendemail.smtpencryption'
    'sendemail.smtppass'
  )

  output=$(mail_verify)
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" 0 "$ret"
  compare_command_sequence '' "$LINENO" 'expected_results' "$output"

  unset options_values
  unset set_confs
  declare -gA options_values
  declare -gA set_confs

  # complete all the settings
  parse_mail_options '-t' '--local' '--smtpuser' 'test@email.com' '--smtpserver' \
    'test.email.com' '--smtpserverport' '123' '--smtpencryption' 'ssl' \
    '--smtppass' 'verySafePass'
  mail_setup &> /dev/null
  get_configs

  output=$(mail_verify | head -1)
  expected='It looks like you are ready to send patches as:'
  assert_equals_helper 'Expected successful verification' "$LINENO" "$expected" "$output"

  unset options_values
  unset set_confs
  declare -gA options_values
  declare -gA set_confs

  # test custom local smtpserver
  mkdir --parents ./fake_server

  expected_results=(
    'It appears you are using a local smtpserver with custom configurations.'
    "Unfortunately we can't verify these configurations yet."
    'Current value is: ./fake_server/'
  )

  parse_mail_options '-t' '--local' '--smtpserver' './fake_server/'
  mail_setup &> /dev/null
  get_configs

  output=$(mail_verify)
  compare_command_sequence '' "$LINENO" 'expected_results' "$output"

  rm --recursive --force ./fake_server

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_mail_list()
{
  local expected
  local output
  local ret

  # shellcheck disable=SC2034 # used via string reference in compare_command_sequence
  local -a expected_results=(
    'These are the essential configurations for git send-email:'
    'NAME'
    '[local: Xpto Lala]'
    'EMAIL'
    '[local: test@email.com]'
    'SMTPUSER'
    '[local: test@email.com], [loaded: test@email.com]'
    'SMTPSERVER'
    '[local: test.email.com], [loaded: test.email.com]'
    'SMTPSERVERPORT'
    '[local: 123], [loaded: 123]'
    'These are the optional configurations for git send-email:'
    'SMTPENCRYPTION'
    '[loaded: ssl]'
    'SMTPPASS'
    '[local: ********], [loaded: verySafePass]'
  )

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  parse_mail_options '-t' '--force' '--local' '--smtpuser' 'test@email.com' '--smtpserver' \
    'test.email.com' '--smtpserverport' '123' '--smtppass' 'verySafePass'
  mail_setup &> /dev/null

  git config --local --unset sendemail.smtpencryption
  parse_mail_options '-t' '--local' '--smtpencryption' 'ssl'

  output=$(mail_list)
  compare_command_sequence '' "$LINENO" 'expected_results' "$output"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

function test_add_recipients()
{
  local initial_recipients
  local additional_recipients
  local output
  local expected

  initial_recipients=''
  additional_recipients=''
  output=$(add_recipients "$initial_recipients" "$additional_recipients")
  expected=''
  assert_equals_helper 'No recipients should output nothing' "$LINENO" "$expected" "$output"

  initial_recipients='recipient1@email.com'$'\n'
  initial_recipients+='recipient2@email.com'$'\n'
  initial_recipients+='recipient3@email.com'$'\n'
  initial_recipients+='recipient4@email.com'
  output=$(add_recipients "$initial_recipients" "$additional_recipients")
  expected="$initial_recipients"
  assert_equals_helper 'No additional recipients should output initial recipients' "$LINENO" "$expected" "$output"

  additional_recipients='additional1@email.com,additional2@email.com'
  output=$(add_recipients "$initial_recipients" "$additional_recipients")
  expected="$initial_recipients"$'\n'
  expected+='additional1@email.com'$'\n'
  expected+='additional2@email.com'
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
}

function test_prepare_existing_patches()
{
  local count
  local ret
  local test_dir="$SHUNIT_TMPDIR/test_patches/"

  mkdir -p "$test_dir"

  cat > "$test_dir/0001-real.patch" << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test User <test@example.com>
Subject: [PATCH] test patch

diff --git a/file.txt b/file.txt
index 0000000..1111111 100644
--- a/file.txt
+++ b/file.txt
@@ -1 +1 @@
-old
+new
EOF

  echo 'not a patch' > "$test_dir/not-a-patch.txt"

  count=$(prepare_existing_patches "$test_dir/0001-real.patch")
  assert_equals_helper 'Should copy valid patch and return count 1' "$LINENO" 1 "$count"
  assertTrue "($LINENO) Valid patch should exist in cache" \
    '[[ -f "${KW_CACHE_DIR}/patches/0001-real.patch" ]]'

  ret=0
  count=$(prepare_existing_patches "$test_dir/not-a-patch.txt") || ret="$?"
  assert_equals_helper 'Should abort on invalid file' "$LINENO" 22 "$ret"

  ret=0
  count=$(prepare_existing_patches "$test_dir/nonexistent.patch") || ret="$?"
  assert_equals_helper 'Should return 0 for nonexistent files' "$LINENO" 0 "$count"
}

function test_prepare_existing_patches_cover_letter()
{
  local count
  local test_dir="$SHUNIT_TMPDIR/test_patches/"

  mkdir -p "$test_dir"

  cat > "$test_dir/0000-cover-letter.patch" << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH 0/1] cover test

cover letter body
EOF

  count=$(prepare_existing_patches "$test_dir/0000-cover-letter.patch")
  assert_equals_helper 'Should accept cover-letter patch' "$LINENO" 1 "$count"
  assertTrue "($LINENO) Cover-letter should exist in cache" \
    '[[ -f "${KW_CACHE_DIR}/patches/0000-cover-letter.patch" ]]'
}

function test_mail_send_with_patch_files()
{
  local output
  local expected
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    return "$ret"
  }

  cat > '0001-fake.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH] test

diff --git a/file b/file
index 0000000..1111111 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-old
+new
EOF

  parse_mail_options -s -- 0001-fake.patch

  output=$(mail_send 'TEST_MODE')
  assertTrue "($LINENO) Should not include @^" '! grep -q "@^" <<< "$output"'
  assertTrue "($LINENO) Should include the .patch file" '[[ "$output" =~ 0001-fake\.patch ]]'

  assertTrue "($LINENO) Patch should be copied to cache" \
    '[[ -f "${KW_CACHE_DIR}/patches/0001-fake.patch" ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to return to original dir"
    return "$ret"
  }
}

function test_mail_send_with_invalid_patch_file()
{
  local output
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    return "$ret"
  }

  echo 'not a valid patch - no diff markers' > 'bogus.patch'

  parse_mail_options -s -- bogus.patch

  output=$(mail_send 'TEST_MODE' 2>&1)
  ret="$?"
  assert_equals_helper 'Should exit with EINVAL' "$LINENO" 22 "$ret"
  assertTrue "($LINENO) Should complain about invalid patch" \
    '[[ "$output" =~ bogus\.patch ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to return to original dir"
    return "$ret"
  }
}

function test_mail_send_with_mixed_passthrough_args()
{
  local output
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    return "$ret"
  }

  cat > '0001-fake.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH] test

diff --git a/file b/file
index 0000000..1111111 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-old
+new
EOF

  parse_mail_options -s -- --subject-prefix='PATCH v2' 0001-fake.patch -v3

  output=$(mail_send 'TEST_MODE')
  assertTrue "($LINENO) Should not include @^" '! grep -q "@^" <<< "$output"'
  assertTrue "($LINENO) Should include subject-prefix" '[[ "$output" =~ subject-prefix ]]'
  assertTrue "($LINENO) Should include the .patch file" '[[ "$output" =~ 0001-fake\.patch ]]'
  assertTrue "($LINENO) Should include version" '[[ "$output" =~ -v3 ]]'

  assertTrue "($LINENO) Patch should be copied to cache" \
    '[[ -f "${KW_CACHE_DIR}/patches/0001-fake.patch" ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to return to original dir"
    return "$ret"
  }
}

function test_mail_send_with_invalid_file_in_glob()
{
  local output
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    return "$ret"
  }

  cat > '0001-good.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH] test

diff --git a/file b/file
index 0000000..1111111 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-old
+new
EOF

  echo 'not a patch' > 'other.txt'

  parse_mail_options -s -- 0001-good.patch other.txt

  output=$(mail_send 'TEST_MODE' 2>&1)
  ret="$?"
  assert_equals_helper 'Should exit with EINVAL for invalid file' "$LINENO" 22 "$ret"
  assertTrue "($LINENO) Should reference invalid file in error" \
    '[[ "$output" =~ other\.txt ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to return to original dir"
    return "$ret"
  }
}

function test_mail_send_rejects_cover_letter_patch()
{
  local output
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    return "$ret"
  }

  cat > '0000-cover-letter.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH 0/1] cover test

cover letter body
EOF
  cat > '0001-real.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH] test

diff --git a/file b/file
index 0000000..1111111 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-old
+new
EOF

  parse_mail_options -s -- 0000-cover-letter.patch 0001-real.patch

  output=$(mail_send 'TEST_MODE' 2>&1)
  ret="$?"
  assert_equals_helper 'Should NOT reject cover letter patch' "$LINENO" 0 "$ret"
  assertTrue "($LINENO) Should include cover letter patch in command" \
    '[[ "$output" =~ 0000-cover-letter\.patch ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to return to original dir"
    return "$ret"
  }
}

function test_mail_send_cover_letter_among_existing_patches()
{
  local output
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    return "$ret"
  }

  cat > '0000-cover-letter.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH 0/1] cover test

cover letter body
EOF

  cat > '0001-real.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH] test

diff --git a/file b/file
index 0000000..1111111 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-old
+new
EOF

  parse_mail_options -s -- 0000-cover-letter.patch 0001-real.patch

  parse_configuration "$KW_MAIL_CONFIG_SAMPLE" send_patch_config
  output=$(mail_send 'TEST_MODE' 2>&1)
  ret="$?"

  assert_equals_helper 'Should succeed' "$LINENO" 0 "$ret"
  assertTrue "($LINENO) Should not generate a new cover-letter" \
    '! [[ "$output" =~ --cover-letter ]]'
  assertTrue "($LINENO) Should include cover-letter patch in command" \
    '[[ "$output" =~ 0000-cover-letter\.patch ]]'
  assertTrue "($LINENO) Should include real patch in command" \
    '[[ "$output" =~ 0001-real\.patch ]]'

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to return to original dir"
    return "$ret"
  }
}

function test_mail_send_auto_save_user_provided_cover_letter()
{
  local output ret saved_opts

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    return "$ret"
  }

  cat > '0000-cover-letter.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH 0/1] cover test

cover letter body
EOF

  saved_opts="${send_patch_config[send_opts]}"
  send_patch_config[send_opts]='--annotate --cover-letter --no-chain-reply-to --thread'

  parse_mail_options -s --simulate -3 -- 0000-cover-letter.patch

  # Simulate the GIT_EDITOR wrapper having captured an edit
  printf 'template\n' > "${KW_CACHE_DIR}/.cov_letter_template"
  printf 'user edited cover letter\n' > "${KW_CACHE_DIR}/.cov_letter_edited"

  output=$(mail_send 'TEST_MODE')
  ret="$?"
  assert_equals_helper 'Should succeed' "$LINENO" 0 "$ret"
  assertTrue "($LINENO) Should not have --cover-letter in opts" \
    '! [[ "$output" =~ --cover-letter ]]'
  assertTrue "($LINENO) Should save back to user-provided file" \
    '[[ -f "$PWD/0000-cover-letter.patch" ]]'

  local file_content
  file_content=$(< "$PWD/0000-cover-letter.patch")
  assert_equals_helper "($LINENO) Saved content should match edited" "$LINENO" \
    'user edited cover letter' "$file_content"

  send_patch_config[send_opts]="$saved_opts"
  rm -f "$PWD/0000-cover-letter.patch" \
    "${KW_CACHE_DIR}/.cov_letter_template" \
    "${KW_CACHE_DIR}/.cov_letter_edited"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to return to original dir"
    return "$ret"
  }
}

function test_mail_send_auto_save_prefixed_cover_letter()
{
  local output ret saved_opts

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    return "$ret"
  }

  cat > '0000-cover-letter.kw-26-07-29_122608.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH 0/1] cover test

cover letter body
EOF

  saved_opts="${send_patch_config[send_opts]}"
  send_patch_config[send_opts]='--annotate --cover-letter --no-chain-reply-to --thread'

  parse_mail_options -s --simulate -3 -- 0000-cover-letter.kw-26-07-29_122608.patch

  printf 'template\n' > "${KW_CACHE_DIR}/.cov_letter_template"
  printf 'user edited cover letter\n' > "${KW_CACHE_DIR}/.cov_letter_edited"

  output=$(mail_send 'TEST_MODE')
  ret="$?"
  assert_equals_helper 'Should succeed' "$LINENO" 0 "$ret"
  assertTrue "($LINENO) Should save back to prefixed file" \
    '[[ -f "$PWD/0000-cover-letter.kw-26-07-29_122608.patch" ]]'

  local file_content
  file_content=$(< "$PWD/0000-cover-letter.kw-26-07-29_122608.patch")
  assert_equals_helper "($LINENO) Saved content should match edited" "$LINENO" \
    'user edited cover letter' "$file_content"

  send_patch_config[send_opts]="$saved_opts"
  rm -f "$PWD/0000-cover-letter.kw-26-07-29_122608.patch" \
    "${KW_CACHE_DIR}/.cov_letter_template" \
    "${KW_CACHE_DIR}/.cov_letter_edited"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to return to original dir"
    return "$ret"
  }
}

function test_mail_send_rejects_range_with_patch_files()
{
  local output
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    return "$ret"
  }

  cat > '0000-cover-letter.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH 0/1] cover test

cover letter body
EOF

  cat > '0001-real.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH] test

diff --git a/file b/file
index 0000000..1111111 100644
--- a/file
+++ b/file
@@ -1 +1 @@
-old
+new
EOF

  # Reject range + non-cover-letter patch files
  parse_mail_options -s --simulate -3 -- 0001-real.patch

  output=$(mail_send 'TEST_MODE' 2>&1)
  ret="$?"
  assert_equals_helper 'Should reject range + non-cover-letter patches' "$LINENO" 22 "$ret"
  assertTrue "($LINENO) Should mention commit range" \
    '[[ "$output" =~ commit\ range ]]'

  # Allow range + cover-letter-only files
  parse_mail_options -s --simulate -3 -- 0000-cover-letter.patch

  output=$(mail_send 'TEST_MODE' 2>&1)
  ret="$?"
  assert_equals_helper 'Should allow range + cover-letter' "$LINENO" 0 "$ret"

  # Allow range + prefixed cover-letter files
  cat > '0000-cover-letter.kw-26-07-29_122608.patch' << 'EOF'
From abc123 Mon Sep 17 00:00:00 2001
From: Test <test@test.com>
Subject: [PATCH 0/1] cover test

cover letter body
EOF
  parse_mail_options -s --simulate -3 -- 0000-cover-letter.kw-26-07-29_122608.patch

  output=$(mail_send 'TEST_MODE' 2>&1)
  ret="$?"
  assert_equals_helper 'Should allow range + prefixed cover-letter' "$LINENO" 0 "$ret"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to return to original dir"
    return "$ret"
  }
}

invoke_shunit
