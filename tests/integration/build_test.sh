#!/usr/bin/env bash

include './src/lib/kwio.sh'
include './src/lib/kwlib.sh'
include './tests/unit/utils.sh'
include './tests/integration/utils.sh'

declare -g CLONED_KERNEL_TREE_PATH_HOST
declare -g TARGET_RANDOM_DISTRO
declare -g KERNEL_TREE_PATH_CONTAINER
declare -g CONTAINER

function oneTimeSetUp()
{
  local url_kernel_repo_tree='https://github.com/torvalds/linux'

  # Select a random distro for the tests
  TARGET_RANDOM_DISTRO=$(select_random_distro)
  CLONED_KERNEL_TREE_PATH_HOST="$(mktemp --directory)/linux"
  CONTAINER="kw-${TARGET_RANDOM_DISTRO}"

  # The VERBOSE variable is set and exported in the run_tests.sh script based
  # on the command-line options provided by the user. It controls the verbosity
  # of the output during the test runs.
  setup_container_environment "$VERBOSE" 'build' "$TARGET_RANDOM_DISTRO"

  # Install kernel build dependencies
  container_exec "$CONTAINER" 'yes | ./setup.sh --install-kernel-dev-deps > /dev/null 2>&1'
  if [[ "$?" -ne 0 ]]; then
    complain "Failed to install kernel build dependencies for ${TARGET_RANDOM_DISTRO}"
    return 22 # EINVAL
  fi

  git clone --quiet --depth 5 "$url_kernel_repo_tree" "$CLONED_KERNEL_TREE_PATH_HOST"
  if [[ "$?" -ne 0 ]]; then
    complain "Failed to clone ${url_kernel_repo_tree}"
    if [[ -n "$CLONED_KERNEL_TREE_PATH_HOST" ]]; then
      if is_safe_path_to_remove "$CLONED_KERNEL_TREE_PATH_HOST"; then
        rm --recursive --force "$CLONED_KERNEL_TREE_PATH_HOST"
      else
        complain "Unsafe path: ${CLONED_KERNEL_TREE_PATH_HOST} - Not removing"
      fi
    fi
  fi
}

function setUp()
{
  KERNEL_TREE_PATH_CONTAINER="$(container_exec "$CONTAINER" 'mktemp --directory')/linux"
  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to create temporary directory in container."
  fi

  setup_kernel_tree_with_config_file "$CONTAINER"
}

function tearDown()
{
  container_exec "$CONTAINER" "cd ${KERNEL_TREE_PATH_CONTAINER} && kw build --full-cleanup > /dev/null 2>&1"
  assert_equals_helper "kw build --clean failed for ${CONTAINER}" "(${LINENO})" 0 "$?"
}

# shellcheck disable=SC2317
function oneTimeTearDown()
{
  if [[ -n "$CLONED_KERNEL_TREE_PATH_HOST" ]]; then
    if is_safe_path_to_remove "$CLONED_KERNEL_TREE_PATH_HOST"; then
      rm --recursive --force "$CLONED_KERNEL_TREE_PATH_HOST"
    fi
  fi
}

# Prepares the kernel tree inside the container by copying the pre-cloned
# kernel repository .
function setup_kernel_tree_with_config_file()
{
  container_copy "$CONTAINER" "$CLONED_KERNEL_TREE_PATH_HOST" "$KERNEL_TREE_PATH_CONTAINER"
  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to copy ${CLONED_KERNEL_TREE_PATH_HOST} to ${CONTAINER}:${KERNEL_TREE_PATH_CONTAINER}"
  fi

  optimize_dot_config "$CONTAINER" "$KERNEL_TREE_PATH_CONTAINER"
}

