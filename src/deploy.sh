#
# The `deploy.sh` file centralizes functions related to kernel installation.
# With kworkflow, we want to handle three scenarios:
#
# 1. Virtual Machine (VM): we want to provide support for developers that uses
#    VM during their work with Linux Kernel, because of this kw provide
#    essential features for this case.
# 2. Local: we provide support for users to utilize their machine as a target.
# 3. Remote: we provide support for deploying kernel in a remote machine. It is
#    important to highlight that a VM in the localhost can be treated as a
#    remote machine.
#
# Usually, installing modules and updating the kernel image requires root
# permission. With this idea in mind we rely on the `/root` in the remote
# machine. Additionally, for local deploy you will be asked to enter your root
# password.
#

include "$KW_LIB_DIR/vm.sh" # It includes kw_config_loader.sh and kwlib.sh
include "$KW_LIB_DIR/remote.sh"
include "$KW_LIB_DIR/signal_manager.sh"

# Hash containing user options
declare -gA options_values

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
# Note: This function relies on the parameters set in the config file.
function kernel_deploy()
{
  local reboot=0
  local modules=0
  local target=0
  local list=0
  local single_line=0
  local uninstall=''
  local start=0
  local end=0
  local runtime=0
  local ret=0

  if [[ "$1" =~ -h|--help ]]; then
    deploy_help "$1"
    exit 0
  fi

  parse_deploy_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  target="${options_values['TARGET']}"
  reboot="${options_values['REBOOT']}"
  modules="${options_values['MODULES']}"
  single_line="${options_values['LS_LINE']}"
  list="${options_values['LS']}"
  uninstall="${options_values['UNINSTALL']}"

  if [[ "$list" == 1 || "$single_line" == 1 ]]; then
    say 'Available kernels:'
    start=$(date +%s)
    list_installed_kernels '' "$single_line" "$target"
    end=$(date +%s)

    runtime=$((end - start))
    statistics_manager 'list' "$runtime"
    return "$?"
  fi

  if [[ -n "$uninstall" ]]; then
    start=$(date +%s)
    kernel_uninstall "$target" "$reboot" "$uninstall" "$flag"
    end=$(date +%s)

    runtime=$((end - start))
    statistics_manager 'uninstall' "$runtime"
    return "$?"
  fi

  if ! is_kernel_root "$PWD"; then
    complain 'Execute this command in a kernel tree.'
    exit 125 # ECANCELED
  fi

  signal_manager 'cleanup' || warning 'Was not able to set signal handler'

  if [[ "$target" == "$VM_TARGET" ]]; then
    vm_mount
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      complain 'Please shutdown or umount your VM to continue.'
      exit "$ret"
    fi
  fi

  # NOTE: If we deploy a new kernel image that does not match with the modules,
  # we can break the boot. For security reason, every time we want to deploy a
  # new kernel version we also update all modules; maybe one day we can change
  # it, but for now this looks the safe option.
  start=$(date +%s)
  modules_install '' "$target"
  end=$(date +%s)
  runtime=$((end - start))

  if [[ "$modules" == 0 ]]; then
    start=$(date +%s)
    # Update name: release + alias
    name=$(make kernelrelease)

    kernel_install "$reboot" "$name" '' "$target"
    end=$(date +%s)
    runtime=$((runtime + (end - start)))
    statistics_manager 'deploy' "$runtime"
  else
    statistics_manager 'Modules_deploy' "$runtime"
  fi

  if [[ "$target" == "$VM_TARGET" ]]; then
    # Umount VM if it remains mounted
    vm_umount
  fi

  #shellcheck disable=SC2119
  cleanup
}

