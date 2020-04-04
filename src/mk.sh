#
# The `mk.sh` file centralizes functions related to kernel operation workflows
# such as compile, installation, and others. With kworkflow, we want to handle
# three scenarios:
#
# 1. Virtual Machine (VM): we want to provide support for developers that uses
#    VM during their work with Linux Kernel, because of this kw provide
#    essential features for this case.
# 2. Local: we provide support for users to utilize their machine as a target.
# 3. Remote: we provide support for deploying kernel in a remote machine. It is
#    important to highlight that a VM in the localhost can be treated as a
#    remote machine.
#
# Usually, install modules and update the kernel image requires root
# permission, with this idea in mind we rely on the `/root` in the remote
# machine. Additionally, for local deploy, you will be asked to enter your
# root password.
#

. $src_script_path/vm.sh --source-only # It includes kw_config_loader.sh
. $src_script_path/kwlib.sh --source-only
. $src_script_path/remote.sh --source-only

# This function is responsible for handling the command to
# `make install_modules`, and it expects a target path for saving the modules
# files.
#
# @install_to Target path to install the output of the command `make
#             modules_install`.
# @flag How to display a command, see `src/kwlib.sh` function `cmd_manager`
function modules_install_to()
{
  local install_to="$1"
  local flag="$2"

  flag=${flag:-""}

  if ! is_kernel_root "$PWD"; then
    complain "Execute this command in a kernel tree."
    exit 125 # ECANCELED
  fi

  local cmd="make INSTALL_MOD_PATH=$install_to modules_install"
  set +e
  cmd_manager "$flag" "$cmd"
}

function vm_modules_install
{
  # Attention: The vm code have to be loaded before this function.
  # Take a look at the beginning of kworkflow.sh.
  vm_mount

  if [ "$?" != 0 ] ; then
    complain "Did you check if your VM is running?"
    return 125 # ECANCELED
  fi

  modules_install_to "${configurations[mount_point]}"

  vm_umount
}

# Get the kernel release based on the command kernel release.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
function get_kernel_release
{
  local flag="$1"
  local cmd="make kernelrelease"

  flag=${flag:-"SILENT"}

  cmd_manager "$flag" "$cmd"
}

# This function expects a parameter that specifies the target machine;
# in the first case, the host machine is the target, and otherwise the virtual
# machine.
#
# @target Target machine
function modules_install
{
  local ret
  local flag="$1"
  local target="$2"
  local formatted_remote="$3"

  if ! is_kernel_root "$PWD"; then
    complain "Execute this command in a kernel tree."
    exit 125 # ECANCELED
  fi

  flag=${flag:-""}

  case "$target" in
    1) # VM_TARGET
      vm_modules_install
      ;;
    2) # LOCAL_TARGET
      cmd="sudo -E make modules_install"
      cmd_manager "$flag" "$cmd"
      ;;
    3) # REMOTE_TARGET
      # 1. Preparation steps
      prepare_host_deploy_dir

      local remote=$(get_based_on_delimiter "$formatted_remote" ":" 1)
      local port=$(get_based_on_delimiter "$formatted_remote" ":" 2)
      # User may specify a hostname instead of bare IP
      remote=$(get_based_on_delimiter "$remote" "@" 2)

      prepare_remote_dir "$remote" "$port" "" "$flag"

      # 2. Send files modules
      modules_install_to "$kw_dir/$LOCAL_REMOTE_DIR/" "$flag"

      release=$(get_kernel_release "$flag")
      success "Kernel: $release"
      generate_tarball "$release" "" "$flag"

      local tarball_for_deploy_path="$kw_dir/$LOCAL_TO_DEPLOY_DIR/$release.tar"
      cp_host2remote "$tarball_for_deploy_path" \
                     "$REMOTE_KW_DEPLOY" "$remote" "$port" "" "$flag"

      # 3. Deploy: Execute script
      local cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --modules $release.tar"
      cmd_remotely "$cmd" "$flag" "$remote" "$port"
      ;;
  esac
}

# This function behaves like a kernel installation manager. It handles some
# parameters, and it also prepares to deploy the new kernel in the target
# machine.
#
# @reboot If this value is equal 1, it means reboot machine after kernel
#         installation.
# @name Kernel name to be deployed.
#
# Note:
# Take a look at the available kernel plugins at: src/plugins/kernel_install
function kernel_install
{
  local user=""
  local root_path="/"
  local host="--host"
  local distro="none"
  local boot_path="/boot"
  local mkinitcpio_path="/etc/mkinitcpio.d/"
  local kernel_name="${configurations[kernel_name]}"
  local mkinitcpio_name="${configurations[mkinitcpio_name]}"
  local reboot="$1"
  local name="$2"
  local flag="$3"
  local target="$4"
  local formatted_remote="$5"

  if ! is_kernel_root "$PWD"; then
    complain "Execute this command in a kernel tree."
    exit 125 # ECANCELED
  fi

  # We have to guarantee some default values values
  kernel_name=${kernel_name:-"nothing"}
  mkinitcpio_name=${mkinitcpio_name:-"nothing"}
  name=${name:-"kw"}
  flag=${flag:-""}

  if [[ "$reboot" == 0 ]]; then
    reboot_default="${configurations[reboot_after_deploy]}"
    if [[ "$reboot_default" =~ "yes" ]]; then
      reboot=1
    fi
  fi

  case "$target" in
    1) # VM_TARGET
      # TODO: See issue #139
      echo "Unfortunately, we don't support kernel image deploy in a VM with" \
           "libguestfs yet; however, an alternative is using the remote" \
           "option."
    ;;
    2) # LOCAL_TARGET
      local distro=$(detect_distro "/")

      if [[ "$distro" =~ "none" ]]; then
        complain "Unfortunately, there's no support for the target distro"
        exit 95 # ENOTSUP
      fi

      # Local Deploy
      . "$plugins_path/kernel_install/$distro.sh" --source-only
      install_kernel "$name" "$reboot" 'local' "${configurations[arch]}" "$flag"
    ;;
    3) # REMOTE_TARGET
      local preset_file="$kw_dir/$LOCAL_TO_DEPLOY_DIR/$name.preset"
      if [[ ! -f "$preset_file" ]]; then
        template_mkinit="$etc_files_path/template_mkinitcpio.preset"
        cp "$template_mkinit" "$preset_file"
        sed -i "s/NAME/$name/g" "$preset_file"
      fi

      local remote=$(get_based_on_delimiter "$formatted_remote" ":" 1)
      local port=$(get_based_on_delimiter "$formatted_remote" ":" 2)
      remote=$(get_based_on_delimiter "$remote" "@" 2)

      cp_host2remote "$kw_dir/$LOCAL_TO_DEPLOY_DIR/$name.preset" \
                     "$REMOTE_KW_DEPLOY" \
                     "$remote" "$port" "$user" "$flag"
      cp_host2remote "arch/x86_64/boot/bzImage" \
                     "$REMOTE_KW_DEPLOY/vmlinuz-$name" \
                     "$remote" "$port" "$user" "$flag"

      # Deploy
      local cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --kernel_update $name $reboot"
      cmd_remotely "$cmd" "$flag" "$remote" "$port"
    ;;
  esac
}

