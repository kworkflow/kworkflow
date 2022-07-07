#!/bin/bash

include './src/mail.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  declare -gr ORIGINAL_DIR="$PWD"
  declare -gr FAKE_GIT="$SHUNIT_TMPDIR/fake_git/"
  declare -gr FAKE_KERNEL="$FAKE_GIT/fake_kernel/"
  declare -ga test_config_opts=('test0' 'test1' 'test2' 'user.name' 'sendemail.smtpuser')

  export KW_ETC_DIR="$SHUNIT_TMPDIR/etc/"
  export KW_CACHE_DIR="$SHUNIT_TMPDIR/cache/"

  mk_fake_kernel_root "$FAKE_KERNEL"
  mkdir -p "$KW_ETC_DIR/mail_templates/"

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
  rm -rf "$FAKE_GIT"
}

function setUp()
{
  declare -gA options_values
  declare -gA set_confs
}

function tearDown()
{
  unset options_values
  unset set_confs
}

function test_validate_encryption()
{
  local ret

  # invalid values
  validate_encryption 'xpto' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption 'rsa' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption 'tlss' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption 'ssll' &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption &> /dev/null
  ret="$?"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  # valid values
  validate_encryption 'ssl'
  ret="$?"
  assert_equals_helper 'Expected no error for ssl' "$LINENO" "$ret" 0

  validate_encryption 'tls'
  ret="$?"
  assert_equals_helper 'Expected no error for tls' "$LINENO" "$ret" 0
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
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$output" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  output="$(validate_email 'lalala')"
  ret="$?"
  expected='Invalid email: lalala'
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$output" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  # valid values
  validate_email 'test@email.com'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0

  validate_email 'test123@serious.gov'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0
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
  assert_equals_helper 'No arguments given' "$LINENO" "$ret" 22

  find_commit_references @^
  ret="$?"
  assert_equals_helper 'Outside git repo should return 125' "$LINENO" "$ret" 125

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  output="$(find_commit_references invalid_ref)"
  ret="$?"
  assert_equals_helper 'Invalid ref should not work' "$LINENO" "$ret" 22
  assertTrue "($LINENO) Invalid ref should be empty" '[[ -z "$output" ]]'

  output="$(find_commit_references '@^..@')"
  ret="$?"
  assert_equals_helper '@^..@ should be a valid reference' "$LINENO" "$ret" 0
  assertTrue "($LINENO) @^..@ should generate a reference" '[[ -n "$output" ]]'

  output="$(find_commit_references @)"
  ret="$?"
  assert_equals_helper '@ should be a valid reference' "$LINENO" "$ret" 0
  assertTrue "($LINENO) @ should generate a reference" '[[ -n "$output" ]]'

  output="$(find_commit_references some args @ around)"
  ret="$?"
  assert_equals_helper '@ should be a valid reference' "$LINENO" "$ret" 0
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
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$output" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  output="$(validate_email_list 'lalala')"
  ret="$?"
  expected='The given recipient: lalala does not contain a valid e-mail.'
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$output" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  output="$(validate_email_list 'name1@lala.com,name2@lala.xpto,LastName, FirstName <last.first@lala.com>,test123@serious.gov')"
  ret="$?"
  expected='The given recipient: LastName does not contain a valid e-mail.'
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  # valid values
  validate_email_list 'test@email.com'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0

  validate_email_list 'name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>,test123@serious.gov'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0
}