# This function gets raw data and based on that fill out the options values to
# be used in another function.
#
# @raw_options String with all user options
#
# Return:
# In case of successful return 0, otherwise, return 22.
#
function parse_deploy_options()
{
  local enable_collect_param=0
  local remote
  local options
  local long_options='remote:,local,vm,reboot,modules,list,ls-line,uninstall:'
  local short_options='r,m,l,s,u:'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw deploy' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['UNINSTALL']=''
  options_values['MODULES']=0
  options_values['LS_LINE']=0
  options_values['LS']=0
  options_values['REBOOT']=0
  options_values['MENU_CONFIG']='nconfig'

  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_USER']=''

  # Set basic default values
  if [[ -n ${configurations[default_deploy_target]} ]]; then
    local config_file_deploy_target=${configurations[default_deploy_target]}
    options_values['TARGET']=${deploy_target_opt[$config_file_deploy_target]}
  else
    options_values['TARGET']="$VM_TARGET"
  fi

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']="Invalid remote: $remote"
    return 22 # EINVAL
  fi

  if [[ ${configurations[reboot_after_deploy]} == 'yes' ]]; then
    options_values['REBOOT']=1
  fi

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --remote)
        options_values['TARGET']="$REMOTE_TARGET"
        populate_remote_info "$2"
        if [[ "$?" == 22 ]]; then
          options_values['ERROR']="Invalid remote: $2"
          return 22 # EINVAL
        fi
        shift 2
        ;;
      --local)
        options_values['TARGET']="$LOCAL_TARGET"
        shift
        ;;
      --vm)
        options_values['TARGET']="$VM_TARGET"
        shift
        ;;
      --reboot | -r)
        options_values['REBOOT']=1
        shift
        ;;
      --modules | -m)
        options_values['MODULES']=1
        shift
        ;;
      --list | -l)
        options_values['LS']=1
        shift
        ;;
      --ls-line | -s)
        options_values['LS_LINE']=1
        shift
        ;;
      --uninstall | -u)
        if [[ "$2" =~ ^-- ]]; then
          options_values['ERROR']='Uninstall requires a kernel name'
          return 22 # EINVAL
        fi
        options_values['UNINSTALL']+="$2"
        shift 2
        ;;
      --) # End of options, beginning of arguments
        shift
        ;;
      *)
        options_values['ERROR']="Unrecognized argument: $1"
        return 22 # EINVAL
        shift
        ;;
    esac
  done

  case "${options_values['TARGET']}" in
    1 | 2 | 3) ;;

    *)
      options_values['ERROR']="Invalid target value: ${options_values['TARGET']}"
      return 22 # EINVAL
      ;;
  esac
}

# This function list all the available kernels in a VM, local, and remote
# machine. This code relies on `kernel_install` plugin, more precisely on
# `utils.sh` file which comprises all the required operations for listing new
# Kernels.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
# @single_line If this option is set to 1 this function will display all
#   available kernels in a single line separated by commas. If it gets 0 it
#   will display each kernel name by line.
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
function list_installed_kernels()
{
  local flag="$1"
  local single_line="$2"
  local target="$3"
  local remote
  local port

  flag=${flag:-'SILENT'}

  case "$target" in
    1) # VM_TARGET
      vm_mount

      if [ "$?" != 0 ]; then
        complain 'Did you check if your VM is running?'
        return 125 # ECANCELED
      fi

      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      list_installed_kernels "$single_line" "${configurations[mount_point]}"

      vm_umount
      ;;
    2) # LOCAL_TARGET
      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      list_installed_kernels "$single_line"
      ;;
    3) # REMOTE_TARGET
      local cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --list_kernels $single_line"
      remote="${remote_parameters['REMOTE_IP']}"
      port="${remote_parameters['REMOTE_PORT']}"

      prepare_remote_dir "$remote" "$port" '' "$flag"

      cmd_remotely "$cmd" "$flag" "$remote" "$port"
      ;;
  esac

  return 0
}

