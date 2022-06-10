#!/bin/bash

include './src/build.sh' > /dev/null
include './tests/utils.sh'

TMP_DIR="$PWD/tests/.tmp_kw_build_config_tests"

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

  kw_etc_dir="$KW_ETC_DIR"
  xdg_config_dirs="$XDG_CONFIG_DIRS"
  xdg_config_home="$XDG_CONFIG_HOME"
  home="$HOME"
  KW_BUILD_CONFIG_TEMPLATE="$PWD/etc/init_templates/x86-64/build_template.config"
  parse_configuration "$KW_CONFIG_SAMPLE"
  parse_configuration "$KW_BUILD_CONFIG_SAMPLE" build_config

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
  [[ -d "$TPM_DIR" ]] && rm -rf "$TMP_DIR"
  rm -rf "$SHUNIT_TMPDIR"
}

setUp()
{
  [[ -d "$TMP_DIR" ]] || mkdir -p "$TMP_DIR"
  cp "$KW_BUILD_CONFIG_TEMPLATE" "$TMP_DIR/build.config"

  KW_ETC_DIR="$kw_etc_dir"
  XDG_CONFIG_DIRS="$kw_etc_dir"
  XDG_CONFIG_HOME="$kw_config_home"
  HOME="$home"

  # In this case we actually want to exit, since all tests below rely on
  # being in a kernel root
  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move into fake kernel directory"
    return
  }
}

