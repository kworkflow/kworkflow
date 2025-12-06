#!/usr/bin/env bash

include './src/lib/distros.sh'
include './tests/unit/utils.sh'

function test_install_package_empty_list()
{
  local output
  local package_list=('')
  local expected_output='sudo yes | pacman -Syu inxi'

  output=$(install_package 'TEST_MODE' package_list '' '' '' 2)
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$?"

  package_list=(' ')
  output=$(install_package 'TEST_MODE' package_list '' '' '' 2)
  assert_equals_helper 'Expected an error' "$LINENO" 22 "$?"
}

function test_install_package_local_single_package_arch()
{
  local output
  local package_list=('inxi')
  local expected_output='sudo yes | pacman -Syu inxi'

  output="$(
    function detect_distro()
    {
      printf '%s' 'arch'
    }

    install_package 'TEST_MODE' package_list '' '' '' 2
  )"

  assertEquals "(${LINENO}): " "$expected_output" "$output"
}

function test_install_package_local_single_package_debian()
{
  local output
  local package_list=('inxi')
  local expected_output='sudo apt install --yes inxi'

  output="$(
    function detect_distro()
    {
      printf '%s' 'debian'
    }

    install_package 'TEST_MODE' package_list '' '' '' 2
  )"

  assertEquals "(${LINENO}): " "$expected_output" "$output"
}

function test_install_package_local_single_package_debian()
{
  local output
  local package_list=('inxi')
  local expected_output='sudo dnf install --assumeyes inxi'

  output="$(
    function detect_distro()
    {
      printf '%s' 'fedora'
    }

    install_package 'TEST_MODE' package_list '' '' '' 2
  )"

  assertEquals "(${LINENO}): " "$expected_output" "$output"
}

function test_install_package_local_multiple_package_arch()
{
  local output
  local package_list=('inxi' 'vim' 'git')
  local expected_output='sudo yes | pacman -Syu inxi vim git'

  output="$(
    function detect_distro()
    {
      printf '%s' 'arch'
    }

    install_package 'TEST_MODE' package_list '' '' '' 2
  )"

  assertEquals "(${LINENO}): " "$expected_output" "$output"
}

function test_install_package_remote_single_package_arch()
{
  local output
  local package_list=('inxi' 'vim' 'git')
  local expected_output='ssh -p 22 root@TM "yes | pacman -Syu inxi vim git"'

  output="$(
    function which_distro()
    {
      printf '%s' 'arch'
    }

    install_package 'TEST_MODE' package_list 'TM' '22' 'root' 3
  )"

  assertEquals "(${LINENO}): " "$expected_output" "$output"
}

function test_detect_distro_root_path_only()
{
  local root_path
  local output

  root_path="${SAMPLES_DIR}/os/arch"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  root_path="${SAMPLES_DIR}/os/manjaro"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  root_path="${SAMPLES_DIR}/os/ubuntu"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'debian' "$output"

  root_path="${SAMPLES_DIR}/os/debian"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'debian' "$output"

  root_path="${SAMPLES_DIR}/os/raspbian"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'debian' "$output"

  root_path="${SAMPLES_DIR}/os/fedora"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'fedora' "$output"

  root_path="${SAMPLES_DIR}/os/arch-linux-arm"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  root_path="${SAMPLES_DIR}/os/endeavouros"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  root_path="${SAMPLES_DIR}/os/steamos"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  root_path="${SAMPLES_DIR}/os/popos"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'debian' "$output"

  root_path="${SAMPLES_DIR}/os/none"
  output=$(detect_distro "$root_path")
  assert_equals_helper '' "$LINENO" 'none' "$output"
}

function test_detect_distro_str_check()
{
  local root_path
  local output

  output=$(detect_distro '/' 'arch')
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  output=$(detect_distro '' 'debian')
  assert_equals_helper '' "$LINENO" 'debian' "$output"

  output=$(detect_distro '' 'fedora')
  assert_equals_helper '' "$LINENO" 'fedora' "$output"

  output=$(detect_distro '' 'ubuntu')
  assert_equals_helper '' "$LINENO" 'none' "$output"

  output=$(detect_distro '' 'ubuntu debian')
  assert_equals_helper '' "$LINENO" 'debian' "$output"

  output=$(detect_distro '' 'manjaro steamos lala arch')
  assert_equals_helper '' "$LINENO" 'arch' "$output"
}

function test_detect_distro_from_raw_data()
{
  local root_path_string
  local os_release_data
  local output

  root_path="${SAMPLES_DIR}/os/arch/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  root_path="${SAMPLES_DIR}/os/manjaro/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  root_path="${SAMPLES_DIR}/os/ubuntu/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'debian' "$output"

  root_path="${SAMPLES_DIR}/os/debian/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'debian' "$output"

  root_path="${SAMPLES_DIR}/os/raspbian/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'debian' "$output"

  root_path="${SAMPLES_DIR}/os/fedora/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'fedora' "$output"

  root_path="${SAMPLES_DIR}/os/arch-linux-arm/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  root_path="${SAMPLES_DIR}/os/endeavouros/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  root_path="${SAMPLES_DIR}/os/steamos/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'arch' "$output"

  root_path="${SAMPLES_DIR}/os/popos/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'debian' "$output"

  root_path="${SAMPLES_DIR}/os/none/etc/os-release"
  os_release_data=$(< "$root_path")
  output=$(detect_distro '' '' "$os_release_data")
  assert_equals_helper '' "$LINENO" 'none' "$output"
}

function test_which_distro()
{
  local cmd='cat /etc/os-release'
  local remote='172.16.224.1'
  local user='xpto'
  local port='2222'
  local flag='TEST_MODE'
  local expected_str

  remote_parameters['REMOTE_IP']='127.0.0.1'
  remote_parameters['REMOTE_PORT']='3333'
  remote_parameters['REMOTE_USER']='juca'

  output=$(which_distro "$remote" "$port" "$user" "$flag")
  expected_str="ssh -p ${port} ${user}@${remote} sudo \"${cmd}\""
  assertEquals "($LINENO):" "$expected_str" "$output"

  user='juca'
  output=$(which_distro "$remote" "$port" '' "$flag")
  expected_str="ssh -p ${port} ${user}@${remote} sudo \"${cmd}\""
  assertEquals "(${LINENO})" "$expected_str" "$output"

  port=3333
  output=$(which_distro "${remote}" '' '' "${flag}")
  expected_str="ssh -p ${port} ${user}@${remote} sudo \"${cmd}\""
  assertEquals "(${LINENO})" "${expected_str}" "${output}"

  remote='127.0.0.1'
  output=$(which_distro '' '' '' "$flag")
  expected_str="ssh -p ${port} ${user}@${remote} sudo \"${cmd}\""
  assert_equals_helper 'Command did not match' "${LINENO}" "$expected_str" "$output"
}

invoke_shunit
