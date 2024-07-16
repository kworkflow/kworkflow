#!/usr/bin/env bash

include './src/lib/kwio.sh'
include './tests/unit/utils.sh'
include './tests/integration/utils.sh'

declare -g CLONED_KERNEL_TREE_PATH_HOST
declare -g TARGET_RANDOM_DISTRO
declare -g VM_NAME

function oneTimeSetUp()
{
  CLONED_KERNEL_TREE_PATH_HOST='/tmp/linux'

  # TODO: randomize distros, same logic as kw build integration tests
  VM_NAME='kw-debian'

  setup_vm_environment "$VM_NAME"

  vm_exec "$VM_NAME" "git clone --depth 1 https://github.com/torvalds/linux ${CLONED_KERNEL_TREE_PATH_HOST}"
  vm_exec "$VM_NAME" "git config --global --add safe.directory ${CLONED_KERNEL_TREE_PATH_HOST}"
}

function optimize_dot_config()
{
  # Generate a list of currently loaded modules in the container
  vm_exec "$VM_NAME" "cd ${CLONED_KERNEL_TREE_PATH_HOST} && /usr/bin/lsmod > vm_mod_list"
  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to generate module list in container."
  fi

  # Create a default configuration and then update it to reflect current settings
  vm_exec "$VM_NAME" "cd ${CLONED_KERNEL_TREE_PATH_HOST} && make defconfig > /dev/null 2>&1 && make olddefconfig > /dev/null 2>&1"
  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to create default configuration in container."
  fi

  # Optimize the configuration based on the currently loaded modules
  vm_exec "$VM_NAME" "cd ${CLONED_KERNEL_TREE_PATH_HOST} && make LSMOD=/tmp/linux/vm_mod_list localmodconfig > /dev/null 2>&1"
  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to optimize configuration based on loaded modules in container."
  fi
}

function test_kw_deploy()
{
  local deploy_output
  local not_expected_output='None of the installed kernels are managed by kw.'

  optimize_dot_config

  vm_exec "$VM_NAME" "cd ${CLONED_KERNEL_TREE_PATH_HOST} && kw build"
  vm_exec "$VM_NAME" "cd ${CLONED_KERNEL_TREE_PATH_HOST} && kw deploy --local"

  deploy_output=$(vm_exec "$VM_NAME" 'kw deploy --list --local' | head -n 2 | tail -n 1 | xargs)

  assertNotEquals "${LINENO}: 'kw deploy --local' failed" "$not_expected_output" "$deploy_output"
}

function oneTimeTearDown()
{
  teardown_single_vm "$VM"
}

invoke_shunit
