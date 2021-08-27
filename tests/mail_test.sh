#!/bin/bash

include './src/mail.sh'
include './tests/utils.sh'

function oneTimeSetUp()
{
  declare -gr ORIGINAL_DIR="$PWD"
  declare -gr FAKE_GIT="$SHUNIT_TMPDIR/fake_git/"

  mkdir -p "$FAKE_GIT"

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
  local expected
  local output
  local ret

  # invalid values
  expected=''

  validate_encryption 'xpto' &> /dev/null
  ret="$?"
  assert_equals_helper 'Encryption should be blank' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption 'rsa' &> /dev/null
  ret="$?"
  assert_equals_helper 'Encryption should be blank' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption 'tlss' &> /dev/null
  ret="$?"
  assert_equals_helper 'Encryption should be blank' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption 'ssll' &> /dev/null
  ret="$?"
  assert_equals_helper 'Encryption should be blank' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  validate_encryption &> /dev/null
  ret="$?"
  assert_equals_helper 'Encryption should be blank' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  # valid values
  validate_encryption 'ssl'
  expected='ssl'
  assert_equals_helper 'Encryption should be ssl' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"

  validate_encryption 'tls'
  expected='tls'
  assert_equals_helper 'Encryption should be tls' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"
}

function test_validate_email()
{
  local expected
  local output
  local ret

  # invalid values
  output="$(validate_email 'email' 'invalid email')"
  ret="$?"
  expected='Invalid email: invalid email'
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$output" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  output="$(validate_email 'smtpuser' 'invalid email')"
  ret="$?"
  expected='Invalid smtpuser: invalid email'
  assert_equals_helper 'Invalid email was passed' "$LINENO" "$output" "$expected"
  assert_equals_helper 'Expected an error' "$LINENO" "$ret" 22

  # valid values
  validate_email 'email' 'test@email.com'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0

  validate_email 'smtpuser' 'test@email.com'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0

  # non-emails should be a success
  validate_email 'name' 'Xpto Lala'
  ret="$?"
  assert_equals_helper 'Expected a success' "$LINENO" "$ret" 0
}