# This function handles the kernel uninstall process for different targets.
#
# @target Target machine Target machine Target machine Target machine
# @reboot If this value is equal 1, it means reboot machine after kernel
#         installation.
# @kernels_target List containing kernels to be uninstalled
# @flag How to display a command, see `src/kwlib.sh` function `cmd_manager`
#
# Return:
# Return 0 if everything is correct or an error in case of failure
function kernel_uninstall()
{
  local target="$1"
  local reboot="$2"
  local kernels_target="$3"
  local flag="$4"
  local distro
  local remote
  local port

  flag=${flag:-''}

  case "$target" in
    1) # VM_TARGET
      printf '%s\n' 'UNINSTALL VM'
      ;;
    2) # LOCAL_TARGET
      distro=$(detect_distro '/')

      if [[ "$distro" =~ 'none' ]]; then
        complain 'Unfortunately, there is no support for the target distro'
        exit 95 # ENOTSUP
      fi

      # Local Deploy
      # We need to update grub, for this reason we to load specific scripts.
      include "$KW_PLUGINS_DIR/kernel_install/$distro.sh"
      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      # TODO: Rename kernel_uninstall in the plugin, this name is super
      # confusing
      kernel_uninstall "$reboot" 'local' "$kernels_target" "$flag"
      ;;
    3) # REMOTE_TARGET
      remote="${remote_parameters['REMOTE_IP']}"
      port="${remote_parameters['REMOTE_PORT']}"

      prepare_remote_dir "$remote" "$port" '' "$flag"

      # Deploy
      # TODO
      # It would be better if `cmd_remotely` handle the extra space added by
      # line break with `\`; this may allow us to break a huge line like this.
      local cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --uninstall_kernel $reboot remote $kernels_target $flag"
      cmd_remotely "$cmd" "$flag" "$remote" "$port"
      ;;
  esac
}

# When kw deploy a new kernel it creates temporary files to be used for moving
# to the target machine. There is no need to keep those files in the user
# machine, for this reason, this function is in charge of cleanup the temporary
# files at the end.
function cleanup()
{
  local flag=${1:-'SILENT'}
  say 'Cleaning up temporary files...'

  if [[ -d "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR" ]]; then
    cmd_manager "$flag" "rm -rf $KW_CACHE_DIR/$LOCAL_REMOTE_DIR/"*
  fi

  if [[ -d "$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR" ]]; then
    cmd_manager "$flag" "rm -rf $KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/"*
  fi

  say 'Exiting...'
  exit 0
}

