#!/bin/bash

include './src/build.sh' > /dev/null
include './tests/utils.sh'

oneTimeSetUp()
{
  original_dir="$PWD"
  FAKE_KERNEL="${SHUNIT_TMPDIR}/fake_kernel"
  KW_DATA_DIR="$SHUNIT_TMPDIR"

  kw_etc_dir="$KW_ETC_DIR"
  xdg_config_dirs="$XDG_CONFIG_DIRS"
  KW_BUILD_CONFIG_TEMPLATE="$PWD/etc/init_templates/x86-64/build_template.config"
  parse_configuration "$KW_CONFIG_SAMPLE"
  parse_configuration "$KW_BUILD_CONFIG_SAMPLE" build_config

  BUILD_CONFIG_FILENAME='build.config'

  if [ -x "$(command -v nproc)" ]; then
    PARALLEL_CORES=$(nproc --all)
  else
    PARALLEL_CORES=$(grep -c ^processor /proc/cpuinfo)
  fi
  export PARALLEL_CORES
  export SCALING=$((PARALLEL_CORES / 2))

  shopt -s expand_aliases
  alias get_kernel_release='get_kernel_release_mock'
  alias get_kernel_version='get_kernel_version_mock'
}

oneTimeTearDown()
{
  [[ -d "$SHUNIT_TMPDIR" ]] && rm -rf "$SHUNIT_TMPDIR"
  rm -rf "$SHUNIT_TMPDIR"
}

setUp()
{
  [[ -d "$SHUNIT_TMPDIR" ]] || mkdir -p "$SHUNIT_TMPDIR"
  cp "$KW_BUILD_CONFIG_TEMPLATE" "$SHUNIT_TMPDIR/build.config"

  KW_ETC_DIR="$kw_etc_dir"
  XDG_CONFIG_DIRS="$kw_etc_dir"

  mkdir -p "$FAKE_KERNEL"
  mk_fake_kernel_root "$FAKE_KERNEL"

  # In this case we actually want to exit, since all tests below rely on
  # being in a kernel root
  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move into fake kernel directory"
    return
  }
}

tearDown()
{
  [[ -d "$SHUNIT_TMPDIR" ]] && rm -rf "$SHUNIT_TMPDIR"

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

function get_kernel_release_mock()
{
  printf '%s\n' '5.4.0-rc7-test'
}

function get_kernel_version_mock()
{
  printf '%s\n' '5.4.0-rc7'
}

function assertConfigurations()
{
  declare -n configurations_ref="$1"
  declare -n expected_configurations_ref="$2"

  # Check if configurations is contained in expected_configurations
  for k in "${!configurations_ref[@]}"; do
    assert_equals_helper "Did not expect setting '$k'" "($LINENO)" "${expected_configurations_ref[$k]+token}" token
    assert_equals_helper "Did not expect setting '$k'" "($LINENO)" "${expected_configurations_ref[$k]}" "${configurations_ref[$k]}"
  done

  # check if configurations has all expected_configurations keys
  for k in "${!expected_configurations_ref[@]}"; do
    assert_equals_helper "Expected setting '$k' to be present" "($LINENO)" "${configurations_ref[$k]+token}" token
  done
}

function test_parse_build_config_success_exit_code()
{
  local build_config=()

  parse_configuration "$KW_BUILD_CONFIG_SAMPLE" build_config
  assert_equals_helper 'kw failed to load a regular config file' "($LINENO)" 0 "$?"
}

# Test if etc/init_templates/build_template.config contains all the expected settings
function test_parse_build_config_standard_config()
{
  build_config=()

  declare -A expected_build_configurations=(
    [arch]='x86_64'
    [kernel_img_name]='bzImage'
    [menu_config]='nconfig'
    [doc_type]='htmldocs'
    [doc_type]='htmldocs'
    [cpu_scaling_factor]=100
  )

  parse_configuration "$SHUNIT_TMPDIR/build.config" build_config
  assertConfigurations build_config expected_build_configurations "$LINENO"
}

# To test the order of config file loading, we will put a file named
# kworkflow.config in each place, in order, and remove the previous one.
# The order is: PWD, XDG_CONFIG_HOME, XDG_CONFIG_DIRS, KW_ETC_DIR
function test_parse_configuration_files_loading_order()
{
  local -a expected
  local original_dir="$PWD"

  build_config=()

  KW_ETC_DIR='1'
  XDG_CONFIG_DIRS='2:3:4'
  XDG_CONFIG_HOME='5'

  local expected=(
    "1/${BUILD_CONFIG_FILENAME}"
    "4/${KWORKFLOW}/${BUILD_CONFIG_FILENAME}"
    "3/${KWORKFLOW}/${BUILD_CONFIG_FILENAME}"
    "2/${KWORKFLOW}/${BUILD_CONFIG_FILENAME}"
    "5/${KWORKFLOW}/${BUILD_CONFIG_FILENAME}"
    'Please use kw init to update your config files'
  )

  output="$(
    function parse_configuration()
    {
      printf '%s\n' "$1"
    }
    load_build_config
  )"

  compare_command_sequence 'Wrong config file reading order' "$LINENO" 'expected' "$output"

  # IF XDG global variables are not defined
  unset XDG_CONFIG_DIRS
  unset XDG_CONFIG_HOME
  HOME='5'

  expected=(
    "1/${BUILD_CONFIG_FILENAME}"
    "/etc/xdg/${KWORKFLOW}/${BUILD_CONFIG_FILENAME}"
    "5/.config/${KWORKFLOW}/${BUILD_CONFIG_FILENAME}"
    'Please use kw init to update your config files'
    "${PWD}/${BUILD_CONFIG_FILENAME}"
  )

  output="$(
    function parse_configuration()
    {
      printf '%s\n' "$1"
    }
    load_build_config
  )"

  compare_command_sequence 'Wrong config file reading order' "$LINENO" 'expected' "$output"
}