# Optimize the .config file in a container.
#
# @CONTAINER                   The ID or name of the container.
# @KERNEL_TREE_PATH_CONTAINER  The temporary directory in the container to use for intermediate files.
function optimize_dot_config()
{
  # Generate a list of currently loaded modules in the container
  container_exec "$CONTAINER" "cd ${KERNEL_TREE_PATH_CONTAINER} && /usr/sbin/lsmod > container_mod_list"
  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Unable to retrieve the list of loaded modules inside the container."
  fi

  # Create a default configuration and then update it to reflect current settings
  container_exec "$CONTAINER" "cd ${KERNEL_TREE_PATH_CONTAINER} && make defconfig > /dev/null 2>&1 && make olddefconfig > /dev/null 2>&1"
  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to generate and update the default kernel configuration inside the container."
  fi

  # Optimize the configuration based on the currently loaded modules
  container_exec "$CONTAINER" "cd ${KERNEL_TREE_PATH_CONTAINER} && make LSMOD=${KERNEL_TREE_PATH_CONTAINER}/container_mod_list localmodconfig > /dev/null 2>&1"
  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Configuration optimization failed. Could not adjust kernel settings based on the loaded modules inside the container"
  fi
}

# Verify that the kernel binary and modules were successfully generated, and
# validate the build result stored in the database.
#
# @caller_lineno  The line number where the function is called (for debugging).
function validate_kernel_build_artifacts()
{
  local caller_lineno="$1"
  local raw_build_log_from_db
  local build_type_string_from_db
  local build_result_status_from_db

  # Verify kernel binary exists
  kernel_binary_path=$(container_exec "$CONTAINER" "find ${KERNEL_TREE_PATH_CONTAINER}/arch/x86/boot/ -type f -name 'bzImage'")
  if [[ -z "$kernel_binary_path" ]]; then
    assert_equals_helper "Kernel binary not found in ${KERNEL_TREE_PATH_CONTAINER}/arch/x86/boot/ for ${CONTAINER}" "$caller_lineno" '0' '1'
  fi

  # Retrieve the build status log from the database
  raw_build_log_from_db=$(container_exec "$CONTAINER" "sqlite3 ~/.local/share/kw/kw.db \"SELECT * FROM statistics_report ORDER BY id DESC LIMIT 1\"")

  # Extract the build status and result from the log
  build_type_string_from_db=$(printf '%s' "$raw_build_log_from_db" | cut --delimiter='|' --fields=2)
  assert_equals_helper "Build status from database failed for ${CONTAINER}" "$caller_lineno" 'build' "$build_type_string_from_db"

  build_result_status_from_db=$(printf '%s' "$raw_build_log_from_db" | cut --delimiter='|' --fields=3)
  assert_equals_helper "Build result from database failed for ${CONTAINER}" "$caller_lineno" 'success' "$build_result_status_from_db"
}

function test_kernel_build_gcc_x86_64_no_env()
{
  container_exec "$CONTAINER" "cd ${KERNEL_TREE_PATH_CONTAINER} && kw build > /dev/null 2>&1"
  assert_equals_helper "kw build failed for ${CONTAINER}" "(${LINENO})" 0 "$?"

  validate_kernel_build_artifacts "$LINENO"
}

function test_kw_build_cpu_scaling_execution()
{
  local cpu_scaling_test_exit_code

  # Execute the test script `kw_build_cpu_scaling_monitor` inside the
  # container. The test script will run the `kw build` command with the
  # `--cpu-scaling 50` option
  cpu_scaling_test_exit_code=$(container_exec "$CONTAINER" "cd ${KERNEL_TREE_PATH_CONTAINER} && kw_build_cpu_scaling_monitor 50 > /dev/null 2>&1; echo \$?")
  assert_equals_helper "kw build --cpu-scaling 50 failed for ${CONTAINER}" "(${LINENO})" 0 "$cpu_scaling_test_exit_code"

  # For more details about this test, check the file:
  # tests/integration/podman/scripts/kw_build_cpu_scaling_monitor
}

function test_kernel_build_llvm()
{
  container_exec "$CONTAINER" "cd ${KERNEL_TREE_PATH_CONTAINER} && kw build --llvm > /dev/null 2>&1"
  assert_equals_helper "kw build failed for ${CONTAINER}" "(${LINENO})" 0 "$?"

  validate_kernel_build_artifacts "$LINENO"
}

invoke_shunit
