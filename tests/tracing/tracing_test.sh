#!/bin/bash

include './tracing/tracing.sh'
include './tests/utils.sh'

function setUp()
{
  export ORIGINAL_PATH="$PWD"

  cd "${SHUNIT_TMPDIR}" || {
    fail "($LINENO): setUp(): It was not possible to move into ${SHUNIT_TMPDIR}"
    return
  }
}

function tearDown()
{
  cd "${ORIGINAL_PATH}" || {
    fail "($LINENO): tearDown(): It was not possible to move into ${ORIGINAL_PATH}"
    return
  }
}

function test_sync_main_kw_file_with_tracing()
{
  local kw_path='kw'
  local bin="${SHUNIT_TMPDIR}/bin"
  local output
  local expected

  sync_main_kw_file_with_tracing 'invalid/path' "$bin" "${SAMPLES_DIR}/tracing"
  assert_equals_helper 'Invalid `kw_path` should return 2' "$LINENO" 2 "$?"

  sync_main_kw_file_with_tracing "$kw_path" 'invalid/path' "${SAMPLES_DIR}/tracing"
  assert_equals_helper 'Invalid `bin` should return 2' "$LINENO" 2 "$?"

  cp "${SAMPLES_DIR}/tracing/kw_main_file_mock" "${SHUNIT_TMPDIR}/${kw_path}"
  mkdir --parents "$bin"

  sync_main_kw_file_with_tracing "$kw_path" "$bin" "${SAMPLES_DIR}/tracing"

  [[ -x "${bin}/${kw_path}" ]]
  assert_equals_helper 'Should create an executable kw main file at bin' "$LINENO" 0 "$?"

  output=$(< "${bin}/${kw_path}")
  expected=$(
    cat << 'EOF'
#!/bin/bash

# This is a mock to test the injection of tracing code into kw main file

some_command "$arg1" "$arg2"

local some_setup_code

some_setup_code='to test if the injection was successful'

if [[ "$this_is_an" == 'an if statement' ]]; then
do_something
fi

function foo()
{
bar

local some_commit_code

some_commit_code='to test if the injection was successful'
}
EOF
  )
  assert_equals_helper 'The file was not correctly generated' "$LINENO" "$expected" "$output"
}

invoke_shunit
