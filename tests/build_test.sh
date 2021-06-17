include './src/build.sh'
include './tests/utils.sh'

function get_kernel_release_mock()
{
  echo '5.4.0-rc7-test'
}

function get_kernel_version_mock()
{
  echo '5.4.0-rc7'
}

oneTimeSetUp()
{
  original_dir="$PWD"
  FAKE_KERNEL="$SHUNIT_TMPDIR"
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

function test_kernel_build()
{
  local expected_result

  output=$(kernel_build 'TEST_MODE' '--menu')
  expected_result="make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- nconfig"
  assertEquals "($LINENO)" "$expected_result" "$output"

  output=$(kernel_build 'TEST_MODE' '--doc')
  expected_result="make htmldocs"
  assertEquals "($LINENO)" "$expected_result" "$output"

  output=$(kernel_build 'TEST_MODE' '--notvalid')
  ret="$?"
  assertEquals "($LINENO)" "$ret" "22"

  output=$(kernel_build 'TEST_MODE' | head -1) # Remove statistics output
  expected_result="make -j$PARALLEL_CORES ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-"
  assertEquals "($LINENO)" "$expected_result" "${output}"

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

  output=$(kernel_build 'TEST_MODE' | head -1) # Remove statistics output
  expected_result="make -j$PARALLEL_CORES ARCH=x86_64 "
  assertEquals "($LINENO)" "$expected_result" "${output}"

  cp "$original_dir/$SAMPLES_DIR/.config" .config
  output=$(kernel_build 'TEST_MODE' | head -2) # Remove statistics output
  declare -a expected_result=(
    'make olddefconfig &> /dev/null'
    "make -j$PARALLEL_CORES ARCH=x86_64"
  )
  compare_command_sequence expected_result[@] "$output" "$LINENO"
  rm .config
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
  compare_command_sequence expected_cmd[@] "$output" "($LINENO)"

  cp "$original_dir/tests/samples/.config" .config
  expected_cmd[3]="$modules"
  output=$(kernel_build 'TEST_MODE' '--info')
  compare_command_sequence expected_cmd[@] "$output" "($LINENO)"
  rm .config
}

invoke_shunit