# From kw perspective, deploy a new kernel is composed of two steps: install
# modules and update kernel image. I chose this approach for reducing the
# chances of break the system due to modules and kernel mismatch. This function
# is responsible for handling some of the userspace options and calls the
# required functions to update the kernel. This function handles a different
# set of parameters for the distinct set of target machines.
#
# Note: I know that developer know what they are doing (usually) and in the
# future, it will be nice if we support single kernel update (patches are
# welcome).
#
# @reboot If 1 the target machine will be rebooted after the kernel update
# @name Kernel name for the deploy
function kernel_deploy
{
  local reboot=0
  local modules=0
  local target=0
  local test_mode=""

  if ! is_kernel_root "$PWD"; then
    complain "Execute this command in a kernel tree."
    exit 125 # ECANCELED
  fi

  for arg do
    shift
    [[ "$arg" =~ ^--vm ]] && target="$VM_TARGET" && continue
    [[ "$arg" =~ ^--local ]] && target="$LOCAL_TARGET" && continue
    [[ "$arg" =~ ^--remote ]] && target="$REMOTE_TARGET" && continue
    [[ "$arg" =~ ^(--reboot|-r) ]] && reboot=1 && continue
    [[ "$arg" =~ ^(--modules|-m) ]] && modules=1 && continue
    [[ "$arg" =~ ^(test_mode) ]] && test_mode="TEST_MODE" && continue
    set -- "$@" "$arg"
  done

  if [[ "$target" == 0 ]]; then
    deploy_target="${configurations[default_deploy_target]}"
    case "$deploy_target" in
      vm)
        target="$VM_TARGET"
        ;;
      local)
        target="$LOCAL_TARGET"
        ;;
      remote)
        target="$REMOTE_TARGET"
        ;;
      *)
        warning "We could not determine your deploy target, set it to VM." \
                "Please, check your local kworkflow.conf"
        target="$VM_TARGET"
        ;;
    esac
  fi

  # Handle the case of --remote [REMOTE:PORT]
  if [[ "$target" == "$REMOTE_TARGET" ]]; then
    remote=$(get_remote_info "$@")
    if [[ "$?" == 22 ]]; then
      complain "$remote"
      exit 22
    fi
  fi

  if [[ "$test_mode" == "TEST_MODE" ]]; then
    echo "$reboot $modules $target $remote"
    return 0
  fi

  # NOTE: If we deploy a new kernel image that does not match with the modules,
  # we can break the boot. For security reason, every time we want to deploy a
  # new kernel version we also update all modules; maybe one day we can change
  # it, but for now this looks the safe option.
  modules_install "" "$target" "$remote"

  if [[ "$modules" == 0 ]]; then
    # Update name: release + alias
    name=$(make kernelrelease)

    kernel_install "$reboot" "$name" "" "$target" "$remote"
  fi
}

function mk_build
{
  local PARALLEL_CORES=1

  if [ -x "$(command -v nproc)" ] ; then
    PARALLEL_CORES=$(nproc --all)
  else
    PARALLEL_CORES=$(grep -c ^processor /proc/cpuinfo)
  fi

  say "make ARCH="${configurations[arch]}" -j$PARALLEL_CORES"
  make ARCH="${configurations[arch]}" -j$PARALLEL_CORES
}

# Handles the remote info
#
# @parameters String to be parsed
#
# Returns:
# This function has two returns, and we make the second return by using
# capturing the "echo" output. The standard return ("$?") can be 22 if
# something is wrong or 0 if everything finished as expected; the second
# output is the remote info as IP:PORT
function get_remote_info()
{
  ip="$@"

  if [[ -z "$ip" ]]; then
    ip=${configurations[ssh_ip]}
    port=${configurations[ssh_port]}
    ip="$ip:$port"
  else
    temp_ip=$(get_based_on_delimiter "$ip" ":" 1)
    # 22 in the conditon refers to EINVAL
    if [[ "$?" == 22 ]]; then
      ip="$ip:22"
    else
      port=$(get_based_on_delimiter "$ip" ":" 2)
      ip="$temp_ip:$port"
    fi
  fi

  if [[ "$ip" =~ ^: ]]; then
    complain "Something went wrong with the remote option"
    return 22 # EINVAL
  fi

  echo "$ip"
  return 0
}
