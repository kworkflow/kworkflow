#!/bin/bash

include './src/build.sh'
include './tests/utils.sh'

function get_kernel_release_mock()
{
  printf '%s\n' '5.4.0-rc7-test'
}

function get_kernel_version_mock()
{
  printf '%s\n' '5.4.0-rc7'
}

oneTimeSetUp()
{
  original_dir="$PWD"
  FAKE_KERNEL="$SHUNIT_TMPDIR"
  KW_DATA_DIR="$SHUNIT_TMPDIR"
  mk_fake_kernel_root "$FAKE_KERNEL"

  parse_configuration "$KW_CONFIG_SAMPLE"

  if [ -x "$(command -v nproc)" ]; then
    PARALLEL_CORES=$(nproc --all)
  else
    PARALLEL_CORES=$(grep -c ^processor /proc/cpuinfo)
  fi
  export PARALLEL_CORES

  shopt -s expand_aliases
  alias get_kernel_release='get_kernel_release_mock'
  alias get_kernel_version='get_kernel_version_mock'

}

setUp()
{
  # In this case we actually want to exit, since all tests below rely on
  # being in a kernel root
  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move into fake kernel directory"
    return
  }
}

tearDown()
{
  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

function test_kernel_build_cross_compilation_flags()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' | tail -n +1 | head -2) # Remove statistics output
  declare -a expected_cmd=(
    "make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig --silent"
    "make -j$PARALLEL_CORES ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-"
  )

  compare_command_sequence 'expected_cmd' "$output" "$LINENO"
}

function test_kernel_build_menu_cross_compilation_flags()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' '--menu')
  expected_result="make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- nconfig"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_kernel_build_html_doc()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' '--doc')
  expected_result="make htmldocs"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_kernel_build_invalid_flag()
{
  local output
  local ret

  output=$(kernel_build 'TEST_MODE' '--notvalid' 2> /dev/null)
  ret="$?"
  assertEquals "($LINENO)" "$ret" 22
}

function test_kernel_build_outside_kernel_repository()
{
  local ret
  local output

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }

  output=$(kernel_build 'TEST_MODE')
  ret="$?"
  assertEquals "($LINENO) We expected an error" "$ret" 125

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move into temporary directory"
    return
  }
}

function test_kernel_build_x86()
{
  local expected_result
  local output

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }

  output=$(kernel_build 'TEST_MODE')
  ret="$?"
  assertEquals "($LINENO) We expected an error" "125" "$ret"

  configurations=()
  cp "$KW_CONFIG_SAMPLE_X86" "$FAKE_KERNEL/kworkflow.config"
  parse_configuration "$FAKE_KERNEL/kworkflow.config"

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move into temporary directory"
    return
  }

  output=$(kernel_build 'TEST_MODE' | tail -n +1 | head -2) # Remove statistics output
  declare -a expected_cmd=(
    "make ARCH=x86_64  olddefconfig --silent"
    "make -j$PARALLEL_CORES ARCH=x86_64"
  )

  compare_command_sequence 'expected_cmd' "$output" "$LINENO"
}

function test_parse_build_options()
{
  unset options_values
  declare -gA options_values
  local output
  local help_output

  # test default options
  parse_build_options
  assertEquals "($LINENO)" 'x86_64' "${options_values['ARCH']}"
  assertEquals "($LINENO)" '' "${options_values['MENU_CONFIG']}"
  assertEquals "($LINENO)" '' "${options_values['CROSS_COMPILE']}"
  assertEquals "($LINENO)" '1' "${options_values['PARALLEL_CORES']}"
  assertEquals "($LINENO)" '' "${options_values['INFO']}"
  assertEquals "($LINENO)" '' "${options_values['DOC_TYPE']}"

  # test individual options
  help_output="$(build_help)"
  unset options_values
  declare -gA options_values
  output="$(parse_build_options -h)"
  assertEquals "($LINENO)" "$help_output" "$output"

  unset options_values
  declare -gA options_values
  parse_build_options --info
  assertEquals "($LINENO)" '1' "${options_values['INFO']}"

  unset options_values
  declare -gA options_values
  parse_build_options -i
  assertEquals "($LINENO)" '1' "${options_values['INFO']}"

  unset options_values
  declare -gA options_values
  parse_build_options --menu
  assertEquals "($LINENO)" 'nconfig' "${options_values['MENU_CONFIG']}"

  unset options_values
  declare -gA options_values
  parse_build_options --doc
  assertEquals "($LINENO)" 'htmldocs' "${options_values['DOC_TYPE']}"

  unset options_values
  declare -gA options_values
  parse_build_options -d
  assertEquals "($LINENO)" 'htmldocs' "${options_values['DOC_TYPE']}"

  output="$(parse_build_options --mispelled 2>&1)"
  assertEquals "($LINENO)" 22 "$?"
  assertEquals "($LINENO)" "kw build: unrecognized option '--mispelled'" "$output"
}

function test_build_info()
{
  local release='5.4.0-rc7-test'
  local version='5.4.0-rc7'
  local release_output="Name: $release"
  local version_output="Version: $version"
  local modules='Total modules to be compiled: 5'

  declare -a expected_cmd=(
    'Kernel source information'
    "$release_output"
    "$version_output"
  )

  output=$(kernel_build 'TEST_MODE' '--info')
  compare_command_sequence 'expected_cmd' "$output" "($LINENO)"

  cp "$original_dir/tests/samples/.config" .config
  expected_cmd[3]="$modules"
  output=$(kernel_build 'TEST_MODE' '--info')
  compare_command_sequence 'expected_cmd' "$output" "($LINENO)"
  rm .config
}

invoke_shunit
