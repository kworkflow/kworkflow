#!/bin/bash

include './src/lib/kwio.sh'
include './tests/unit/utils.sh'
include './tests/integration/utils.sh'

declare -g expected_output

function oneTimeSetUp()
{
  local kw_git_dir
  local kw_dir
  local head_hash
  local branch_name
  local base_version

  # git directory path
  kw_dir="${KWROOT_DIR}"
  kw_git_dir="${kw_dir}/.git"

  # In order to check correctness of `kw --version`, we collect some information
  # from the git repo:
  #
  # - Base version (alpha, beta, or other)
  # - Branch name
  # - Commit sha
  #
  # Because the local KW repo is copied to the container, we run  the  following
  # commands directly on the host instead of running in the container.
  head_hash=$(git --git-dir "${kw_git_dir}" rev-parse --short HEAD)
  branch_name=$(git --git-dir "${kw_git_dir}" rev-parse --short --abbrev-ref HEAD)
  base_version=$(head --lines 1 "${kw_dir}/src/VERSION")

  # using the gathered information, we build the expected output
  expected_output=$(printf '%s\nBranch: %s\nCommit: %s' "$base_version" "$branch_name" "$head_hash")
}

function kw_version_test_helper()
{
  local distro="$1"
  local container
  local output

  # collect the kw version in the container
  container="kw-${distro}"
  output=$(container_exec "${container}" 'kw --version')

  assertEquals "(${LINENO}): kw version failed for ${distro}" "$expected_output" "$output"
}

function test_kw_version_on_archlinux()
{
  kw_version_test_helper 'archlinux'
}

function test_kw_version_on_debian()
{
  kw_version_test_helper 'debian'
}

function test_kw_version_on_fedora()
{
  kw_version_test_helper 'fedora'
}

invoke_shunit