function test_load_build_config()
{
  local current_path="$PWD"
  local -a expected

  build_config=()

  KW_ETC_DIR='1'
  unset XDG_CONFIG_DIRS
  unset XDG_CONFIG_HOME
  HOME='5'

  # Test preparation
  mkdir -p "${FAKE_KERNEL}/${KW_DIR}"
  cp "${KW_BUILD_CONFIG_TEMPLATE}" "${FAKE_KERNEL}/${KW_DIR}/build.config"

  expected=(
    "1/${BUILD_CONFIG_FILENAME}"
    "/etc/xdg/${KWORKFLOW}/${BUILD_CONFIG_FILENAME}"
    "5/.config/${KWORKFLOW}/${BUILD_CONFIG_FILENAME}"
    "${PWD}/${KW_DIR}/${BUILD_CONFIG_FILENAME}"
  )

  output="$(
    function parse_configuration()
    {
      printf '%s\n' "$1"
    }
    load_build_config
  )"

  compare_command_sequence '' "$LINENO" 'expected' "$output"
}

function test_kernel_build_cross_compilation_flags()
{
  local expected_result
  local output
  build_config=()

  parse_configuration "$SAMPLES_DIR/build_no_llvm.config" build_config

  # For CI: The tail and head command remove statistics output
  output=$(kernel_build 'TEST_MODE' | tail -n +1 | head -2)

  declare -a expected_cmd=(
    'make -j ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- --silent olddefconfig'
    "make -j${PARALLEL_CORES} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=2 2>&1 | tee ./log"
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_kernel_build_menu_cross_compilation_flags()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --menu)
  expected_result='make -j ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- nconfig'
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_kernel_build_html_doc()
{
  local expected_result
  local output

  build_config=()
  parse_configuration "$SAMPLES_DIR/build_no_log.config" build_config

  output=$(kernel_build 'TEST_MODE' --doc)
  expected_result="make -j${PARALLEL_CORES} htmldocs"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_kernel_build_html_doc_with_ccache()
{
  local expected_result
  local output

  build_config=()
  parse_configuration "$SAMPLES_DIR/build_no_log.config" build_config

  output=$(kernel_build 'TEST_MODE' --doc --ccache)
  expected_result="make CC=\"ccache gcc -fdiagnostics-color\" -j${PARALLEL_CORES} htmldocs"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_kernel_build_html_doc_with_save_log_option()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --doc --save-log-to docs.out)
  expected_result="make -j${PARALLEL_CORES} htmldocs 2>&1 | tee docs.out"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_kernel_build_invalid_flag()
{
  local output
  local ret

  output=$(kernel_build 'TEST_MODE' --notvalid 2> /dev/null)
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
  assert_equals_helper 'We expected an error' "($LINENO)" "$ret" 125

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move into temporary directory"
    return
  }
}

function test_kernel_build_x86()
{
  local expected_result
  local output

  # Test preparation
  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }

  configurations=()
  build_config=()
  cp "$KW_BUILD_CONFIG_SAMPLE_X86" "${FAKE_KERNEL}/build.config"
  parse_configuration "${FAKE_KERNEL}/build.config" build_config

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move into temporary directory"
    return
  }

  # For CI: The tail and head command remove statistics output
  output=$(kernel_build 'TEST_MODE' | tail -n +1 | head -2)
  declare -a expected_cmd=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make -j$PARALLEL_CORES ARCH=x86_64"
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_parse_build_options_check_options_values()
{
  unset options_values
  declare -gA options_values

  # test default options
  parse_build_options

  assert_equals_helper 'Default ARCH did not match expectation' \
    "($LINENO)" 'x86_64' "${options_values['ARCH']}"

  assert_equals_helper 'Default MENU_CONFIG did not match expectation' \
    "($LINENO)" '' "${options_values['MENU_CONFIG']}"

  assert_equals_helper 'Default CROSS_COMPILE did not match expectation' \
    "($LINENO)" '' "${options_values['CROSS_COMPILE']}"

  assert_equals_helper 'Default CPU_SCALING_FACTOR did not match expectation' \
    "($LINENO)" 100 "${options_values['CPU_SCALING_FACTOR']}"

  assert_equals_helper 'Default CCACHE did not match expectation' \
    "($LINENO)" '' "${options_values['CCACHE']}"

  assert_equals_helper 'Default INFO did not match expectation' \
    "($LINENO)" '' "${options_values['INFO']}"

  assert_equals_helper 'Default DOC_TYPE did not match expectation' \
    "($LINENO)" '' "${options_values['DOC_TYPE']}"

  assert_equals_helper 'Default LOG_PATH did not match expectation' \
    "($LINENO)" '' "${options_values['LOG_PATH']}"
}

