#!/bin/bash

include './src/lib/kwio.sh'

declare -g CONTAINER_DIR # has the container files to build the container images
declare -g SAMPLES_DIR   # has sample files used accross the integration tests
declare -g KWROOT_DIR    # local kw dir to be copied to and installed in the containers
declare -g DISTROS       # distributions we will run the integration tests

# ensure path to directories is absolute
script_dir=$(realpath "$(dirname "${BASH_SOURCE[0]}")")
CONTAINER_DIR="${script_dir}/podman"
SAMPLES_DIR="${script_dir}/samples"
KWROOT_DIR=$(realpath "${script_dir}/../..")

# supported distros
DISTROS=(
  'archlinux'
  'debian'
  'fedora'
)

# Builds a container image for the given distro
#
# @param $1 The OS distribution of the target container image.
# @return $? The status code of the command ran to build the image.
function build_distro_image()
{
  local distro="${1}"
  local file="${CONTAINER_DIR}/Containerfile_${distro}"

  podman image build --file "$file" --tag "kw-${distro}" > /dev/null 2>&1

  # Check if the command failed
  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Error building the image for distribution ${distro}"
    return "$?"
  fi
}

# Builds container images and create containers used accross the tests.
#
# @param $1 log level to print info, debug or error
function setup_container_environment()
{
  local container_img
  local container_name
  local distro            # current distro
  local distros_ok        # array of distros whose setup succeed
  local i                 # current step of the setup
  local n                 # total number of steps
  local working_directory # working directory in the container

  # initialize some values
  distros_ok=()
  i=0
  n=$((${#DISTROS[@]} * 2))
  working_directory='/tmp/kw'

  for distro in "${DISTROS[@]}"; do

    # Only build the image if it does not exists. That's because trying to build
    # the podman image takes a second or two even if it exists and is cached.
    podman image exists "kw-${distro}"
    if [[ "$?" -ne 0 ]]; then
      # progress message:
      i=$((i + 1))
      say "[${i}/${n}] Building container image for ${distro}."

      # Build the image or fail.
      build_distro_image "$distro"
      if [[ "$?" -ne 0 ]]; then
        complain "failed to setup container environment for distro ${distro}"

        # print we will skip creating the container image
        i=$((i + 1))
        say "[${i}/${n}] Skip creating ${distro} container."

        # continue the setup for other distros.
        continue
      fi
    else
      # progress message:
      i=$((i + 1))
      say "[${i}/${n}] Using cached container image for ${distro}."
    fi

    # The name of the container and the container image are equal here,  but  it
    # is useful to make a distinction that in some places we should use the image
    # name and in others the container name (they are equal in value but are not
    # equivalent in meaning).
    container_img="kw-${distro}"
    container_name="${container_img}"

    # If container exists, we tear it down and create a new one in order
    # ensure KW installation reflects the latest local changes.
    podman container exists "${container_name}"
    if [[ "$?" -eq 0 ]]; then
      teardown_single_container "${container_name}"
    fi

    # progress message:
    i=$((i + 1))
    say "[${i}/${n}] Creating ${distro} container."

    # containers are isolated environments designed to run a  process.  After  the
    # process ends, the container is destroyed. In order execute multiple commands
    # in the container, we need to keep the container,  which  means  the  primary
    # process must not terminate. Therefore, we run a never-ending command as  the
    # primary process,  so  that  we  can  execute  multiple  commands  (secondary
    # processes) and get the output of each of them separately.
    container_run \
      --workdir "${working_directory}" \
      --volume "${KWROOT_DIR}":"${working_directory}" \
      --env PATH='/root/.local/bin:/usr/bin' \
      --name "${container_name}" \
      --detach \
      "${container_img}" sleep infinity > /dev/null

    if [[ "$?" -ne 0 ]]; then
      fail "(${LINENO}): Failed to run the container ${container_name}"
    fi

    # install kw again
    container_exec "${container_name}" \
      ./setup.sh --install --force --skip-checks --skip-docs > /dev/null 2>&1

    if [[ "$?" -ne 0 ]]; then
      fail "(${LINENO}): Failed to install kw in the container ${container_name}"
    else
      # add distro to array of distros that worked.
      distros_ok+=("$distro")
    fi
  done

  # Update DISTRO so it only has distros whose setup succeed.
  # Thus, the integration tests can run even if some distros failed to set up.
  DISTROS=("${distros_ok[@]}")
}

# destroy a single container
function teardown_single_container()
{
  local container="$1"

  podman container exists "${container}"

  if [[ "$?" -eq 0 ]]; then
    # destroy the container, waiting 0 seconds to send SIGKILL
    podman container rm --force --time 0 "${container}" > /dev/null 2>&1
  fi
}

# destroy all containers used in the tests
teardown_container_environment()
{
  local distro
  local i=0                # current step of tear down
  local n="${#DISTROS[@]}" # total number of steps of tear down

  for distro in "${DISTROS[@]}"; do
    # progress message
    i=$((i + 1))
    say "[${i}/${n}] Removing ${distro} container."

    teardown_single_container "kw-${distro}"
  done
}

# run a container
function container_run()
{
  # shellcheck disable=SC2068
  podman container run $@

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to run the container."
  fi
}

# execute a given command in the container
function container_exec()
{
  # shellcheck disable=SC2068
  podman container exec $@ 2> /dev/null

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to execute the command in the container."
  fi
}
