#!/usr/bin/env bash

include './tracing/tracing.sh'
include './tests/unit/utils.sh'

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
#!/usr/bin/env bash

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

function test_sync_kw_lib_files_with_tracing()
{
  local input_dir='src'
  local output_dir="${SHUNIT_TMPDIR}/lib"
  local output

  cp --recursive "${SAMPLES_DIR}/tracing/src" './'
  mkdir --parents "$output_dir"

  sync_kw_lib_files_with_tracing "$input_dir" "$output_dir"

  output=$(find "$output_dir" -type f)
  assert_line_match "$LINENO" "${SHUNIT_TMPDIR}/lib/nothing_to_inject.sh" "$output"
  assert_line_match "$LINENO" "${SHUNIT_TMPDIR}/lib/simple_return_and_exit.sh" "$output"
  assert_line_match "$LINENO" "${SHUNIT_TMPDIR}/lib/alternate_return_and_exit.sh" "$output"
  assert_line_match "$LINENO" "${SHUNIT_TMPDIR}/lib/background_execution.sh" "$output"
  assert_line_match "$LINENO" "${SHUNIT_TMPDIR}/lib/lib/stub.sh" "$output"
}

function test_inject_lib_file_with_tracing_nothing_to_inject()
{
  local output
  local expected

  output=$(inject_lib_file_with_tracing "${SAMPLES_DIR}/tracing/src/nothing_to_inject.sh")
  expected='# Comment'$'\n''command1'$'\n'$'\n''command2'
  assert_equals_helper 'The file was not correctly injected' "$LINENO" "$expected" "$output"

  output=$(inject_lib_file_with_tracing "${SAMPLES_DIR}/tracing/src/simple_return_and_exit.sh")
  expected=$(
    cat << 'EOF'
function foo()
{
printf 'entry,foo,%s\n' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"
printf 'return,foo,%s\n' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"
return 0
# shellcheck disable=SC2317
printf 'exit,foo,%s\n' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"
exit 0
local _return_val="$?"
printf 'return,foo,%s\n' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"
return "$_return_val"
}
EOF
  )
  assert_equals_helper 'The file was not correctly injected' "$LINENO" "$expected" "$output"
}

function test_inject_lib_file_with_alternate_return_and_exit()
{
  local output
  local expected

  output=$(inject_lib_file_with_tracing "${SAMPLES_DIR}/tracing/src/alternate_return_and_exit.sh")
  expected=$(
    cat << 'EOF'
function foo()
{
printf 'entry,foo,%s\n' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"
command1 && command2 && printf 'return,foo,%s\n' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv" && return 0
command3 && command4 && printf 'exit,foo,%s\n' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv" && exit 0
local _return_val="$?"
printf 'return,foo,%s\n' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"
return "$_return_val"
}
EOF
  )
  assert_equals_helper 'The file was not correctly injected' "$LINENO" "$expected" "$output"
}

function test_inject_lib_file_with_background_execution()
{
  local output
  local expected

  output=$(inject_lib_file_with_tracing "${SAMPLES_DIR}/tracing/src/background_execution.sh")
  expected=$(
    cat << 'EOF'
function foo()
{
printf 'entry,foo,%s\n' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"
THREAD_NUMBER=$((++TOTAL_NUMBER_OF_THREADS))
command &
THREAD_NUMBER=0
local _return_val="$?"
printf 'return,foo,%s\n' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"
return "$_return_val"
}
EOF
  )
  assert_equals_helper 'The file was not correctly injected' "$LINENO" "$expected" "$output"
}

function test_process_function_line()
{
  local line
  local function_name='foo'
  local output
  local expected

  line='generic_line "$that_should_not" "$be_altered"'
  output=$(process_function_line "$line" "$function_name")
  expected="$line"
  assert_equals_helper 'Non-special line should remain unaltered' "$LINENO" "$expected" "$output"

  line='}'
  output=$(process_function_line "$line" "$function_name")
  expected='local _return_val="$?"'$'\n'
  expected+='printf '"'"'return,foo,%s\n'"'"' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"'$'\n'
  expected+='return "$_return_val"'$'\n'
  expected+='}'
  assert_equals_helper 'End of function definition should log return and preserve last command return' "$LINENO" "$expected" "$output"

  line='    return 235'
  output=$(process_function_line "$line" "$function_name")
  expected='printf '"'"'return,foo,%s\n'"'"' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"'$'\n'
  expected+='    return 235'
  assert_equals_helper 'Simple return should log return' "$LINENO" "$expected" "$output"

  line='command && return 235'
  output=$(process_function_line "$line" "$function_name")
  expected='command && printf '"'"'return,foo,%s\n'"'"' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv" && return 235'
  assert_equals_helper '&& return should log return in same line' "$LINENO" "$expected" "$output"

  line='  exit 271'
  output=$(process_function_line "$line" "$function_name")
  expected='printf '"'"'exit,foo,%s\n'"'"' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv"'$'\n'
  expected+='  exit 271'
  assert_equals_helper 'Simple exit should log exit' "$LINENO" "$expected" "$output"

  line='command && exit 271'
  output=$(process_function_line "$line" "$function_name")
  expected='command && printf '"'"'exit,foo,%s\n'"'"' "$(date +%s%N)" >> "${TMP_TRACING_DIR}/${THREAD_NUMBER}.csv" && exit 271'
  assert_equals_helper '&& exit should log exit in same line' "$LINENO" "$expected" "$output"
}

function test_get_tracing_log_line()
{
  local output
  local expected

  output=$(get_tracing_log_line 'entry' 'foo')
  expected="printf 'entry,foo,%s\n' \"\$(date +%s%N)\" >> \"\${TMP_TRACING_DIR}/\${THREAD_NUMBER}.csv\""
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  output=$(get_tracing_log_line 'exit' 'foo')
  expected="printf 'exit,foo,%s\n' \"\$(date +%s%N)\" >> \"\${TMP_TRACING_DIR}/\${THREAD_NUMBER}.csv\""
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"

  output=$(get_tracing_log_line 'return' 'foo')
  expected="printf 'return,foo,%s\n' \"\$(date +%s%N)\" >> \"\${TMP_TRACING_DIR}/\${THREAD_NUMBER}.csv\""
  assert_equals_helper 'Wrong output' "$LINENO" "$expected" "$output"
}

invoke_shunit
