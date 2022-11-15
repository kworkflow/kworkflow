#!/bin/bash

REPO_ROOT_PATH="$PWD"
TEST_DIR="$PWD/tests"
SAMPLES_DIR="$TEST_DIR/samples"
EXTERNAL_DIR="$TEST_DIR/external"
TMP_TEST_DIR="$TEST_DIR/.tmp"

KW_REMOTE_SAMPLES_DIR="${SAMPLES_DIR}/remote_samples"

# Common samples
MAINTAINERS_SAMPLE="$SAMPLES_DIR/MAINTAINERS"
KW_CONFIG_SAMPLE="$SAMPLES_DIR/kworkflow.config"
KW_BUILD_CONFIG_SAMPLE="$SAMPLES_DIR/build.config"
KW_DEPLOY_CONFIG_SAMPLE="$SAMPLES_DIR/deploy.config"
KW_MAIL_CONFIG_SAMPLE="$SAMPLES_DIR/mail.config"
KW_NOTIFICATION_CONFIG_SAMPLE="$SAMPLES_DIR/notification.config"
KW_REMOTE_CONFIG_SAMPLE="${KW_REMOTE_SAMPLES_DIR}/remote.config"

KW_CONFIG_SAMPLE_X86="$SAMPLES_DIR/kworkflow_x86.config"
KW_BUILD_CONFIG_SAMPLE_X86="$SAMPLES_DIR/build_x86.config"

# Config file
STD_CONFIG_FILE="${SAMPLES_DIR}/.config"

# External files
CHECKPATH_EXT="$EXTERNAL_DIR/get_maintainer.pl"

# Constants
LOCAL_TO_DEPLOY_DIR="to_deploy"
LOCAL_REMOTE_DIR="remote"
KERNEL_INSTALL_PLUGIN_PATH="src/plugins/kernel_install/"

function init_env()
{
  unset -v KW_LIB_DIR KWORKFLOW
  KW_LIB_DIR="./src"
  KWORKFLOW=".kw"
  export KW_LIB_DIR KWORKFLOW
  export -f include
}

# Receives a string with one or more lines and print each of
# then prefixed by "> "
function prefix_multiline()
{
  printf '%s\n' "$@" | sed -E 's/^/> /g'
}

