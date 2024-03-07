#!/bin/bash

include './src/lib/kwio.sh'
include './src/lib/kwlib.sh'
include './tests/unit/utils.sh'
include './tests/integration/utils.sh'

function oneTimeSetUp()
{
  local kw_repo_url='https://github.com/kworkflow/kworkflow'
  local ret
  declare -ar KW_BRANCHES=('master' 'unstable')
  declare -g HOST_TEMP_DIR
  declare -g HOST_KW_CLONED_PATH

  HOST_TEMP_DIR=$(mktemp --directory)
  HOST_KW_CLONED_PATH="${HOST_TEMP_DIR}/kworkflow"

  # Clone the repository once on the host
  git clone --quiet "$kw_repo_url" "$HOST_KW_CLONED_PATH"
  ret="$?"
  if [[ "$ret" -ne 0 ]]; then
    complain "Failed to clone ${kw_repo_url}"
    if [[ -n "$HOST_KW_CLONED_PATH" ]]; then
      if is_safe_path_to_remove "$HOST_TEMP_DIR"; then
        rm --recursive --force "$HOST_TEMP_DIR"
      else
        complain "Unsafe path: ${HOST_TEMP_DIR} - Not removing"
      fi
    fi
    exit "$ret"
  fi

  # The VERBOSE variable is set and exported in the run_tests.sh script based
  # on the command-line options provided by the user. It controls the verbosity
  # of the output during the test runs.
  setup_container_environment "$VERBOSE" 'self-update'
}

function oneTimeTearDown()
{
  # Check if the path is safe to remove
  if is_safe_path_to_remove "$HOST_TEMP_DIR"; then
    rm --recursive --force "$HOST_TEMP_DIR"
  fi
}

# Function to set up an outdated kworkflow environment in a container
#
# @container: The name of the container.
# @kw_cloned_container_path: Temporary directory inside the container where kworkflow is cloned.
# @kw_branch: The branch of kworkflow to be used.
# @commit_point: The specific commit to be checked out.
function setup_outdated_kworkflow_environment()
{
  local container="$1"
  local kw_cloned_container_path="$2"
  local kw_branch="$3"
  local commit_point="$4"
  local ret

  # Check if container and kw_cloned_container_path are non-empty
  if [[ -z "$container" ]]; then
    complain 'Container name is not provided'
    return 1
  fi

  if [[ -z "$kw_cloned_container_path" ]]; then
    complain 'kworkflow cloned directory path inside the container is not provided'
    return 1
  fi

  # Copy the repository into the container
  container_copy "$container" "$HOST_KW_CLONED_PATH" "$kw_cloned_container_path"
  ret="$?"
  if [[ "$ret" -ne 0 ]]; then
    complain "Failed to copy kworkflow to container $container"
    return "$ret"
  fi

  container_exec "$container" "git -C ${kw_cloned_container_path} checkout remotes/origin/${kw_branch}"
  ret="$?"
  if [[ "$ret" -ne 0 ]]; then
    complain 'Git checkout operation failed'
    complain "git -C ${kw_cloned_container_path} checkout remotes/origin/${kw_branch}"
    return "$ret"
  fi

  container_exec "$container" "git -C ${kw_cloned_container_path} checkout ${commit_point}"
  ret="$?"
  if [[ "$ret" -ne 0 ]]; then
    complain 'Git checkout to specific commit failed'
    complain "git -C ${kw_cloned_container_path} checkout ${commit_point}"
    return "$ret"
  fi

  container_exec "$container" "cd ${kw_cloned_container_path} && ./setup.sh --install --force --skip-checks > /dev/null 2>&1"
  ret="$?"
  if [[ "$ret" -ne 0 ]]; then
    complain 'kw setup failed'
    complain './setup.sh --install --force --skip-checks --skip-docs'
    return "$ret"
  fi
}

