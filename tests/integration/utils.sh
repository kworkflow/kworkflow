#!/bin/bash

include './src/lib/kwio.sh'

declare -gr CONTAINER_BASE_IMAGE='docker.io/library'
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

  image_build --file "$file" --tag "kw-${distro}"

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
    image_exists "${container_img}"
    if [[ "$?" -ne 0 ]]; then
      current_step=$((current_step + 1))
      say "[${current_step}/${total_steps}] Building container image for ${distro}. This might take a while..."

      build_distro_image "$distro"
      if [[ "$?" -ne 0 ]]; then
        complain "Failed to setup container for distro ${distro}"

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
    container_exists "${container_name}"
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
    container_exec "${container_name}" './setup.sh --install --force --skip-checks --skip-docs > /dev/null 2>&1'

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

# Destroy all containers used in the tests.
function teardown_containers()
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
# @container    Container name or id.
function teardown_single_container()
{
  local container="$1"

  container_exists "${container}"

  if [[ "$?" -eq 0 ]]; then
    # Destroy container sending SIGKILL instantly.
    podman container rm --force --time 0 "${container}" > /dev/null 2>&1
  fi
}

# Completely remove the container environment: the containers and the images
#
# @flag   Optional. Currently, only accepts '-f' or '--force' to force removal of cached images.
function teardown_container_environment()
{
  local flag="$1"
  local container_name
  local distro
  local img
  local img_layer_list
  local dangling_img
  local dangling_img_layer_list

  for distro in "${DISTROS[@]}"; do
    container_name="kw-${distro}"
    podman container exists "${container_name}"
    if [[ "$?" -eq 0 ]]; then
      say "Removing podman container kw-${distro}."
      teardown_single_container "${container_name}"
    fi

    img="kw-${distro}"
    image_exists "${img}"
    if [[ "$?" -eq 0 ]]; then
      say "Removing podman ${img} image."

      # Get this image layers, so we can safely remove its children dangling images.
      img_layer_list=$(image_inspect -f '{{.RootFS.Layers}}' "${img}" | tr -d '[]')

      # Remove possible dangling images
      while read -r dangling_img; do
        # We check if the image exist  because  it  could  happen  that  in  the
        # previous iteration the father dangling image was deleted, causing  the
        # child dangling image to be deleted as well.
        image_exists "${dangling_img}"
        if [[ "$?" -ne 0 ]]; then
          continue
        fi

        # We check if the dangling image have layers which are exact prefixes of
        # the current image we are trying to delete.
        dangling_img_layer_list=$(image_inspect -f '{{.RootFS.Layers}}' "${dangling_img}" | tr -d '[]')
        grep --perl-regexp "^${dangling_img_layer_list}" <<< "${img_layer_list}" > /dev/null

        # Delete the dangling image if that is the case.
        if [[ "$?" -eq 0 ]]; then
          # Dangling images are always force-removed.
          image_rm --force "${dangling_img}"
        fi
      done <<< "$(image_ls --all --quiet --filter 'intermediate=true')"

      # Remove main image.
      image_rm --force "${img}"
      if [[ "$?" -ne 0 ]]; then
        complain "Failed to remove ${img} image."
      fi
    fi

    # Remove the base image for the distro.
    img="${CONTAINER_BASE_IMAGE}/${distro}"
    image_exists "${img}"
    if [[ "$?" -eq 0 ]]; then
      say "Removing podman ${img} image."

      if [[ -n "$flag" ]]; then
        image_rm "$flag" "$img"
      else
        image_rm "$img"
      fi
    fi
  done
}

# Check if the given image exists.
#
# @image    The image name or id.
function image_exists()
{
  podman image exists "$1"
}

