#!/bin/bash

include './src/lib/kwio.sh'
include './tests/unit/utils.sh'
include './tests/integration/utils.sh'

declare -g expected_output

function self_update_test_helper()
{
  local kw_branch="$1"
  local tmp_kw_dir
  local repo_url='https://github.com/kworkflow/kworkflow'
  local base_version
  local distro
  local container
  local output
  local expected_output
  local head_commit_hash

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"

    tmp_kw_dir=$(container_exec "$container" 'mktemp --directory')

    # Preparing the environment: Clone repository into a temporary directory inside the container
    container_exec "$container" "git clone ${repo_url} ${tmp_kw_dir}"

    # Get the short commit hash of the branch
    head_commit_hash=$(container_exec "$container" "git -C ${tmp_kw_dir} rev-parse --short origin/${kw_branch}")

    # Get the base version from the specified branch
    base_version=$(container_exec "$container" "git -C ${tmp_kw_dir} show remotes/origin/${kw_branch}:./src/VERSION | head --lines 1")

    # Format the expected output with branch, commit hash, and base version
    expected_output=$(printf '%s\nBranch: %s\nCommit: %s' "$base_version" "$kw_branch" "$head_commit_hash")

    case "$kw_branch" in
      'master')
        container_exec "$container" 'yes | kw self-update > /dev/null'
        ;;
      'unstable')
        container_exec "$container" 'yes | kw self-update --unstable > /dev/null'
        ;;
      *)
        complain "Unsupported update for branch '${kw_branch}'"
        ;;
    esac

    output=$(container_exec "$container" 'kw --version')

    assert_equals_helper "kw self-update failed for ${distro}" "$LINENO" "$expected_output" "$output"
  done
}

function test_self_update_master()
{
  self_update_test_helper 'master'
}

function test_self_update_unstable()
{
  self_update_test_helper 'unstable'
}

invoke_shunit
