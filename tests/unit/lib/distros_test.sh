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

invoke_shunit