function test_parse_build_options()
{
  unset options_values
  declare -gA options_values
  local output
  local help_output

  # Warning options
  options_values=()
  parse_build_options --warnings
  assert_equals_helper 'Could not set build option WARNINGS' \
    "($LINENO)" '1' "${options_values['WARNINGS']}"

  options_values=()
  parse_build_options -w
  assert_equals_helper 'Could not set build option WARNINGS' \
    "($LINENO)" '1' "${options_values['WARNINGS']}"

  options_values=()
  parse_build_options --warnings 123
  assert_equals_helper 'Could not set build option WARNINGS' \
    "($LINENO)" '123' "${options_values['WARNINGS']}"

  options_values=()
  parse_build_options -w 123
  assert_equals_helper 'Could not set build option WARNINGS' \
    "($LINENO)" '123' "${options_values['WARNINGS']}"

  # Check help option
  help_output=$(build_help)
  options_values=()
  output=$(parse_build_options -h)
  assert_equals_helper 'Could not access build help' \
    "($LINENO)" "$help_output" "$output"

  # Test info
  options_values=()
  parse_build_options --info
  assert_equals_helper 'Could not set build option INFO' \
    "($LINENO)" 1 "${options_values['INFO']}"

  options_values=()
  parse_build_options -i
  assert_equals_helper 'Could not set build option INFO' \
    "($LINENO)" 1 "${options_values['INFO']}"

  # Menu
  options_values=()
  parse_build_options --menu
  assert_equals_helper 'Could not set build option MENU_CONFIG' \
    "($LINENO)" 'nconfig' "${options_values['MENU_CONFIG']}"

  # Doc
  options_values=()
  parse_build_options --doc
  assert_equals_helper 'Could not set build option DOC_TYPE' \
    "($LINENO)" 'htmldocs' "${options_values['DOC_TYPE']}"

  options_values=()
  parse_build_options -d
  assert_equals_helper 'Could not set build option DOC_TYPE' \
    "($LINENO)" 'htmldocs' "${options_values['DOC_TYPE']}"

  # CPU Scaling option
  options_values=()
  parse_build_options --cpu-scaling 150 > /dev/null
  assert_equals_helper 'Could not set build option CPU_SCALING_FACTOR' \
    "($LINENO)" 150 "${options_values['CPU_SCALING_FACTOR']}"

  options_values=()
  parse_build_options -c 150 > /dev/null
  assert_equals_helper 'Could not set build option CPU_SCALING_FACTOR' \
    "($LINENO)" 150 "${options_values['CPU_SCALING_FACTOR']}"

  # CCACHE
  options_values=()
  parse_build_options --ccache
  assert_equals_helper 'Could not set build option CCACHE' \
    "($LINENO)" 1 "${options_values['CCACHE']}"

  # Save log option
  options_values=()
  parse_build_options --save-log-to out.log
  assert_equals_helper 'Could not set build option LOG_PATH' \
    "($LINENO)" 'out.log' "${options_values['LOG_PATH']}"

  options_values=()
  parse_build_options -s out.log
  assert_equals_helper 'Could not set build option LOG_PATH' \
    "($LINENO)" 'out.log' "${options_values['LOG_PATH']}"

  # LLVM
  options_values=()
  parse_build_options --llvm
  assert_equals_helper 'Could not set build option USE_LLVM_TOOLCHAIN' \
    "($LINENO)" 1 "${options_values['USE_LLVM_TOOLCHAIN']}"

  # Unsopported option
  output="$(parse_build_options --mispelled 2>&1)"
  assertEquals "($LINENO)" 22 "$?"
}

