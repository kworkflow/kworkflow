#!/usr/bin/env bash

include './src/lib/kwio.sh'
include './tests/unit/utils.sh'
include './tests/integration/utils.sh'

function oneTimeSetUp() {
	# The VERBOSE variable is set and exported in the run_tests.sh script based
	# on the command-line options provided by the user. It controls the verbosity
	# of the output during the test runs.
	setup_container_environment "$VERBOSE" 'version'
}

# This function gets the commit hash and base version of the specified branch,
# constructs the expected output.
#
# @container: The name of the container.
#
# Return:
# Return 0: On success.
# Return 1: If it fails to get the branch name, head commit hash, or base version.
function kw_version_check_version() {
	local container="$1"
	local head_hash
	local branch_name
	local base_version
	local expected_output

	# In order to check correctness of `kw --version`, we collect some information
	# from the git repo:
	#
	# - Base version (alpha, beta, or other)
	# - Branch name
	# - Commit sha
	branch_name=$(container_exec "$container" "git rev-parse --short --abbrev-ref HEAD")
	if [[ "$?" -ne 0 ]]; then
		complain "Failed to get the branch name"
		return 1 # EPERM
	fi

	head_commit_hash=$(container_exec "$container" "git rev-parse --short ${branch_name}")
	if [[ "$?" -ne 0 ]]; then
		complain 'Failed to get the head commit hash'
		return 1 # EPERM
	fi

	base_version=$(container_exec "$container" "git show ${branch_name}:./src/VERSION | head --lines 1")
	if [[ "$?" -ne 0 ]]; then
		complain 'Failed to get the base version'
		return 1 # EPERM
	fi

	expected_output=$(printf '%s\nBranch: %s\nCommit: %s' "$base_version" "$branch_name" "$head_commit_hash")

	printf '%s\n' "$expected_output"
}

# Function to test the kw version feature across different distributions inside
# containers, using the three forms of the feature: kw version, kw --version,
# and kw -v.
function test_kw_version() {
	local container
	local distro
	local output
	local expected_output

	for distro in "${DISTROS[@]}"; do
		container="kw-${distro}"

		# collect the expected output in the container.
		expected_output=$(kw_version_check_version "$container")
		if [[ "$?" -ne 0 ]]; then
			fail "(${LINENO}): Couldn't collect expected version output from container ${container}"
		fi

		# collect the version in the container using `kw version`
		output=$(container_exec "$container" 'kw version')
		if [[ "$?" -ne 0 ]]; then
			fail "(${LINENO}): Failed to get 'kw version' for ${distro}"
		fi
		assert_equals_helper "'kw version' failed for ${distro}" "$LINENO" "$expected_output" "$output"

		# collect the version in the container using `kw --version`
		output=$(container_exec "$container" 'kw --version')
		if [[ "$?" -ne 0 ]]; then
			fail "(${LINENO}): Failed to get 'kw --version' for ${distro}"
		fi
		assert_equals_helper "'kw --version' failed for ${distro}" "$LINENO" "$expected_output" "$output"

		# collect the version in the container using `kw -v`
		output=$(container_exec "$container" 'kw -v')
		if [[ "$?" -ne 0 ]]; then
			fail "(${LINENO}): Failed to get 'kw -v' for ${distro}"
		fi
		assert_equals_helper "'kw -v' failed for ${distro}" "$LINENO" "$expected_output" "$output"
	done
}

invoke_shunit
