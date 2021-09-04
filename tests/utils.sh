#!/bin/bash

TEST_DIR="tests"
SAMPLES_DIR="$TEST_DIR/samples"
EXTERNAL_DIR="$TEST_DIR/external"
TMP_TEST_DIR="$TEST_DIR/.tmp"
FAKE_DRM_SYSFS="$TMP_TEST_DIR/sys/class/drm"

# Samples
MAINTAINERS_SAMPLE="$SAMPLES_DIR/MAINTAINERS"
KW_CONFIG_SAMPLE="$SAMPLES_DIR/kworkflow.config"
KW_CONFIG_SAMPLE_X86="$SAMPLES_DIR/kworkflow_x86.config"

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
}

function mk_fake_sys_class_drm()
{
  declare -a fake_dirs=(
    "card0"
    "card0-DP-1"
    "card0-DP-2"
    "card0-DP-3"
    "card0-DVI-D-1"
    "card0-HDMI-A-1"
    "card1"
    "card1-DP-4"
    "card1-DP-5"
    "card1-DP-6"
    "card1-HDMI-A-2"
    "renderD128"
    "renderD129"
    "ttm")

  for dir in "${fake_dirs[@]}"; do
    mkdir -p "$FAKE_DRM_SYSFS/$dir"
  done

  touch "$FAKE_DRM_SYSFS/version"
  touch "$FAKE_DRM_SYSFS/card0-DP-3/modes"

  cat << END >> "$FAKE_DRM_SYSFS/card0-DP-3/modes"
1920x2160
2560x1440
1920x1080
1680x1050
1280x1024
1440x900
1280x960
1152x864
1280x720
1440x576
1024x768
1440x480
800x600
720x576
720x480
640x480
720x400
END

  cat << END >> "$FAKE_DRM_SYSFS/card1-HDMI-A-2/modes"
2560x1440
1920x1080
1280x1024
640x480
720x400
END

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

function mk_fake_remote_system()
{
  local prefix="$1"
  local target="$2"
  local kernelpath="$prefix/boot/vmlinuz-$target"
  local initrdpath="$prefix/boot/initrd.img-$target"
  local modulespath="$prefix/lib/modules/$target"
  local libpath="$prefix/var/lib/initramfs-tools/$target"
  local configpath="$prefix/boot/config-$target"

  mkdir -p "$modulespath"
  mkdir -p "$prefix/boot/"
  mkdir -p "$prefix/lib/modules/"
  mkdir -p "$prefix/var/lib/initramfs-tools/"

  touch "$kernelpath"
  touch "$kernelpath.old"
  touch "$initrdpath"
  touch "$libpath"
  touch "$configpath"
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
  local -r FAKE_BOOT_DIR="$1"

  mkdir -p "$FAKE_BOOT_DIR"
  cp -r "$SAMPLES_DIR/boot" "$FAKE_BOOT_DIR"
}

# This function expects an array of string with the command sequence and a
# string containing the output.
#
# @_expected Name of the array variable containing expected strings
# @result_to_compare A raw output from the string
# @ID An ID identification
function compare_command_sequence()
{
  # This variable name must be unique
  local -n _expected="$1"
  local result_to_compare="$2"
  local ID="$3"
  local count=0

  ID=${ID:-0}

  while read -r f; do
    if [[ "${_expected[$count]}" != "${f}" ]]; then
      fail "($ID) $count
Expected: \"${_expected[$count]}\"
but got:  \"${f}\"
"
    fi
    ((count++))
  done <<< "$result_to_compare"
}

function assert_equals_helper()
{
  local msg="$1"
  local line="$2"
  # See bugs section in github.com/koalaman/shellcheck/wiki/SC2178
  # shellcheck disable=SC2178
  local expected="$3"
  local target="$4"

  line=${line:-'Unknown line'}

  # See bugs section in github.com/koalaman/shellcheck/wiki/SC2178
  # shellcheck disable=2128
  assertEquals "line $line: $msg" "$target" "$expected"
}

# Create an invalid file path
function create_invalid_file_path()
{
  invalid_path="$RANDOM/$RANDOM/$RANDOM/xptolala"
  printf '%s\n' "$invalid_path"
}

function invoke_shunit()
{
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
