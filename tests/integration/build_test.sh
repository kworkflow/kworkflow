#!/bin/bash

include './src/lib/kwio.sh'
include './tests/unit/utils.sh'
include './tests/integration/utils.sh'

declare -g expected_output

# This function installs the kernel build dependencies inside a container.
# It supports three Linux distributions: Debian, Arch Linux, and Fedora.
#
# @container: The name of the container where the dependencies will be installed.
# @distro: The name of the Linux distribution running in the container.
#
# Return:
#   Returs 0 if the dependencies were successfully installed,
function install_kworkflow_build_dependencies()
{
  local container="$1"
  local distro="$2"
  local package_install_command
  local kernel_build_dependencies="${script_dir}/samples/kernel_build_dependencies_${distro}"
  local dependency_packages

  dependency_packages=$(tr '\n' ' ' < "$kernel_build_dependencies")

  case "$distro" in
    debian)
      package_install_command="apt update && apt install -y"
      ;;
    archlinux)
      package_install_command="pacman -Syu --noconfirm"
      ;;
    fedora)
      package_install_command="dnf makecache && dnf install -y"
      ;;
    *)
      complain "Unsupported OS type: $distro"
      return 1
      ;;
  esac

  container_exec "$container" "${package_install_command} ${dependency_packages}"

  if [ "$?" -ne 0 ]; then
    complain "Failed to install kw build packages dependencies: ${dependency_packages}"
    return 1
  fi
}

# This function clones the Linux kernel repository into a temporary directory
# inside a specified container. It uses a shallow clone with depth 1 to minimize
# the amount of data being transferred.
#
# @container: The name of the container where the repository will be cloned.
# @kw_tmp_dir: The path to the temporary directory inside the container where
# the repository will be cloned.
#
# Return:
#   Returs 0 if the repository was successfully cloned, 1 otherwise.
function clone_kernel_tree_repo()
{
  local container="$1"
  local kw_tmp_dir="$2"
  local kernel_repo_tree='https://github.com/torvalds/linux'

  container_exec "$container" "git clone --depth 1 ${kernel_repo_tree} ${kw_tmp_dir}"

  if [ "$?" -ne 0 ]; then
    complain "Failed to clone ${kernel_repo_tree}"
    return 1
  fi
}

# This function tests the build functionality of kworkflow
function test_kernel_build()
{
  local kw_tmp_dir
  local container
  local distro

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"
    kw_tmp_dir=$(container_exec "$container" 'mktemp --directory')

    # Preparing the environment: Clone kernel tree repository into a
    # temporary directory inside the container.
    say "cloning.."
    clone_kernel_tree_repo "$container" "$kw_tmp_dir"

    # Copying the .config file to kernel tree
    container_copy "$container" "${SAMPLES_DIR}/.config" "$kw_tmp_dir"

    say "installing kernel build dependencies"
    install_kworkflow_build_dependencies "$container" "$distro"

    say "building the kernel"
    container_exec "$container" "cd ${kw_tmp_dir} && kw build"
  done
}

invoke_shunit