tearDown()
{
  [[ -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }
}

function test_parse_build_config_success_exit_code()
{
  build_config=()

  parse_configuration "$KW_BUILD_CONFIG_SAMPLE" build_config
  assert_equals_helper 'kw failed to load a regular config file' "($LINENO)" '0' "$?"
}

function assertConfigurations()
{
  declare -n configurations_ref="$1"
  declare -n expected_configurations_ref="$2"

  # check if configurations is contained in expected_configurations
  for k in "${!configurations_ref[@]}"; do
    assert_equals_helper "Did not expect setting '$k'" "($LINENO)" "${expected_configurations_ref[$k]+token}" token
    assert_equals_helper "Did not expect setting '$k'" "($LINENO)" "${expected_configurations_ref[$k]}" "${configurations_ref[$k]}"
  done

  # check if configurations has all expected_configurations keys
  for k in "${!expected_configurations_ref[@]}"; do
    assert_equals_helper "Expected setting '$k' to be present" "($LINENO)" "${configurations_ref[$k]+token}" token
  done
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

  parse_configuration "$TMP_DIR/build.config" build_config
  assertConfigurations build_config expected_build_configurations "$LINENO"
}

# To test the order of config file loading, we will put a file named
# kworkflow.config in each place, in order, and remove the previous one.
# The order is: PWD, XDG_CONFIG_HOME, XDG_CONFIG_DIRS, KW_ETC_DIR
function test_parse_configuration_files_loading_order()
{
  local expected
  local original_dir="$PWD"

  build_config=()

  KW_ETC_DIR='1'
  XDG_CONFIG_DIRS='2:3:4'
  XDG_CONFIG_HOME='5'

  expected=(
    "1/$BUILD_CONFIG_FILENAME"
    "4/$KWORKFLOW/$BUILD_CONFIG_FILENAME"
    "3/$KWORKFLOW/$BUILD_CONFIG_FILENAME"
    "2/$KWORKFLOW/$BUILD_CONFIG_FILENAME"
    "5/$KWORKFLOW/$BUILD_CONFIG_FILENAME"
    "Please use kw init to update your config files"
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
    "1/$BUILD_CONFIG_FILENAME"
    "/etc/xdg/$KWORKFLOW/$BUILD_CONFIG_FILENAME"
    "5/.config/$KWORKFLOW/$BUILD_CONFIG_FILENAME"
    "Please use kw init to update your config files"
    "$PWD/$BUILD_CONFIG_FILENAME"
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

function test_show_build_variables_completeness()
{
  build_config=()

  local -A shown_options
  local -A possible_options
  local output

  # get all assigned options, including commented ones
  # remove #'s and ='s to get option names
  output="$(< "$KW_BUILD_CONFIG_SAMPLE")"
  output="$(printf '%s\n' "$output" | grep -oE '^(#?\w+=?)' | sed -E 's/[#=]//g')"

  for option in $output; do
    possible_options["$option"]='1'
  done

  output="$(show_build_variables 'TEST_MODE' | grep -E '^    ')"
  output="$(sed 's/.*(\(\S*\)).*/\1/' <<< "$output")"

  for option in $output; do
    shown_options["$option"]=1
  done

  for option in "${!possible_options[@]}"; do
    if [[ ! -v shown_options["$option"] ]]; then
      fail "($LINENO): shown_options is missing option $option"
    fi
  done

  for option in "${!shown_options[@]}"; do
    if [[ ! -v possible_options["$option"] ]]; then
      fail "($LINENO): show_variable is showing $option not present in kworkflow_template.config"
    fi
  done
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

  cp "$KW_BUILD_CONFIG_TEMPLATE" "$SHUNIT_TMPDIR/build.config"

  mkdir -p "$SHUNIT_TMPDIR/$KW_DIR"
  cp "$KW_BUILD_CONFIG_TEMPLATE" "$SHUNIT_TMPDIR/$KW_DIR/build.config"

  expected=(
    "1/$BUILD_CONFIG_FILENAME"
    "/etc/xdg/$KWORKFLOW/$BUILD_CONFIG_FILENAME"
    "5/.config/$KWORKFLOW/$BUILD_CONFIG_FILENAME"
    "$PWD/$KW_DIR/$BUILD_CONFIG_FILENAME"
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
  build_config=()

  parse_configuration "$KW_BUILD_CONFIG_SAMPLE" build_config

  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' | tail -n +1 | head -2) # Remove statistics output
  declare -a expected_cmd=(
    'make -j ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- --silent olddefconfig'
    "make -j$PARALLEL_CORES ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- W=2"
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

  output=$(kernel_build 'TEST_MODE' --doc)
  expected_result="make -j$PARALLEL_CORES htmldocs"
  assertEquals "($LINENO)" "$expected_result" "$output"

  output=$(kernel_build 'TEST_MODE' --doc --ccache)
  expected_result="make CC=\"ccache gcc -fdiagnostics-color\" -j$PARALLEL_CORES htmldocs"
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

  cd "$original_dir" || {
    fail "($LINENO) It was not possible to move back to original directory"
    return
  }

  output=$(kernel_build 'TEST_MODE')
  ret="$?"
  assert_equals_helper 'We expected an error' "($LINENO)" "125" "$ret"

  configurations=()
  build_config=()
  cp "$KW_CONFIG_SAMPLE_X86" "$FAKE_KERNEL/kworkflow.config"
  cp "$KW_BUILD_CONFIG_SAMPLE_X86" "$FAKE_KERNEL/build.config"
  parse_configuration "$FAKE_KERNEL/kworkflow.config"
  parse_configuration "$FAKE_KERNEL/build.config" build_config

  cd "$FAKE_KERNEL" || {
    fail "($LINENO) It was not possible to move into temporary directory"
    return
  }

  output=$(kernel_build 'TEST_MODE' | tail -n +1 | head -2) # Remove statistics output
  declare -a expected_cmd=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make -j$PARALLEL_CORES ARCH=x86_64"
  )

  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
}

function test_parse_build_options()
{
  unset options_values
  declare -gA options_values
  local output
  local help_output

  # test default options
  parse_build_options
  assert_equals_helper 'Default ARCH did not match expectation' "($LINENO)" 'x86_64' "${options_values['ARCH']}"
  assert_equals_helper 'Default MENU_CONFIG did not match expectation' "($LINENO)" '' "${options_values['MENU_CONFIG']}"
  assert_equals_helper 'Default CROSS_COMPILE did not match expectation' "($LINENO)" '' "${options_values['CROSS_COMPILE']}"
  assert_equals_helper 'Default CPU_SCALING_FACTOR did not match expectation' "($LINENO)" '100' "${options_values['CPU_SCALING_FACTOR']}"
  assert_equals_helper 'Default CCACHE did not match expectation' "($LINENO)" '' "${options_values['CCACHE']}"
  assert_equals_helper 'Default INFO did not match expectation' "($LINENO)" '' "${options_values['INFO']}"
  assert_equals_helper 'Default DOC_TYPE did not match expectation' "($LINENO)" '' "${options_values['DOC_TYPE']}"

  # Warning options
  options_values=()
  parse_build_options --warnings
  assert_equals_helper 'Could not set build option WARNINGS' "($LINENO)" '1' "${options_values['WARNINGS']}"

  options_values=()
  parse_build_options -w
  assert_equals_helper 'Could not set build option WARNINGS' "($LINENO)" '1' "${options_values['WARNINGS']}"

  options_values=()
  parse_build_options --warnings 123
  assert_equals_helper 'Could not set build option WARNINGS' "($LINENO)" '123' "${options_values['WARNINGS']}"

  options_values=()
  parse_build_options -w 123
  assert_equals_helper 'Could not set build option WARNINGS' "($LINENO)" '123' "${options_values['WARNINGS']}"

  # test individual options
  help_output="$(build_help)"
  options_values=()
  output="$(parse_build_options -h)"
  assert_equals_helper 'Could not access build help' "($LINENO)" "$help_output" "$output"

  options_values=()
  parse_build_options --info
  assert_equals_helper 'Could not set build option INFO' "($LINENO)" '1' "${options_values['INFO']}"

  options_values=()
  parse_build_options -i
  assert_equals_helper 'Could not set build option INFO' "($LINENO)" '1' "${options_values['INFO']}"

  options_values=()
  parse_build_options --menu
  assert_equals_helper 'Could not set build option MENU_CONFIG' "($LINENO)" 'nconfig' "${options_values['MENU_CONFIG']}"

  options_values=()
  parse_build_options --doc
  assert_equals_helper 'Could not set build option DOC_TYPE' "($LINENO)" 'htmldocs' "${options_values['DOC_TYPE']}"

  options_values=()
  parse_build_options -d
  assert_equals_helper 'Could not set build option DOC_TYPE' "($LINENO)" 'htmldocs' "${options_values['DOC_TYPE']}"

  # CPU Scaling option
  options_values=()
  parse_build_options --cpu-scaling 150 > /dev/null
  assert_equals_helper 'Could not set build option CPU_SCALING_FACTOR' "($LINENO)" '150' "${options_values['CPU_SCALING_FACTOR']}"

  options_values=()
  parse_build_options -c 150 > /dev/null
  assert_equals_helper 'Could not set build option CPU_SCALING_FACTOR' "($LINENO)" '150' "${options_values['CPU_SCALING_FACTOR']}"

  options_values=()
  parse_build_options --ccache
  assert_equals_helper 'Could not set build option CCACHE' "($LINENO)" '1' "${options_values['CCACHE']}"

  output="$(parse_build_options --mispelled 2>&1)"
  assertEquals "($LINENO)" 22 "$?"
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
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"

  cp "$original_dir/tests/samples/.config" .config
  expected_cmd[3]="$modules"
  output=$(kernel_build 'TEST_MODE' '--info')
  compare_command_sequence '' "$LINENO" 'expected_cmd' "$output"
  rm .config
}

function test_kernel_cpu_scaling_2composed_build_options()
{
  local expected_result
  local output

  output=$(kernel_build 'TEST_MODE' --cpu-scaling 50 | tail -n +1 | head -2)
  declare -a expected_cmd=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make -j$SCALING ARCH=x86_64"
  )
  compare_command_sequence '' "($LINENO)" 'expected_cmd' "$output"

  output=$(kernel_build 'TEST_MODE' --cpu-scaling 50 --warnings 123 | tail -n +1 | head -2)
  declare -a expected_cmd=(
    'make -j ARCH=x86_64 --silent olddefconfig'
    "make -j$SCALING ARCH=x86_64 W=123"
  )
  compare_command_sequence '' "($LINENO)" 'expected_cmd' "$output"
}


invoke_shunit
