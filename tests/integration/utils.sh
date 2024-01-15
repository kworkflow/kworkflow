#!/bin/bash

include './src/lib/kwio.sh'

declare -g CONTAINER_DIR # Has the container files to build the container images
declare -g SAMPLES_DIR   # Has sample files used accross the integration tests
declare -g KWROOT_DIR    # Local kw dir to be copied to and installed in the containers
declare -g DISTROS       # Distributions we will run the integration tests

# Ensure path to directories is absolute
script_dir=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
CONTAINER_DIR="${script_dir}/podman"
SAMPLES_DIR="${script_dir}/samples"
KWROOT_DIR=$(realpath "${script_dir}/../..")

# Supported distros
DISTROS=(
  'archlinux'
  'debian'
  'fedora'
)

# Build a container image for the given distro
#
# @distro The OS distribution of the target container image.
#
# Return:
# The status code of the command ran to build the image.
function build_distro_image()
{
  local distro="$1"
  local file="${CONTAINER_DIR}/Containerfile_${distro}"

  podman image build --file "$file" --tag "kw-${distro}" > /dev/null 2>&1

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Error building the image for distribution ${distro}"
    return "$?"
  fi
}

# Build container images and create containers used accross the tests.
function setup_container_environment()
{
  local working_directory # working directory in the container
  local container_name
  local container_img
  local current_step
  local total_steps
  local distros_ok # array of distros whose setup succeeded
  local distro

  distros_ok=()
  current_step=0
  total_steps=$((${#DISTROS[@]} * 2))
  working_directory='/tmp/kw'

  for distro in "${DISTROS[@]}"; do

    # container_img is the image name, while container_name is the name of the
    # container built from the image.
    container_img="kw-${distro}"
    container_name="${container_img}"

    # Only build the image if it does not exist. That's because trying to build
    # the podman image takes a second or two even if it exists and is cached.
    podman image exists "${container_img}"
    if [[ "$?" -ne 0 ]]; then
      current_step=$((current_step + 1))
      say "[${current_step}/${total_steps}] Building container image for ${distro}. This might take a while..."

      build_distro_image "$distro"
      if [[ "$?" -ne 0 ]]; then
        complain "Failed to setup container environment for distro ${distro}"

        current_step=$((current_step + 1))
        say "[${current_step}/${total_steps}] Skip creating ${distro} container."

        continue
      fi
    else
      current_step=$((current_step + 1))
      say "[${current_step}/${total_steps}] Using cached container image for ${distro}."
    fi

    # If container exists, we tear it down and create a new one in order to
    # ensure KW installation reflects the latest local changes.
    podman container exists "${container_name}"
    if [[ "$?" -eq 0 ]]; then
      teardown_single_container "${container_name}"
    fi

    current_step=$((current_step + 1))
    say "[${current_step}/${total_steps}] Creating ${distro} container."

    # Podman containers are isolated environments designed to run a single
    # process. After the process ends, the container is destroyed. In order to
    # execute multiple commands in the container, we need to keep the
    # container alive, which means that the primary process must not terminate.
    # Therefore, we run a never-ending command as the primary process, so that
    # we can execute multiple commands (secondary processes) and get the output
    # of each of them separately.
    container_run \
      --workdir "${working_directory}" \
      --volume "${KWROOT_DIR}":"${working_directory}:Z" \
      --env PATH='/root/.local/bin:/usr/bin' \
      --name "${container_name}" \
      --detach \
      "${container_img}" sleep infinity > /dev/null

    if [[ "$?" -ne 0 ]]; then
      fail "(${LINENO}): Failed to run the container ${container_name}"
    fi

    # Container images already have kw installed. Install it again, overwriting
    # the installation.
    container_exec "${container_name}" \
      ./setup.sh --install --force --skip-checks --skip-docs > /dev/null 2>&1

    if [[ "$?" -ne 0 ]]; then
      fail "(${LINENO}): Failed to install kw in the container ${container_name}"
    else
      distros_ok+=("$distro")
    fi
  done

  # Update DISTRO so it only has distros whose setup succeed.
  # Thus, the integration tests can run even if some distros failed to set up.
  DISTROS=("${distros_ok[@]}")
}

# Destroy all containers used in the tests
function teardown_container_environment()
{
  local distro
  local i=0
  local total_distros="${#DISTROS[@]}"

  for distro in "${DISTROS[@]}"; do
    i=$((i + 1))
    say "[${i}/${total_distros}] Removing ${distro} container."
    teardown_single_container "kw-${distro}"
  done
}

# Destroy a single container
#
# @container: Name or ID of the container
function teardown_single_container()
{
  local container="$1"

  podman container exists "${container}"

  if [[ "$?" -eq 0 ]]; then
    # Destroy container sending SIGKILL instantly.
    podman container rm --force --time 0 "${container}" > /dev/null 2>&1
  fi
}

function container_run()
{
  # shellcheck disable=SC2068
  podman container run $@

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to run the container."
  fi
}

function container_exec()
{
  # shellcheck disable=SC2068
  podman container exec $@ 2> /dev/null

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to execute the command in the container."
  fi
}

# Copy files from the host to the container
#
# @container The container to copy files to.
# @src       The file in the host.
# @dst       The destination file or directory in the container.
function container_copy()
{
  local container="$1"
  local src="$2"
  local dst="$3"

  podman container cp "${src}" "${container}":"${dst}"

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to copy host files to the container."
  fi
}

function container_inspect()
{
  # shellcheck disable=SC2068
  podman container inspect $@

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to inspect the container."
  fi
}