# Compare strings with multiple lines and prefix them with "> "
function multilineAssertEquals()
{
  local message
  local left
  local right

  if [ $# -ge 3 ]; then
    message="$1"
    shift
  fi

  left=$'\n'"$(printf '%s\n' "$1" | sed -E 's/^/> /g')"$'\n'
  right=$'\n'"$(printf '%s\n' "$2" | sed -E 's/^/> /g')"$'\n'

  if [ -n "$message" ]; then
    assertEquals "$message" "$left" "$right"
  else
    assertEquals "$left" "$right"
  fi
}

# Assert that two files are byte by byte the same
function assertFileEquals()
{
  local message
  local ret

  if [ $# -ge 3 ]; then
    message="$1"
    shift
  else
    message="Files $1 and $2 differ"
  fi

  cmp -s "$1" "$2"
  ret="$?"

  assertTrue "$message" "$ret"
}

# Receives a path and creates a fake kernel root in it. The goal is to make this
# path recognizable by src/kwlib.sh:is_kernel_root().
function mk_fake_kernel_root()
{
  local -r path="$1"
  mkdir -p "$path"
  touch "$path/COPYING"
  touch "$path/CREDITS"
  touch "$path/Kbuild"
  touch "$path/Makefile"
  touch "$path/README"
  touch "$path/MAINTAINERS"
  mkdir -p "$path/Documentation"
  mkdir -p "$path/arch"
  mkdir -p "$path/include"
  mkdir -p "$path/drivers"
  mkdir -p "$path/fs"
  mkdir -p "$path/init"
  mkdir -p "$path/ipc"
  mkdir -p "$path/kernel"
  mkdir -p "$path/lib"
  mkdir -p "$path/scripts"
  mkdir -p "$path/arch/x86_64/boot/"
  mkdir -p "$path/arch/arm64/boot/"
  touch "$path/arch/x86_64/boot/bzImage"
  touch "$path/arch/arm64/boot/Image"

  printf 'This is a bzImage fake\n' > "${path}/arch/x86_64/boot/bzImage"
  printf 'This is a Image fake\n' > "$path/arch/arm64/boot/Image"
}

function mk_fake_remote()
{
  local -r FAKE_KW="$1"
  local -r modules_path="$2"
  local -r modules_name="test"
  local -r kernel_install_path="kernel_install"

  mkdir -p "$FAKE_KW"/{$LOCAL_TO_DEPLOY_DIR,$LOCAL_REMOTE_DIR,$kernel_install_path}
  mkdir -p "$modules_path/$modules_name"

  touch "$modules_path/$modules_name"/file{1,2}
  touch "$FAKE_KW/$kernel_install_path"/{debian.sh,deploy.sh}
}

# Create a fake kw package.
#
# @FAKE_KW: Target path to create the kw package
# @output: Save kw package file to output
# @kernel_name: Kernel name. If not set, it is 'test'
# @kernel_binary_name: Kernel binary name. If not set, it is 'vmlinuz-test'
# @architecture: Target achitecture. If not set, it is 'x86_64'
function mk_fake_tar_file_to_deploy()
{
  local FAKE_KW="$1"
  local output="$2"
  local kernel_name="$3"
  local kernel_binary_name="$4"
  local architecture="$5"

  kernel_name=${kernel_name:-'test'}
  kernel_binary_name=${kernel_binary_name:-'vmlinuz-test'}
  architecture=${architecture:-'x86_64'}

  # Create kw_pkg dir
  mkdir -p "${FAKE_KW}/kw_pkg/"

  # Create fake files
  touch "${FAKE_KW}/kw_pkg/${kernel_binary_name}"
  touch "${FAKE_KW}/kw_pkg/${kernel_name}.config"
  touch "${FAKE_KW}/kw_pkg/kw.pkg.info"

  # Create modules
  mkdir -p "${FAKE_KW}/kw_pkg/modules/lib/modules/"
  touch "${FAKE_KW}/kw_pkg/modules/lib/modules/something_1"
  touch "${FAKE_KW}/kw_pkg/modules/lib/modules/something_2"

  # Compress everything
  cmd="tar --gzip --directory='$FAKE_KW' --create --file=${kernel_name}.kw.tar kw_pkg"
  eval "$cmd"

  # Move to output if requested
  if [[ -d "$output" ]]; then
    mv "${FAKE_KW}/${kernel_name}.kw.tar" "$output"
  elif [[ -n "$output" && ! -d "$output" ]]; then
    printf 'Invalid parameter: %s\n' "$output"
  fi

  # Clean temporary files
  rm -rf "${FAKE_KW}/kw_pkg/"
}

function mk_fake_remote_system()
{
  local prefix="$1"
  local target="$2"
  local kernelpath="$prefix/boot/vmlinuz-$target"
  local initrdpath="$prefix/boot/initrd.img-$target"
  local modulespath="$prefix/lib/modules/$target"
  local libpath="$prefix/var/lib/initramfs-tools/$target"
  local configpath="$prefix/boot/config-$target"
  local initramfspath="$prefix/boot/initramfs-$target.img"
  local initramfsfallbackpath="$prefix/boot/initramfs-$target-fallback.img"
  local mkinitcpiodpath="$prefix/etc/mkinitcpio.d/"
  local mkinitcpiofile="$mkinitcpiodpath/$target.preset"

  mkdir -p "$modulespath"
  mkdir -p "$prefix/boot/"
  mkdir -p "$prefix/lib/modules/"
  mkdir -p "$prefix/var/lib/initramfs-tools/"
  mkdir -p "$mkinitcpiodpath"

  touch "$kernelpath"
  touch "$kernelpath.old"
  touch "$initrdpath"
  touch "$libpath"
  touch "$configpath"
  touch "$initramfspath"
  touch "$initramfsfallbackpath"
  touch "$mkinitcpiofile"
}

function mock_target_machine()
{
  local -r FAKE_KW="$1"
  local -r kernel_install_path="kernel_install"
  local -r remote_kw_deploy="kw_deploy"

  mkdir -p "$FAKE_KW/$remote_kw_deploy"
  # Copy file
  cp "$KERNEL_INSTALL_PLUGIN_PATH/deploy.sh" "$FAKE_KW/$remote_kw_deploy/"
  cp "$KERNEL_INSTALL_PLUGIN_PATH/utils.sh" "$FAKE_KW/$remote_kw_deploy/"
  cp "$KERNEL_INSTALL_PLUGIN_PATH/debian.sh" "$FAKE_KW/$remote_kw_deploy/distro_deploy.sh"
}

function mk_fake_boot()
{
  local -r FAKE_BOOT_DIR=${1:-'./'}

  mkdir -p "$FAKE_BOOT_DIR"
  cp -r "$SAMPLES_DIR/boot" "$FAKE_BOOT_DIR"
}

# Creates a new git repository in the current path and configure it locally.
# Note: Git folder must be deleted afterward manually.
function mk_fake_git()
{
  local -r path="$PWD"

  git init -q "$path"

  touch "$path/first_file"
  printf 'This is the first file.\n' > "$path/first_file"

  git config --local user.name 'Xpto Lala'
  git config --local user.email 'test@email.com'
  git config --local test.config value

  git add first_file
  git commit -q -m 'Initial commit'

  printf 'Second change\n' >> "$path/first_file"
  git add --all
  git commit --allow-empty -q -m 'Second commit'

  printf 'Third change\n' >> "$path/first_file"
  git add --all
  git commit --allow-empty -q -m 'Third commit'
}

function mk_fake_kw_folder()
{
  local target_folder="$1"
  local kw_config_folder="${target_folder}/.kw"

  [[ -z "$target_folder" ]] && return 22

  mkdir -p "$kw_config_folder"
  # Copy sample files
  cp "$KW_CONFIG_SAMPLE" "$kw_config_folder"
  cp "$KW_BUILD_CONFIG_SAMPLE" "$kw_config_folder"
  cp "$KW_DEPLOY_CONFIG_SAMPLE" "$kw_config_folder"
  cp "$KW_MAIL_CONFIG_SAMPLE" "$kw_config_folder"
  cp "$KW_NOTIFICATION_CONFIG_SAMPLE" "$kw_config_folder"
  cp "$KW_REMOTE_CONFIG_SAMPLE" "$kw_config_folder"
}

function mk_fake_kw_env()
{
  local env_kw="${PWD}/.kw/fake_env"

  mkdir -p "$env_kw"
  printf '%s' 'fake_env' > "${PWD}/.kw/env.current"
}

# This function expects an array of string with the command sequence and a
# string containing the output.
#
# @msg Message to display in case of failure
# @line $LINENO variable
# @expected_res Name of the array variable containing expected strings
# @result_to_compare A raw output from the string
function compare_command_sequence()
{
  local msg="$1"
  local line="$2"
  # This variable name must be unique
  local -n expected_res="$3"
  local result_to_compare="$4"
  local count=0

  while read -r f; do
    if [[ "${expected_res[$count]}" != "${f}" ]]; then
      fail "line $line, statement $count: $msg
Expected: \"${expected_res[$count]}\"
but got:  \"${f}\"
"
    fi
    ((count++))
  done <<< "$result_to_compare"
}

# This function tries to match a substring (case insensitive).
#
# @msg Message to display in case of failure
# @line $LINENO variable
# @expected Expected value
# @result_to_compare Raw output to be compared
function assert_substring_match()
{
  local msg="$1"
  local line="$2"
  local expected="$3"
  local result_to_compare="$4"

  if ! grep -qi "$expected" <<< "$output"; then
    fail "line $line: $msg"
    return
  fi
}

# This function asserts an exact line match (case sensitive).
#
# @lineno $LINENO variable
# @expected_line Expected line
# @result_to_compare Raw output to be compared
function assert_line_match()
{
  local lineno="$1"
  local expected_line="$2"
  local result_to_compare="$3"

  if ! grep -qFx "$expected_line" <<< "$result_to_compare"; then
    fail "line ${lineno}: expected exact match of line '${expected_line}'"
    return
  fi
}

# This function asserts that an exact line is a no match (case sensitive).
# Its the inverse of assert_line_match() function.
#
# @lineno $LINENO variable
# @not_expected_line Not expected line
# @result_to_compare Raw output to be compared
function assert_no_line_match()
{
  local lineno="$1"
  local not_expected_line="$2"
  local result_to_compare="$3"

  if grep -qFx "$not_expected_line" <<< "$result_to_compare"; then
    fail "line ${lineno}: expected NO exact match of line '${not_expected_line}'"
    return
  fi
}

# This function expects an array of string with the command sequence and a
# string containing the output.
#
# @msg Message to display in case of failure
# @line $LINENO variable
# @expected Expected value
# @result_to_compare Raw output to be compared
function assert_equals_helper()
{
  local msg="$1"
  local line="$2"
  # See bugs section in github.com/koalaman/shellcheck/wiki/SC2178
  # shellcheck disable=SC2178
  local expected="$3"
  local result_to_compare="$4"

  line=${line:-'Unknown line'}

  # See bugs section in github.com/koalaman/shellcheck/wiki/SC2178
  # shellcheck disable=2128
  assertEquals "line $line: $msg" "$result_to_compare" "$expected"
}

# Create an invalid file path
function create_invalid_file_path()
{
  invalid_path="$RANDOM/$RANDOM/$RANDOM/xptolala"
  printf '%s\n' "$invalid_path"
}

function compare_array_values()
{
  #shellcheck disable=SC2178
  local -n expected="$1"
  local -n result_to_compare="$2"
  local line="$3"

  line=${line:-0}

  equal=$(printf '%s\n' "${expected[*]} ${result_to_compare[*]}" | tr ' ' '\n' | sort | uniq -u)
  if [[ -n "$equal" ]]; then
    assertNull "$line: Arrays are not equal" "$equal"
    printf '%s\n' 'Diff:' \
      '-----' \
      "$equal" \
      '-----'
  fi
}

function get_config_option_to_string()
{
  local config_path="$1"
  local output

  output=$(< "$config_path")
  output=$(printf '%s\n' "$output" | grep -oE '^(#?\w+=?)' | sed -E 's/[#=]//g')

  printf '%s' "$output"
}

function invoke_shunit()
{
  # Set some global variables to point to the source by default
  KW_LIB_DIR="$PWD/src"
  KW_PLUGINS_DIR="$PWD/src/plugins"

  command -v shunit2 > /dev/null
  if [[ "$?" -eq 0 ]]; then
    . shunit2
  elif [[ -d ./tests/shunit2 ]]; then
    . ./tests/shunit2/shunit2
  else
    printf '%s\n' 'Cannot find shunit2.' \
      'Do you have it installed (or downloaded it to ./tests/shunit2)?'
    return 1
  fi
}