# This function gets the commit hash and base version of the specified
# branch, constructs the expected output, updates kworkflow based on
# the branch, and then checks the version.
#
# @container: The name of the container.
# @kw_cloned_container_path: Temporary directory inside the container where kworkflow is cloned
# @kw_branch: The branch of kworkflow to be used.
#
# Return:
# Return 0: On success. Prints a formatted string that includes the branch name,
# the commit hash of the branch, and the base version of the branch.
function generate_formatted_branch_info()
{
  local container="$1"
  local kw_cloned_container_path="$2"
  local kw_branch="$3"
  local head_commit_hash
  local base_version
  local ret

  head_commit_hash=$(container_exec "$container" "git -C ${kw_cloned_container_path} rev-parse --short origin/${kw_branch}")
  ret="$?"
  if [[ "$ret" -ne 0 ]]; then
    complain 'Git checkout to specific commit failed'
    complain "git -C ${kw_cloned_container_path} checkout ${commit_point}"
    return "$ret"
  fi

  base_version=$(container_exec "$container" "git -C ${kw_cloned_container_path} show remotes/origin/${kw_branch}:./src/VERSION | head --lines 1")
  ret="$?"
  if [[ "$ret" -ne 0 ]]; then
    complain 'Git checkout to specific commit failed'
    complain "git -C ${kw_cloned_container_path} checkout ${commit_point}"
    return "$ret"
  fi

  printf '%s\nBranch: %s\nCommit: %s\n' "$base_version" "$kw_branch" "$head_commit_hash"
}

# This function tests the self-update functionality of kworkflow for the master
# branch.
function test_self_update_from_master_branch()
{
  local kw_cloned_container_path
  local container
  local distro
  local expected_output
  local output

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"
    kw_cloned_container_path="$(generate_temporary_directory_in_container "$container")/kworkflow"

    container_copy "$container" "$HOST_KW_CLONED_PATH" "$kw_cloned_container_path"

    expected_output=$(generate_formatted_branch_info "$container" "$kw_cloned_container_path" 'master')

    # Specific update command for master branch
    container_exec "$container" 'yes | bash ./kw self-update > /dev/null'

    output=$(container_exec "$container" 'kw --version')
    assert_equals_helper "kw self-update master failed for ${distro}" "$LINENO" "$expected_output" "$output"
  done
}

# This function tests the self-update functionality of kworkflow for the
# unstable branch.
function test_self_update_from_unstable_branch()
{
  local kw_cloned_container_path
  local container
  local distro
  local expected_output
  local output

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"
    kw_cloned_container_path="$(generate_temporary_directory_in_container "$container")/kworkflow"

    container_copy "$container" "$HOST_KW_CLONED_PATH" "$kw_cloned_container_path"

    expected_output=$(generate_formatted_branch_info "$container" "$kw_cloned_container_path" 'unstable')

    # Specific update command for unstable branch
    container_exec "$container" "yes | bash ./kw self-update --unstable > /dev/null"

    output=$(container_exec "$container" 'kw --version')
    assert_equals_helper "kw self-update unstable failed for ${distro}" "$LINENO" "$expected_output" "$output"
  done
}

# This function tests the self-update functionality of kworkflow for
# the master branch with an old version of kworkflow.
function test_self_update_with_kw_old_version_of_master_branch()
{
  local kw_commit_point='HEAD~4'
  local kw_cloned_container_path
  local container
  local distro

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"
    kw_cloned_container_path="$(generate_temporary_directory_in_container "$container")/kworkflow"

    # Configuring the kworkflow to test an old version of the master branch
    setup_outdated_kworkflow_environment "$container" "$kw_cloned_container_path" 'master' "$kw_commit_point"

    expected_output=$(generate_formatted_branch_info "$container" "$kw_cloned_container_path" 'master')
    container_exec "$container" 'yes | bash ./kw self-update > /dev/null'

    output=$(container_exec "$container" 'kw --version')
    assert_equals_helper "kw self-update master failed for ${distro}" "$LINENO" "$expected_output" "$output"
  done
}

# This function tests the self-update functionality of kworkflow for
# the unstable branch with an old version of kworkflow.
function test_self_update_with_kw_old_version_of_unstable_branch()
{
  local kw_commit_point='HEAD~3'
  local kw_cloned_container_path
  local container
  local distro

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"
    kw_cloned_container_path="$(generate_temporary_directory_in_container "$container")/kworkflow"

    # Configuring the kworkflow to test an old version of the unstable branch
    setup_outdated_kworkflow_environment "$container" "$kw_cloned_container_path" 'unstable' "$kw_commit_point"

    expected_output=$(generate_formatted_branch_info "$container" "$kw_cloned_container_path" 'unstable')

    # Specific update command for master branch
    container_exec "$container" "yes | bash ./kw self-update --unstable > /dev/null"

    output=$(container_exec "$container" 'kw --version')
    assert_equals_helper "kw self-update unstable failed for ${distro}" "$LINENO" "$expected_output" "$output"
  done
}

invoke_shunit