function test_reposition_commit_count_arg()
{
  local output
  local expected

  output="$(reposition_commit_count_arg --any --amount --of --args)"
  expected=' "--any" "--amount" "--of" "--args"'
  assert_equals_helper 'Should not change arguments' "$LINENO" "$output" "$expected"

  output="$(reposition_commit_count_arg --arg='some options, lala')"
  expected=' "--arg=some options, lala"'
  assert_equals_helper 'Should correctly quote arguments' "$LINENO" "$output" "$expected"

  output="$(reposition_commit_count_arg -375)"
  expected=' -- -375'
  assert_equals_helper 'Should place count argument at the end' "$LINENO" "$output" "$expected"

  output="$(reposition_commit_count_arg --arg='some options, lala' -375)"
  expected=' "--arg=some options, lala" -- -375'
  assert_equals_helper 'Should handle multiple arguments' "$LINENO" "$output" "$expected"
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

function test_mail_parser()
{
  local output
  local expected
  local ret

  # Invalid options
  parse_mail_options '-t' '--smtpuser'
  ret="$?"
  assert_equals_helper 'Option without argument' "$LINENO" "$ret" 22

  output=$(parse_mail_options '--name' 'Xpto')
  ret="$?"
  assert_equals_helper 'Option without --setup' "$LINENO" "$ret" 95

  parse_mail_options '--smtpLalaXpto' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option passed' "$LINENO" "$ret" 22

  parse_mail_options '--wrongOption' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option passed' "$LINENO" "$ret" 22

  # valid options
  parse_mail_options some -- extra -1 args HEAD^
  expected='some extra args HEAD^ -1'
  assert_equals_helper 'Set passthrough options' "$LINENO" "${options_values['PASS_OPTION_TO_SEND_EMAIL']}" "$expected"
  assert_equals_helper 'Set passthrough options' "$LINENO" "${options_values['COMMIT_RANGE']}" '-1 HEAD^'

  parse_mail_options -375
  expected='-375'
  assert_equals_helper 'Set commit count option' "$LINENO" "${options_values['PASS_OPTION_TO_SEND_EMAIL']}" "$expected"
  assert_equals_helper 'Set commit count option' "$LINENO" "${options_values['COMMIT_RANGE']}" "$expected "

  parse_mail_options -v3
  expected='-v3'
  assert_equals_helper 'Set version option' "$LINENO" "${options_values['PATCH_VERSION']}" "$expected"

  expected='-v3 @^'
  assert_equals_helper 'Set version option' "$LINENO" "${options_values['PASS_OPTION_TO_SEND_EMAIL']}" "$expected"
  assert_equals_helper 'Set version option' "$LINENO" "${options_values['COMMIT_RANGE']}" '@^'

  parse_mail_options '--send'
  assert_equals_helper 'Set send flag' "$LINENO" "${options_values['SEND']}" 1

  parse_mail_options '--private'
  expected='--suppress-cc=all'
  assert_equals_helper 'Set private flag' "$LINENO" "${options_values['PRIVATE']}" "$expected"

  parse_mail_options '--rfc'
  expected='--rfc'
  assert_equals_helper 'Set rfc flag' "$LINENO" "${options_values['RFC']}" "$expected"

  parse_mail_options '--to=some@mail.com'
  expected='some@mail.com'
  assert_equals_helper 'Set to flag' "$LINENO" "${options_values['TO']}" "$expected"

  parse_mail_options '--cc=some@mail.com'
  expected='some@mail.com'
  assert_equals_helper 'Set cc flag' "$LINENO" "${options_values['CC']}" "$expected"

  parse_mail_options '--simulate'
  expected='--dry-run'
  assert_equals_helper 'Set simulate flag' "$LINENO" "${options_values['SIMULATE']}" "$expected"

  parse_mail_options '--to=name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>'
  expected='name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>'
  assert_equals_helper 'Set to flag' "$LINENO" "${options_values['TO']}" "$expected"

  parse_mail_options '--setup'
  expected=1
  assert_equals_helper 'Set setup flag' "$LINENO" "${options_values['SETUP']}" "$expected"

  parse_mail_options '--force'
  expected=1
  assert_equals_helper 'Set force flag' "$LINENO" "${options_values['FORCE']}" "$expected"

  parse_mail_options '--verify'
  expected_result=1
  assert_equals_helper 'Set verify flag' "$LINENO" "${options_values['VERIFY']}" "$expected_result"

  parse_mail_options '--template'
  expected_result=':'
  assert_equals_helper 'Template without options' "$LINENO" "${options_values['TEMPLATE']}" "$expected_result"

  parse_mail_options '--template=test'
  expected_result=':test'
  assert_equals_helper 'Set template flag' "$LINENO" "${options_values['TEMPLATE']}" "$expected_result"

  parse_mail_options '--template=  Test '
  expected_result=':test'
  assert_equals_helper 'Set template flag, case and spaces' "$LINENO" "${options_values['TEMPLATE']}" "$expected_result"

  parse_mail_options '--interactive'
  expected_result='parser'
  assert_equals_helper 'Set interactive flag' "$LINENO" "${options_values['INTERACTIVE']}" "$expected_result"

  parse_mail_options '--no-interactive'
  expected_result=1
  assert_equals_helper 'Set no-interactive flag' "$LINENO" "${options_values['NO_INTERACTIVE']}" "$expected_result"

  expected=''
  assert_equals_helper 'Unset local or global flag' "$LINENO" "${options_values['CMD_SCOPE']}" "$expected"

  expected='local'
  assert_equals_helper 'Unset local or global flag' "$LINENO" "${options_values['SCOPE']}" "$expected"

  parse_mail_options '--local'
  assert_equals_helper 'Set local flag' "$LINENO" "${options_values['SCOPE']}" "$expected"
  assert_equals_helper 'Set local flag' "$LINENO" "${options_values['CMD_SCOPE']}" "$expected"

  parse_mail_options '--global'
  expected='global'
  assert_equals_helper 'Set global flag' "$LINENO" "${options_values['SCOPE']}" "$expected"
  assert_equals_helper 'Set global flag' "$LINENO" "${options_values['CMD_SCOPE']}" "$expected"

  parse_mail_options '-t' '--name' 'Xpto Lala'
  expected='Xpto Lala'
  assert_equals_helper 'Set name' "$LINENO" "${options_values['user.name']}" "$expected"

  parse_mail_options '-t' '--email' 'test@email.com'
  expected='test@email.com'
  assert_equals_helper 'Set email' "$LINENO" "${options_values['user.email']}" "$expected"

  parse_mail_options '-t' '--smtpuser' 'test@email.com'
  expected='test@email.com'
  assert_equals_helper 'Set smtp user' "$LINENO" "${options_values['sendemail.smtpuser']}" "$expected"

  parse_mail_options '-t' '--smtpencryption' 'tls'
  expected='tls'
  assert_equals_helper 'Set smtp encryption to tls' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"

  parse_mail_options '-t' '--smtpencryption' 'ssl'
  expected='ssl'
  assert_equals_helper 'Set smtp encryption to ssl' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"

  parse_mail_options '-t' '--smtpserver' 'test.email.com'
  expected='test.email.com'
  assert_equals_helper 'Set smtp server' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"

  parse_mail_options '-t' '--smtpserverport' '123'
  expected='123'
  assert_equals_helper 'Set smtp serverport' "$LINENO" "${options_values['sendemail.smtpserverport']}" "$expected"

  parse_mail_options '-t' '--smtppass' 'verySafePass'
  expected='verySafePass'
  assert_equals_helper 'Set smtp pass' "$LINENO" "${options_values['sendemail.smtppass']}" "$expected"
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
  assert_equals_helper 'Testing send without options' "$LINENO" "$output" "$expected"

  parse_mail_options '--to=mail@test.com'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" @^'
  assert_equals_helper 'Testing send with to option' "$LINENO" "$output" "$expected"

  parse_mail_options '--to=name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>,test123@serious.gov'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>,test123@serious.gov" @^'
  assert_equals_helper 'Testing send with to option' "$LINENO" "$output" "$expected"

  parse_mail_options '--cc=mail@test.com'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --cc="mail@test.com" @^'
  assert_equals_helper 'Testing send with c option' "$LINENO" "$output" "$expected"

  parse_mail_options '--cc=name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>,test123@serious.gov'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --cc="name1@lala.com,name2@lala.xpto,name3 second <name3second@lala.com>,test123@serious.gov" @^'
  assert_equals_helper 'Testing send with cc option' "$LINENO" "$output" "$expected"

  parse_mail_options '--simulate'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --dry-run @^'
  assert_equals_helper 'Testing send with simulate option' "$LINENO" "$output" "$expected"

  parse_mail_options '--private'

  output=$(mail_send 'TEST_MODE')
  expected="git send-email --suppress-cc=all @^"
  assert_equals_helper 'Testing send with to option' "$LINENO" "$output" "$expected"

  parse_mail_options '--rfc'

  output=$(mail_send 'TEST_MODE')
  expected="git send-email --rfc @^"
  assert_equals_helper 'Testing send with rfc option' "$LINENO" "$output" "$expected"

  parse_mail_options '--to=mail@test.com' 'HEAD~'

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" HEAD~'
  assert_equals_helper 'Testing send with patch option' "$LINENO" "$output" "$expected"

  parse_mail_options '--to=mail@test.com' -13 -v2 extra_args -- --other_arg

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" extra_args --other_arg -13 -v2'
  assert_equals_helper 'Testing no options option' "$LINENO" "$output" "$expected"

  parse_mail_options '--to=mail@test.com'

  parse_configuration "$KW_MAIL_CONFIG_SAMPLE" mail_config
  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" --annotate  --no-chain-reply-to --thread @^'
  assert_equals_helper 'Testing default option' "$LINENO" "$output" "$expected"

  parse_mail_options '--to=mail@test.com' '@^^'
  parse_configuration "$KW_CONFIG_SAMPLE"

  output=$(mail_send 'TEST_MODE')
  expected='git send-email --to="mail@test.com" --annotate --cover-letter --no-chain-reply-to --thread @^^'
  assert_equals_helper 'Testing default option' "$LINENO" "$output" "$expected"

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
  assert_equals_helper 'Checking local name' "$LINENO" "$output" "$expected"

  output=${set_confs['local_user.email']}
  expected='test@email.com'
  assert_equals_helper 'Checking local email' "$LINENO" "$output" "$expected"

  output=${set_confs['local_sendemail.smtppass']}
  expected='********'
  assert_equals_helper 'Checking local smtppass' "$LINENO" "$output" "$expected"

  output=${set_confs['local_sendemail.smtpuser']}
  expected='<empty>'
  assert_equals_helper 'Checking local smtpuser' "$LINENO" "$output" "$expected"

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

  assert_equals_helper 'Checking local name' "$LINENO" "${output['local']}" "${expected['local']}"
  assert_equals_helper 'Checking loaded name' "$LINENO" "${output['loaded']}" "${expected['loaded']}"

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
  assert_equals_helper 'Testing serverport option' "$LINENO" "$output" "$expected"

  output=$(add_config 'test.option' 'test_value' 'local' 'TEST_MODE')
  expected="git config --local test.option 'test_value'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$output" "$expected"
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
  assert_equals_helper 'Testing config with same value' "$LINENO" "$output" "$expected"

  parse_mail_options '-t' '--name' 'Lala Xpto'

  output=$(printf 'n\n' | mail_setup 'TEST_MODE' | tail -n 1)
  expected='No configuration options were set.'
  assert_equals_helper 'Operation should be skipped' "$LINENO" "$output" "$expected"

  output=$(printf 'y\n' | mail_setup 'TEST_MODE' | tail -n 1)
  expected="git config -- user.name 'Lala Xpto'"
  assert_equals_helper 'Testing confirmation' "$LINENO" "$output" "$expected"

  unset options_values
  declare -gA options_values

  parse_mail_options '-t' '--local' '--smtpserverport' '123'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --local sendemail.smtpserverport '123'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$output" "$expected"

  options_values['sendemail.smtpserverport']=''
  options_values['user.name']='Xpto Lala'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --local user.name 'Xpto Lala'"
  assert_equals_helper 'Testing config with same value' "$LINENO" "$output" "$expected"

  unset options_values
  declare -gA options_values

  parse_mail_options '-t' '--local' '--smtpuser' 'username'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --local sendemail.smtpuser 'username'"
  assert_equals_helper 'Testing smtpuser option' "$LINENO" "$output" "$expected"

  unset options_values
  declare -gA options_values

  # we need to force in case the user has set config at a global scope
  parse_mail_options '-t' '--force' '--global' '--smtppass' 'verySafePass'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --global sendemail.smtppass 'verySafePass'"
  assert_equals_helper 'Testing global option' "$LINENO" "$output" "$expected"

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
  assert_equals_helper 'Testing global option outside git' "$LINENO" "$output" "$expected"

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
  # assert_equals_helper 'Testing test1 value' "$LINENO" "${options_values['test1']}" "$expected"

  # expected='value2'
  # assert_equals_helper 'Testing test2 value' "$LINENO" "${options_values['test2']}" "$expected"

  # expected='Lala Xpto'
  # assert_equals_helper 'Testing user.name value' "$LINENO" "${options_values['user.name']}" "$expected"

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
  assert_equals_helper 'Invalid template' "$LINENO" "$ret" "$expected"

  load_template 'test1'
  expected='smtp.test1.com'
  assert_equals_helper 'Load template 1' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"

  tearDown
  setUp

  load_template 'test2'
  expected='smtp.test2.com'
  assert_equals_helper 'Load template 2' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"

  parse_mail_options -t --smtpserver 'user.given.server'

  load_template 'test2'
  expected='user.given.server'
  assert_equals_helper 'Load template 2 should not overwrite user given values' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"
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
    '3) Exit kw mail'
    '#?'
  )

  # empty template flag should trigger menu
  output=$(printf '1\n' | template_setup 2>&1)
  # couldn't find a way to test the loaded values
  compare_command_sequence '' "$LINENO" 'expected_results' "$output"

  options_values['TEMPLATE']=':test1'

  template_setup
  expected='smtp.test1.com'
  assert_equals_helper 'Load template 1' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"

  options_values['TEMPLATE']=':test2'
  options_values['sendemail.smtpserver']=''

  template_setup
  expected='smtp.test2.com'
  assert_equals_helper 'Load template 2' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"

  parse_mail_options --smtpserver 'user.input' --template='test2'

  template_setup
  expected='user.input'
  assert_equals_helper 'Load template 2' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"
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
  assert_equals_helper 'Failed verify expected an error' "$LINENO" "$ret" 22
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
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0
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
  assert_equals_helper 'Expected successful verification' "$LINENO" "$output" "$expected"

  unset options_values
  unset set_confs
  declare -gA options_values
  declare -gA set_confs

  # test custom local smtpserver
  mkdir -p ./fake_server

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

  rm -rf ./fake_server

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

invoke_shunit