function test_mail_parser()
{
  local output
  local expected
  local ret

  # Invalid options
  parse_mail_options '--smtpencryption' 'tlst' &> /dev/null
  expected=''
  assert_equals_helper 'Encryption should be blank' "$LINENO" "${options_values['SMTPENCRYPTION']}" "$expected"

  parse_mail_options '--email' 'not_an_email' &> /dev/null
  expected=''
  assert_equals_helper 'Invalid email, should be blank' "$LINENO" "${options_values['user.email']}" "$expected"

  parse_mail_options '--smtpuser'
  ret="$?"
  assert_equals_helper 'Option without argument' "$LINENO" "$ret" 22

  parse_mail_options '--smtpLalaXpto' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option passed' "$LINENO" "$ret" 22

  parse_mail_options '--wrongOption' 'lala xpto'
  ret="$?"
  assert_equals_helper 'Invalid option passed' "$LINENO" "$ret" 22

  # valid options
  parse_mail_options '--setup'
  expected=1
  assert_equals_helper 'Set setup flag' "$LINENO" "${options_values['SETUP']}" "$expected"

  parse_mail_options '--force'
  expected=1
  assert_equals_helper 'Set force flag' "$LINENO" "${options_values['FORCE']}" "$expected"

  parse_mail_options '--verify'
  expected_result=1
  assert_equals_helper 'Set verify flag' "$LINENO" "${options_values['VERIFY']}" "$expected_result"

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

  parse_mail_options '--name' 'Xpto Lala'
  expected='Xpto Lala'
  assert_equals_helper 'Set name' "$LINENO" "${options_values['user.name']}" "$expected"

  parse_mail_options '--email' 'test@email.com'
  expected='test@email.com'
  assert_equals_helper 'Set email' "$LINENO" "${options_values['user.email']}" "$expected"

  parse_mail_options '--smtpuser' 'test@email.com'
  expected='test@email.com'
  assert_equals_helper 'Set smtp user' "$LINENO" "${options_values['sendemail.smtpuser']}" "$expected"

  parse_mail_options '--smtpencryption' 'tls'
  expected='tls'
  assert_equals_helper 'Set smtp encryption to tls' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"

  parse_mail_options '--smtpencryption' 'ssl'
  expected='ssl'
  assert_equals_helper 'Set smtp encryption to ssl' "$LINENO" "${options_values['sendemail.smtpencryption']}" "$expected"

  parse_mail_options '--smtpserver' 'test.email.com'
  expected='test.email.com'
  assert_equals_helper 'Set smtp server' "$LINENO" "${options_values['sendemail.smtpserver']}" "$expected"

  parse_mail_options '--smtpserverport' '123'
  expected='123'
  assert_equals_helper 'Set smtp serverport' "$LINENO" "${options_values['sendemail.smtpserverport']}" "$expected"

  parse_mail_options '--smtppass' 'verySafePass'
  expected='verySafePass'
  assert_equals_helper 'Set smtp pass' "$LINENO" "${options_values['sendemail.smtppass']}" "$expected"
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

  git config --local sendemail.smtppass safePass

  get_configs

  output=${set_confs['local_user.name']}
  expected='Xpto Lala'
  assert_equals_helper 'Checking local name' "$LINENO" "$output" "$expected"

  output=${set_confs['local_user.email']}
  expected='test@email.com'
  assert_equals_helper 'Checking local email' "$LINENO" "$output" "$expected"

  output=${set_confs['local_sendemail.smtppass']}
  expected='safePass'
  assert_equals_helper 'Checking local smtppass' "$LINENO" "$output" "$expected"

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

function test_check_add_config()
{
  local output
  local expected
  local ret

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  get_configs

  options_values['FORCE']=0
  options_values['SCOPE']='local'
  options_values['CMD_SCOPE']='local'

  options_values['sendemail.smtpserverport']='123'

  output=$(check_add_config 'TEST_MODE' 'sendemail.smtpserverport')
  expected="git config --local sendemail.smtpserverport '123'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$output" "$expected"

  options_values['user.name']='Lala Xpto'

  output=$(printf '%s\n' 'n' | check_add_config 'TEST_MODE' 'user.name')
  ret="$?"
  assert_equals_helper 'Operation should be cancelled' "$LINENO" "$ret" 125

  output=$(printf '%s\n' 'y' | check_add_config 'TEST_MODE' 'user.name' | tail -n 1)
  expected="git config --local user.name 'Lala Xpto'"
  assert_equals_helper 'Testing confirmation' "$LINENO" "$output" "$expected"

  options_values['FORCE']=1

  output=$(check_add_config 'TEST_MODE' 'user.name')
  expected="git config --local user.name 'Lala Xpto'"
  assert_equals_helper 'Testing forced execution' "$LINENO" "$output" "$expected"

  # global tests must use the force option
  options_values['SCOPE']='global'
  options_values['CMD_SCOPE']='global'

  output=$(check_add_config 'TEST_MODE' 'user.name')
  expected="git config --global user.name 'Lala Xpto'"
  assert_equals_helper 'Testing global scope' "$LINENO" "$output" "$expected"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
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
  parse_mail_options '--force' '--smtpencryption' 'ssl' '--smtppass' 'verySafePass' \
    '--email' 'test@email.com' '--name' 'Xpto Lala' \
    '--smtpuser' 'test@email.com' '--smtpserver' 'test.email.com'

  output=$(mail_setup 'TEST_MODE' | sort -d)
  compare_command_sequence 'expected_results' "$output" "$LINENO"

  unset options_values
  declare -gA options_values

  parse_mail_options '--local' '--smtpserverport' '123'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --local sendemail.smtpserverport '123'"
  assert_equals_helper 'Testing serverport option' "$LINENO" "$output" "$expected"

  unset options_values
  declare -gA options_values

  # we need to force in case the user has set config at a global scope
  parse_mail_options '--force' '--global' '--smtppass' 'verySafePass'

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
  parse_mail_options '--smtppass' 'verySafePass'

  output=$(mail_setup 'TEST_MODE')
  ret="$?"
  assert_equals_helper 'Should fail outside of git repo' "$LINENO" "$ret" 22

  parse_mail_options '--force' '--global'

  output=$(mail_setup 'TEST_MODE')
  expected="git config --global sendemail.smtppass 'verySafePass'"
  assert_equals_helper 'Testing global option outside git' "$LINENO" "$output" "$expected"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
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
  compare_command_sequence 'expected_results' "$output" "$LINENO"

  unset options_values
  unset set_confs
  declare -gA options_values
  declare -gA set_confs

  # fulfill required options
  parse_mail_options '--local' '--smtpuser' 'test@email.com' '--smtpserver' \
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
  compare_command_sequence 'expected_results' "$output" "$LINENO"

  unset options_values
  unset set_confs
  declare -gA options_values
  declare -gA set_confs

  # complete all the settings
  parse_mail_options '--local' '--smtpuser' 'test@email.com' '--smtpserver' \
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

  parse_mail_options '--local' '--smtpserver' './fake_server/'
  mail_setup &> /dev/null
  get_configs

  output=$(mail_verify)
  compare_command_sequence 'expected_results' "$output" "$LINENO"

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
    '[local: test@email.com]'
    'SMTPSERVER'
    '[local: test.email.com]'
    'SMTPSERVERPORT'
    '[local: 123]'
    'These are the optional configurations for git send-email:'
    'SMTPENCRYPTION'
    '[local: ssl]'
    'SMTPPASS'
    '[local: verySafePass]'
  )

  cd "$FAKE_GIT" || {
    ret="$?"
    fail "($LINENO): Failed to move to fake git repo"
    exit "$ret"
  }

  parse_mail_options '--force' '--local' '--smtpuser' 'test@email.com' '--smtpserver' \
    'test.email.com' '--smtpserverport' '123' '--smtpencryption' 'ssl' \
    '--smtppass' 'verySafePass'
  mail_setup &> /dev/null

  output=$(mail_list)
  compare_command_sequence 'expected_results' "$output" "$LINENO"

  cd "$ORIGINAL_DIR" || {
    ret="$?"
    fail "($LINENO): Failed to move back to original dir"
    exit "$ret"
  }
}

invoke_shunit