# Remove the given images.
#
# @flags    Optional flags to be passed to podman.
#           If it is '-f' or '--force', then it should be the ONLY flag.
# @images   Image names or ids.
function image_rm()
{
  local force_remove=0
  local img

  if [[ "$1" == "-f" || "$1" == "--force" ]]; then
    force_remove=1
    shift
  fi

  if [[ "$#" -lt 1 ]]; then
    complain "(${LINENO}): no image provided to be removed."
    return 1
  fi

  # shellcheck disable=SC2068
  podman image rm $@ > /dev/null 2>&1

  # command succeed.
  if [[ "$?" -eq 0 ]]; then
    return 0
  fi

  # comman failed and we should not force-attempt it.
  if [[ "$force_remove" == 0 ]]; then
    complain "(${LINENO}): kw failed to execute \`podman image rm ${*}\`. Consider using --force flag."
    return 1
  fi

  # We try it again, this time forcing the removal of the images.
  # WARNING: If the first argument is '-f', we suppose all the other ones are the image names.
  while [[ "$#" -gt 0 ]]; do
    img="$1"
    shift

    # Make sure the image exists.
    podman image exists "$img"
    if [[ "$?" -ne 0 ]]; then
      complain "(${LINENO}) provided image '${img}' does not exist."
      continue
    fi

    # Force remove all containers that depend on that image, one by one.
    (podman container ls --all --quiet --filter ancestor="$img" |
      xargs -n1 podman container rm --force --time 0) > /dev/null 2>&1

    # Force remove the image now.
    podman image rm --force "$img" > /dev/null 2>&1
  done
}

# List the given images.
#
# @options  Options to be passed to podman.
# @images   Image names or ids.
function image_ls()
{
  if [[ "$#" -le 1 ]]; then
    complain "(${LINENO}): no image provided to be listed."
    return 1
  fi

  # shellcheck disable=SC2068
  podman image ls $@

  if [[ "$?" -ne 0 ]]; then
    complain "(${LINENO}): kw failed to execute \`podman image ls ${*}\`."
  fi
}

# Inspect the given images.
#
# @options  Options to be passed to podman.
# @images   Image names or ids.
function image_inspect()
{
  # shellcheck disable=SC2068
  podman image inspect $@

  if [[ "$?" -ne 0 ]]; then
    complain "(${LINENO}): kw failed to execute \`podman image inspect ${*}\`."
  fi
}

# Build a container image.
#
# @args   Arguments to be passed to podman.
function image_build()
{
  # shellcheck disable=SC2068
  podman image build $@ > /dev/null 2>&1

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to build the image."
  fi
}

# Check existence of given container.
#
# @container    The container name or id.
function container_exists()
{
  podman container exists "$1"
}

# Remove the given containers.
#
# @options      Options to be passed to podman if any.
# @containers   Container names or ids.
function container_rm()
{
  # shellcheck disable=SC2068
  podman container rm $@ > /dev/null 2>&1

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to remove containers."
  fi
}

# Run a container.
#
# @args   Arguments to be passed to podman.
function container_run()
{
  # shellcheck disable=SC2068
  podman container run $@

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to run the container."
  fi
}

# Execute a command within a container.
#
# @container_name       The name or ID of the target container.
# @container_command    The command to be executed within the container.
# @podman_exec_options  Extra parameters for 'podman container exec' like
#                       --workdir, --env, and other supported options.
function container_exec()
{
  local container_name="$1"
  local container_command="$2"
  local podman_exec_options="$3"
  local cmd='podman container exec'

  if [[ -n "$podman_exec_options" ]]; then
    cmd+=" ${podman_exec_options}"
  fi

  cmd+=" ${container_name} /bin/sh -c '${container_command}' 2> /dev/null"
  eval "$cmd"

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to execute the command in the container."
  fi
}

# Copy files from the host to the container.
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

# Inspect the given containers.
#
# @options      Options to be passed to podman.
# @containers   Container names or ids.
function container_inspect()
{
  # shellcheck disable=SC2068
  podman container inspect $@

  if [[ "$?" -ne 0 ]]; then
    fail "(${LINENO}): Failed to inspect the container."
  fi
}
