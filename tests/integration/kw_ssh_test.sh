#!/usr/bin/env bash

include './src/lib/kwio.sh'
include './tests/unit/utils.sh'
include './tests/integration/utils.sh'

declare -g SSH_CONTAINER_NAME='ssh-server-container'
declare -g KW_GLOBAL_CONFIG_FILE='/root/.config/kw/remote.config'

# This function calls setup_nested_ssh_server to configure the SSH server
# inside the container of each distribution in the DISTROS array.
#
# Returns:
# return 0: If all SSH servers are configured successfully.
# return 1: If the SSH server configuration fails for any distribution.
function oneTimeSetUp()
{
  local distro
  local container

  setup_container_environment "$VERBOSE" 'ssh'

  for distro in "${DISTROS[@]}"; do
    setup_nested_ssh_server "$distro"
    if [[ "$?" -ne 0 ]]; then
      complain "Failed to configure ssh server for ${distro}. Exiting setup."
      return 1
    fi
  done
}

# This function sets up an SSH server environment inside a specified container
# for testing purposes.
#
# @distro: The distribution name for which the SSH server is being configured.
#
# Returns:
# return 0: If the SSH server is set up successfully.
# return 1: If an unsupported OS type is specified or if any command fails
#           during the setup.
function setup_nested_ssh_server()
{
  local distro="$1"
  local container="kw-${distro}"
  local containerfile_ssh="${SAMPLES_DIR}/Containerfile_ssh"
  local podman_tmp_utils="${CONTAINER_DIR}/test_resources/kw-ssh-tests"
  local container_workdir='/root'
  local package_install_command

  case "$distro" in
    debian)
      package_install_command='apt update --yes --quiet=3 && apt install --yes'
      ;;
    archlinux)
      package_install_command='pacman -Syu --noconfirm'
      # Install specific dependencies in archlinux to run these tests
      package_install_command+=' openssh aardvark-dns'
      ;;
    fedora)
      package_install_command='dnf makecache --quiet && dnf install --assumeyes'
      # Install specific dependencies in fedora to run these tests
      package_install_command+=' fuse-overlayfs'
      ;;
    *)
      complain "Unsupported OS type: ${distro}"
      return 1
      ;;
  esac

  # Install dependencies to run podman inside the main container
  container_exec "$container" "${package_install_command} podman > /dev/null 2>&1"
  # Copy the Containerfile_ssh to the container's workdir directory
  container_copy "$container" "$containerfile_ssh" "$container_workdir"
  # Copy the kw-ssh-tests directory to the container's workdir directory
  container_copy "$container" "$podman_tmp_utils" "$container_workdir"
  # Execute the kw_setup_ssh_env script located in /bin within the specified container
  # This script creates an SSH server inside a container to test the kw ssh feature.
  container_exec "$container" 'kw_setup_ssh_env > /dev/null 2>&1'
}

# This function tests the 'kw ssh' connection functionality. It verifies that a
# connection can be established from a local container to an SSH server
# container.
function test_kw_ssh_connection()
{
  local ssh_user='root'
  local expected_output='Connection successful'
  local ssh_port=22
  local ssh_container_ip_address
  local distro
  local container
  local output

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"
    # Get the IP address of the SSH server container
    ssh_container_ip_address=$(container_exec "$container" "podman inspect --format '{{.NetworkSettings.IPAddress}}' ${SSH_CONTAINER_NAME}")

    output=$(container_exec "$container" "kw ssh --remote ${ssh_user}@${ssh_container_ip_address}:${ssh_port} --command 'echo Connection successful'")
    assert_equals_helper "kw ssh connection failed for ${distro}" "$LINENO" "$expected_output" "$output"
  done
}

# This function tests the SSH connection functionality using a remote global
# configuration file. It ensures that the 'kw ssh' command can establish a
# connection to an SSH server and execute a command.
function test_kw_ssh_connection_remote_global_config_file()
{
  local expected_output='Connection successful'
  local ssh_container_ip_address
  local distro
  local container
  local output

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"
    # Get the IP address of the ssh container
    ssh_container_ip_address=$(container_exec_in_nested_container "$container" "$SSH_CONTAINER_NAME" 'hostname --all-ip-addresses' | xargs)

    # Update the global config file with the correct IP address of the SSH server
    container_exec "$container" "sed --in-place \"s/localhost/${ssh_container_ip_address}/\" ${KW_GLOBAL_CONFIG_FILE}"
    output=$(container_exec "$container" 'kw ssh --command "echo Connection successful"')
    assert_equals_helper "kw ssh connection failed for ${distro}" "$LINENO" "$expected_output" "$output"
  done
}