function test_build_info()
{
  local release='5.4.0-rc7-test'
  local version='5.4.0-rc7'
  local release_output="Name: ${release}"
  local version_output="Version: ${version}"
  local modules
  local expected_cmd

  declare -a expected_cmd=(
    'Kernel source information'
    "$release_output"
    "$version_output"
  )

  output=$(kernel_build 'TEST_MODE' '--info')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  # Change modules
  modules='Total modules to be compiled: 5'
  cp "${original_dir}/tests/samples/.config" '.config'
  expected_cmd[3]="$modules"
  output=$(kernel_build 'TEST_MODE' '--info')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_kernel_build_only_cpu_scaling_option()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --cpu-scaling 50 | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make -j${SCALING} ARCH=x86_64"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_cpu_scaling_and_warning()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --cpu-scaling 50 --warnings 123 | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make -j${SCALING} ARCH=x86_64 W=123"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_cpu_scaling_with_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --cpu-scaling 50 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make -j${SCALING} ARCH=x86_64 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_cpu_scaling_llvm()
{
  local expected_result
  local output

  build_config['USE_LLVM_TOOLCHAIN']='yes'
  output=$(kernel_build 'TEST_MODE' --cpu-scaling 50 --llvm | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make -j$SCALING LLVM=1 ARCH=x86_64"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_warning_and_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --warnings 123 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make -j${PARALLEL_CORES} ARCH=x86_64 W=123 2>&1 | tee log.out"
  )

  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_kernel_ccache_cpu_scaling_warning()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --cpu-scaling 50 --warnings 123 | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache gcc -fdiagnostics-color\" -j${SCALING} ARCH=x86_64 W=123"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"

  output=$(kernel_build 'TEST_MODE' --ccache --cpu-scaling 50 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_cmd=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache gcc -fdiagnostics-color\" -j${SCALING} ARCH=x86_64 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_cmd' "$output"

  output=$(kernel_build 'TEST_MODE' --ccache --warnings 123 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_cmd=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache gcc -fdiagnostics-color\" -j${PARALLEL_CORES} ARCH=x86_64 W=123 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_cmd' "$output"
}

function test_kernel_build_kernel_ccache_cpu_scaling_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --cpu-scaling 50 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache gcc -fdiagnostics-color\" -j${SCALING} ARCH=x86_64 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_ccache_warning_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --warnings 123 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache gcc -fdiagnostics-color\" -j${PARALLEL_CORES} ARCH=x86_64 W=123 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_with_llvm_warning()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --llvm --warnings 123 | tail -n +1 | head -2)
  declare -a expected_cmd=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make -j${PARALLEL_CORES} LLVM=1 ARCH=x86_64 W=123"
  )
  compare_command_sequence '' "($LINENO)" 'expected_cmd' "$output"
}

function test_kernel_build_with_llvm_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --llvm --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make -j${PARALLEL_CORES} LLVM=1 ARCH=x86_64 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_ccache_cpu_scaling_llvm()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --cpu-scaling 50 --llvm | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache clang -fdiagnostics-color\" -j${SCALING} LLVM=1 ARCH=x86_64"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_ccache_cpu_scaling_warning()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --cpu-scaling 50 --warnings 123 | tail -n +1 | head -2)
  declare -a expected_cmd=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache gcc -fdiagnostics-color\" -j${SCALING} ARCH=x86_64 W=123"
  )
  compare_command_sequence '' "($LINENO)" 'expected_cmd' "$output"
}

