#!/usr/bin/env bash

include './tests/unit/utils.sh'
include './tests/integration/utils.sh'

function oneTimeSetUp()
{
  local distro

  # The VERBOSE variable is set and exported in the run_tests.sh script based
  # on the command-line options provided by the user. It controls the verbosity
  # of the output during the test runs.
  setup_container_environment "$VERBOSE" 'config'

  # copy config files to the containers
  for distro in "${DISTROS[@]}"; do
    container_copy "kw-${distro}" "${SAMPLES_DIR}/config" '/tmp/.kw'
  done
}

# The current workaround is this: we are using specially crafted config files
# that overwrite all global options in the same order displayed by kw.
function local_config_test_helper()
{
  local config="$1"
  local config_file
  local container
  local distro
  local expected_output

  # make sure config is defined
  if [[ -z "${config}" ]]; then
    fail "(${LINENO}): 'config' is not defined."
  fi

  # the path to the config file
  config_file="${SAMPLES_DIR}/config/${config}.config"

  # the expected output is the same for all distros
  expected_output=$(sort --dictionary-order "${config_file}")

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"

    # get the output inside the container
    output=$(container_exec "${container}" "kw config --show --local ${config}" '--workdir=/tmp')

    if [[ "$?" -ne 0 ]]; then
      fail "(${LINENO}) kw failed to show local variables in ${distro}"
    fi

    # remove prefix and N/A values from the output and sort them, before comparing
    output=$(grep --invert-match 'N/A' <<< "${output}" | sed "s/^${config}.//" | sort --dictionary-order)

    assertEquals "(${LINENO}): kw config failed for ${distro}" "${expected_output}" "${output}"
  done
}

function test_build_config()
{
  local_config_test_helper 'build'
}

function test_deploy_config()
{
  local_config_test_helper 'deploy'
}

function test_send_patch_config()
{
  local_config_test_helper 'send_patch'
}

function test_notification_config()
{
  local_config_test_helper 'notification'
}

function test_vm_config()
{
  local_config_test_helper 'vm'
}

invoke_shunit
