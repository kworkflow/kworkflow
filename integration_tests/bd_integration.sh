#!/bin/bash
#
# This file is a parametrized integration test template for the deploy feature of kw.
#
# @distro - Distro to be used in this test, this variable will define th vm and config files to be used
# @kernel_dir - Kernel directory to be used in the test and installed in the vm

include './utils.sh'
include '../src/kwio.sh'

original="$PWD"
distro="$1"
target_vm="$distro""_kw_test_vm"
kernel_dir="$2"

function oneTimeSetUp()
{
  say 'Mounting virtual machine with Vagrant'
  vagrant up "$target_vm"
  vagrant ssh-config "$target_vm" > "./$kernel_dir/vagrant_ssh"

  make -C "./$kernel_dir" distclean
  cp "./distro_configs/$distro""_config" "./$kernel_dir/.config"
  make -C "./$kernel_dir" olddefconfig

  cp "./distro_configs/$distro""_kworkflow.config" "./$kernel_dir/kworkflow.config"
}

function setUp()
{
  cd "./$kernel_dir" || {
    fail "($LINENO) It was not possible to move to the linux kernel directory"
    return
  }
}

function test_debian_deploy_list()
{
  local kernel_name
  local kernels_installed

  kernel_name=$(ssh -F vagrant_ssh "$target_vm" uname -r)
  kernels_installed=$(../../kw d --list)

  assertContains "Distro: $distro, integration test for kw deploy --list option failed." "$kernels_installed" "$kernel_name"
}

function test_debian_bd()
{
  local kernel_to_be_installed
  local kernels_installed

  kernel_to_be_installed=$(make kernelversion)
  kernels_installed=$(../../kw d --list)
  assertNotContains "Distro: $distro, integration test for kw bd failed, kernel to be installed is already installed." "$kernels_installed" "$kernel_to_be_installed"

  ../../kw bd
  kernels_installed=$(../../kw d --list)
  assertContains "Distro: $distro, integration test for kw bd failed." "$kernels_installed" "$kernel_to_be_installed"
}

function test_debian_uninstall()
{
  local kernel_to_be_uninstalled
  local kernels_installed

  kernel_to_be_uninstalled=$(make kernelversion)
  kernel_to_be_uninstalled="$kernel_to_be_uninstalled""-KW-TEST+"
  kernels_installed=$(../../kw d --list)
  assertContains "Distro: $distro, integration test for kw d --uninstall failed, kernel to be uninstalled canot be found." "$kernels_installed" "$kernel_to_be_uninstalled"

  ../../kw d --uninstall "$kernel_to_be_uninstalled"
  kernels_installed=$(../../kw d --list)
  assertNotContains "Distro: $distro, integration test for kw d --uninstall failed." "$kernels_installed" "$kernel_to_be_uninstalled"
}

function tearDown()
{
  cd "$original" || {
    fail "($LINENO) It was not possible to move back from the linux kernel directory"
    return
  }
}

function oneTimeTearDown()
{
  vagrant halt "$target_vm"
  rm -rf "./$kernel_dir/.vagrant" "./$kernel_dir/vagrant_ssh" "./$kernel_dir/kworkflow.config"
}

invoke_shunit