# This function expects a parameter that specifies the target machine;
# in the first case, the host machine is the target, and otherwise the virtual
# machine.
#
# @target Target machine
function modules_install()
{
  local flag="$1"
  local target="$2"
  local remote
  local port
  local distro

  flag=${flag:-''}

  case "$target" in
    1) # VM_TARGET
      distro=$(detect_distro "${configurations[mount_point]}/")

      if [[ "$distro" =~ 'none' ]]; then
        complain 'Unfortunately, there is no support for the target distro'
        vm_umount
        exit 95 # ENOTSUP
      fi

      modules_install_to "${configurations[mount_point]}" "$flag"
      ;;
    2) # LOCAL_TARGET
      cmd='sudo -E make modules_install'
      cmd_manager "$flag" "$cmd"
      ;;
    3) # REMOTE_TARGET
      # 1. Preparation steps
      prepare_host_deploy_dir

      remote="${remote_parameters['REMOTE_IP']}"
      port="${remote_parameters['REMOTE_PORT']}"
      user="${remote_parameters['REMOTE_USER']}"

      prepare_remote_dir "$remote" "$port" "$user" "$flag"

      # 2. Send files modules
      modules_install_to "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR/" "$flag"

      release=$(get_kernel_release "$flag")
      success "Kernel: $release"
      generate_tarball "$KW_CACHE_DIR/$LOCAL_REMOTE_DIR/lib/modules/" \
        "$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/$release.tar" '' "$release" "$flag"

      local tarball_for_deploy_path="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/$release.tar"
      cp_host2remote "$tarball_for_deploy_path" \
        "$REMOTE_KW_DEPLOY" "$remote" "$port" '' "$flag"

      # 3. Deploy: Execute script
      local cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --modules $release.tar"
      cmd_remotely "$cmd" "$flag" "$remote" "$port"
      ;;
  esac
}
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

  flag=${flag:-''}

  local cmd="make INSTALL_MOD_PATH=$install_to modules_install"
  set +e
  cmd_manager "$flag" "$cmd"
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
function kernel_install()
{
  local reboot="$1"
  local name="$2"
  local flag="$3"
  local target="$4"
  local user="${5:-${remote_parameters['REMOTE_USER']}}"
  local distro='none'
  local kernel_name="${configurations[kernel_name]}"
  local mkinitcpio_name="${configurations[mkinitcpio_name]}"
  local arch_target="${configurations[arch]}"
  local kernel_img_name="${configurations[kernel_img_name]}"
  local remote
  local port
  local distro

  # We have to guarantee some default values values
  kernel_name=${kernel_name:-'nothing'}
  mkinitcpio_name=${mkinitcpio_name:-'nothing'}
  name=${name:-'kw'}
  flag=${flag:-''}

  if [[ "$reboot" == 0 ]]; then
    reboot_default="${configurations[reboot_after_deploy]}"
    if [[ "$reboot_default" =~ 'yes' ]]; then
      reboot=1
    fi
  fi

  if [[ ! -f "arch/$arch_target/boot/$kernel_img_name" ]]; then
    # Try to infer the kernel image name
    kernel_img_name=$(find "arch/$arch_target/boot/" -name '*Image' 2> /dev/null)
    if [[ -z "$kernel_img_name" ]]; then
      complain "We could not find a valid kernel image at arch/$arch_target/boot"
      complain 'Please, check your compilation and/or the option kernel_img_name inside kworkflow.config'
      exit 125 # ECANCELED
    fi
    warning "kw inferred arch/$arch_target/boot/$kernel_img_name as a kernel image"
  fi

  case "$target" in
    1) # VM_TARGET
      distro=$(detect_distro "${configurations[mount_point]}/")

      if [[ "$distro" =~ 'none' ]]; then
        complain 'Unfortunately, there is no support for the target distro'
        vm_umount
        exit 95 # ENOTSUP
      fi

      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      include "$KW_PLUGINS_DIR/kernel_install/$distro.sh"
      install_kernel "$name" "$distro" "$kernel_img_name" "$reboot" "$arch_target" 'vm' "$flag"
      return "$?"
      ;;
    2) # LOCAL_TARGET
      distro=$(detect_distro '/')

      if [[ "$distro" =~ 'none' ]]; then
        complain 'Unfortunately, there is no support for the target distro'
        exit 95 # ENOTSUP
      fi

      # Local Deploy
      if [[ $(id -u) == 0 ]]; then
        complain 'kw deploy --local should not be run as root'
        exit 1 # EPERM
      fi

      include "$KW_PLUGINS_DIR/kernel_install/utils.sh"
      include "$KW_PLUGINS_DIR/kernel_install/$distro.sh"
      install_kernel "$name" "$distro" "$kernel_img_name" "$reboot" "$arch_target" 'local' "$flag"
      return "$?"
      ;;
    3) # REMOTE_TARGET
      local preset_file="$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/$name.preset"
      if [[ ! -f "$preset_file" ]]; then
        template_mkinit="$KW_ETC_DIR/template_mkinitcpio.preset"
        cp "$template_mkinit" "$preset_file"
        sed -i "s/NAME/$name/g" "$preset_file"
      fi

      remote="${remote_parameters['REMOTE_IP']}"
      port="${remote_parameters['REMOTE_PORT']}"
      user="${remote_parameters['REMOTE_USER']}"

      distro_info=$(which_distro "$remote" "$port" "$user")
      distro=$(detect_distro '/' "$distro_info")

      cp_host2remote "$KW_CACHE_DIR/$LOCAL_TO_DEPLOY_DIR/$name.preset" \
        "$REMOTE_KW_DEPLOY" \
        "$remote" "$port" "$user" "$flag"
      cp_host2remote "arch/$arch_target/boot/$kernel_img_name" \
        "$REMOTE_KW_DEPLOY/vmlinuz-$name" \
        "$remote" "$port" "$user" "$flag"

      # Deploy
      local cmd_parameters="$name $distro $kernel_img_name $reboot $arch_target 'remote' $flag"
      local cmd="bash $REMOTE_KW_DEPLOY/deploy.sh --kernel_update $cmd_parameters"
      cmd_remotely "$cmd" "$flag" "$remote" "$port"
      ;;
  esac
}

function deploy_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'deploy'
    return
  fi
  printf '%s\n' 'kw deploy:' \
    '  deploy - installs kernel and modules:' \
    '  deploy (--remote <remote>:<port> | --local | --vm) - choose target' \
    '  deploy (--reboot | -r) - reboot machine after deploy' \
    '  deploy (--modules | -m) - install only modules' \
    '  deploy (--uninstall | -u) <kernel-name>,... - uninstall given kernels' \
    '  deploy (--list | -l) - list kernels' \
    '  deploy (--ls-line | -s) - list kernels separeted by commas'
}