function test_kernel_build_ccache_cpu_scaling_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --cpu-scaling 50 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache gcc -fdiagnostics-color\" -j${SCALING} ARCH=x86_64 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_ccache_llvm_warning()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --llvm --warnings 123 | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache clang -fdiagnostics-color\" -j${PARALLEL_CORES} LLVM=1 ARCH=x86_64 W=123"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_ccache_llvm_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --llvm --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache clang -fdiagnostics-color\" -j${PARALLEL_CORES} LLVM=1 ARCH=x86_64 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_cmd' "$output"
}

function test_kernel_build_ccache_llvm_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --warnings 123 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache gcc -fdiagnostics-color\" -j${PARALLEL_CORES} ARCH=x86_64 W=123 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_cpu_scaling_llvm_warning()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --cpu-scaling 50 --llvm --warnings 123 | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make -j${SCALING} LLVM=1 ARCH=x86_64 W=123"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_cpu_scaling_llvm_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --cpu-scaling 50 --llvm --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make -j${SCALING} LLVM=1 ARCH=x86_64 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_cpu_scaling_warning_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --cpu-scaling 50 --warnings 123 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_cmd=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make -j${SCALING} ARCH=x86_64 W=123 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_cmd' "$output"
}

function test_kernel_build_ccache_cpu_scaling_llvm_warning()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --cpu-scaling 50 --llvm --warnings 123 | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache clang -fdiagnostics-color\" -j${SCALING} LLVM=1 ARCH=x86_64 W=123"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_ccache_cpu_scaling_llvm_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --cpu-scaling 50 --llvm --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache clang -fdiagnostics-color\" -j${SCALING} LLVM=1 ARCH=x86_64 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_ccache_cpu_scaling_warning_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --cpu-scaling 50 --warnings 123 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_cmd=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache gcc -fdiagnostics-color\" -j${SCALING} ARCH=x86_64 W=123 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_cmd' "$output"
}

function test_kernel_build_ccache_llvm_warning_save_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --ccache --llvm --warnings 123 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make CC=\"ccache clang -fdiagnostics-color\" -j${PARALLEL_CORES} LLVM=1 ARCH=x86_64 W=123 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_cpu_scaling_llvm_warning_sava_log_to()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --cpu-scaling 50 --llvm --warnings 123 --save-log-to log.out | tail -n +1 | head -2)
  declare -a expected_result=(
    'make -j LLVM=1 ARCH=x86_64 --silent olddefconfig'
    "make -j$SCALING LLVM=1 ARCH=x86_64 W=123 2>&1 | tee log.out"
  )
  compare_command_sequence '' "($LINENO)" 'expected_result' "$output"
}

function test_kernel_build_inside_an_env()
{
  local output
  local expected_result
  local env_output="${KW_CACHE_DIR}/fake_env"
  build_config=()

  mk_fake_kw_env

  parse_configuration "$SAMPLES_DIR/build_no_llvm.config" build_config

  output=$(kernel_build 'TEST_MODE' | tail -n +1 | head -2)

  declare -a expected_cmd=(
    "make -j ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- --silent olddefconfig O=${env_output}"
    "make -j${PARALLEL_CORES} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=2 2>&1 | tee ./log O=${env_output}"
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_kernel_build_html_doc_inside_env()
{
  local expected_result
  local output
  local env_output="${KW_CACHE_DIR}/fake_env"
  build_config=()

  mk_fake_kw_env

  parse_configuration "$SAMPLES_DIR/build_no_log.config" build_config

  output=$(kernel_build 'TEST_MODE' --doc)
  expected_result="make -j${PARALLEL_CORES} htmldocs O=${env_output}"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

function test_kernel_build_menu_inside_env()
{
  local expected_result
  local output
  local env_output="${KW_CACHE_DIR}/fake_env"
  build_config=()

  mk_fake_kw_env

  parse_configuration "$SAMPLES_DIR/build_no_log.config" build_config

  output=$(kernel_build 'TEST_MODE' --menu)
  expected_result="make -j ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- nconfig O=${env_output}"
  assertEquals "($LINENO)" "$expected_result" "$output"
}

invoke_shunit