# This function tests the 'kw ssh --send' functionality It verifies that a file
# can be sent from a local container to an SSH server container.
function test_kw_ssh_send_to_path()
{
  local test_file='file.data'
  local distro
  local container
  local output
  local expected_output
  local container_test_filepath
  local ssh_server_container_test_filepath
  local container_tmp_dir

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"

    ssh_container_ip_address=$(container_exec_in_nested_container "$container" "$SSH_CONTAINER_NAME" 'hostname --all-ip-addresses' | xargs)
    # Update the global config file with the correct IP address of the SSH server
    container_exec "$container" "sed --in-place \"s/localhost/${ssh_container_ip_address}/\" ${KW_GLOBAL_CONFIG_FILE}"

    # Create temporary directories for the test in both the local and SSH server containers
    container_tmp_dir=$(container_exec "$container" 'mktemp --directory')
    ssh_server_container_tmp_dir=$(container_exec_in_nested_container "$container" "$SSH_CONTAINER_NAME" 'mktemp --directory')

    # Define the full path of the test file on the local container
    container_test_filepath="${container_tmp_dir}/${test_file}"

    container_exec "$container" "touch ${container_test_filepath}"
    container_exec "$container" "kw ssh --send ${container_test_filepath} --to ${ssh_server_container_tmp_dir} > /dev/null"

    # Define the file path on the SSH server
    ssh_server_container_test_filepath="${ssh_server_container_tmp_dir}/${test_file}"

    # Check if the file exists on the SSH server by listing its path
    output=$(container_exec_in_nested_container "$container" "$SSH_CONTAINER_NAME" "ls ${ssh_server_container_test_filepath}")
    expected_output="$ssh_server_container_test_filepath"
    assert_equals_helper "kw ssh --send ${test_file} connection failed for ${distro}" "$LINENO" "$expected_output" "$output"
  done
}

# This function tests the 'kw ssh --get' functionality It verifies that a file
# can be sent from a local container to an SSH server container.
function test_kw_ssh_get_to_path()
{
  local test_dir_name='dir_testing'
  local test_file_name='a.data'
  local ssh_server_container_tmp_dir
  local ssh_server_container_test_filepath
  local container_tmp_dir
  local distro
  local container
  local expected_output
  local output

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"

    ssh_container_ip_address=$(container_exec_in_nested_container "$container" "$SSH_CONTAINER_NAME" 'hostname --all-ip-addresses' | xargs)

    # Update the global remote.config file with the correct IP address of the SSH server
    container_exec "$container" "sed --in-place \"s/localhost/${ssh_container_ip_address}/\" ${KW_GLOBAL_CONFIG_FILE}"

    container_tmp_dir=$(container_exec "$container" 'mktemp --directory')
    ssh_server_container_tmp_dir=$(container_exec_in_nested_container "$container" "$SSH_CONTAINER_NAME" 'mktemp --directory')

    ssh_server_container_test_filepath="${ssh_server_container_tmp_dir}/${test_dir_name}/${test_file_name}"

    container_exec_in_nested_container "$container" "$SSH_CONTAINER_NAME" "mkdir --parents ${ssh_server_container_tmp_dir}/${test_dir_name}"
    container_exec_in_nested_container "$container" "$SSH_CONTAINER_NAME" "touch ${ssh_server_container_test_filepath}"

    # Retrieve the file from the SSH server to the local container
    container_exec "$container" "kw ssh --get ${ssh_server_container_tmp_dir}/${test_dir_name} --to ${container_tmp_dir} > /dev/null"

    # Check if the file exists in the local container by listing its path
    output=$(container_exec "$container" "ls ${container_tmp_dir}/${test_dir_name}/${test_file_name}")

    # Set the expected output to the path of the file on the local container
    expected_output="${container_tmp_dir}/${test_dir_name}/${test_file_name}"
    assert_equals_helper "kw ssh --get ${ssh_server_container_test_filepath} retrieval failed for ${distro}" "$LINENO" "$expected_output" "$output"
  done
}

function tearDown()
{
  local distro
  local container

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"
    # Replace any IP address in the format xxx.xxx.xxx.xxx with localhost
    container_exec "$container" "sed --in-place 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/localhost/' ${KW_GLOBAL_CONFIG_FILE}"
  done
}

invoke_shunit
