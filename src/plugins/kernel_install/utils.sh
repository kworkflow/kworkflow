declare -g INSTALLED_KERNELS_PATH="$REMOTE_KW_DEPLOY/INSTALLED_KERNELS"

# ATTENTION:
# This function follows the cmd_manager signature (src/kwlib.sh) because we
# share the specific distro in the kw main code. However, when we deploy for a
# remote machine, we need this function, and this is the reason that we added
# this function.
function cmd_manager()
{
  local flag="$1"

  case "$flag" in
    SILENT)
      shift 1
      ;;
    WARNING)
      shift 1
      printf '%s\n' 'WARNING' "$@"
      ;;
    SUCCESS)
      shift 1
      printf '%s\n' 'SUCCESS' "$@"
      ;;
    TEST_MODE)
      shift 1
      printf '%s\n' "$@"
      return 0
      ;;
    VERBOSE)
      shift 1
      printf '%s\n' "$@"
      ;;
    *) # VERBOSE
      printf '%s\n' "$@"
      ;;
  esac

  eval "$@"
}

function collect_deploy_info()
{
  local flag="$1"
  local target="$2"
  local prefix="$3"
  local distro
  local bootloader

  # Let's include the bootloader_utils in the remote, and local/vm should
  # include themselves
  # XXX: We must remove the numeric value of target because this is not the
  # default here. i.e., if [["$target" == 'remote' ]]; ...
  if [[ "$target" == 3 || "$target" == 'remote' ]]; then
    . "$REMOTE_KW_DEPLOY/bootloader_utils.sh" --source-only
  fi

  bootloader=$(identify_bootloader_from_files "$prefix")
  bootloader="[bootloader]=$bootloader"

  # Get distro
  distro=$(cat /etc/*-release | grep -w ID | cut -d = -f 2)
  distro="[distro]=$distro"

  # Build associative array data
  printf '%s' "$bootloader $distro"
}

# This function is responsible for running a basic setup for the target machine
# based on its specific distro. Notice that this function works as a generic
# API that depends on the distro-specific file; for this reason, it is
# mandatory to load the distro code before calling this function.
#
# Note: the array "required_packages" is in the distro specific file and
# it must be load before invoke this function
function distro_deploy_setup()
{
  local flag="$1"
  local package_list
  local install_package_cmd

  printf -v package_list '%s ' "${required_packages[@]}"

  install_package_cmd="$package_manager_cmd $package_list"
  cmd_manager "$flag" "$install_package_cmd"
}

function ask_yN()
{
  local message="$*"

  read -r -p "$message [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    printf '%s\n' '1'
  else
    printf '%s\n' '0'
  fi
}

# List available kernels
# @single_line If this option is set to 1 this function will display all
#   available kernels in a single line separated by commas. If it gets 0 it
#   will display each kernel name by line.
# @prefix Set a base prefix for searching for kernels.
# @all List all available kernels, not only the ones installed by kw
function list_installed_kernels()
{
  local flag="$1"
  local single_line="$2"
  local all="$3"
  local prefix="$4"
  local -a available_kernels=()
  local cmd

  cmd_manager "$flag" "sudo mkdir -p $REMOTE_KW_DEPLOY"
  cmd_manager "$flag" "sudo touch $INSTALLED_KERNELS_PATH"

  if [[ -n "$all" ]]; then
    if [[ -d "$prefix/boot/grub/" ]]; then
      list_installed_kernels_based_on_grub "$prefix" 'available_kernels'
    else
      printf '%s\n' 'Could not find grub installed. Cannot list all installed kernels'
      return 95 # ENOTSUP
    fi
  else
    readarray -t available_kernels < "$INSTALLED_KERNELS_PATH"
    if [[ "${#available_kernels[@]}" -eq 0 ]]; then
      printf '%s\n' 'None of the installed kernels are managed by kw.' \
        'Pass --list-all|-a to see all installed kernels.'
      return 0
    fi
  fi

  if [[ "$single_line" != 1 ]]; then
    printf '%s\n' "${available_kernels[@]}"
  else
    local IFS=','
    printf '%s\n' "${available_kernels[*]}"
  fi

  return 0
}

list_installed_kernels_based_on_grub()
{
  local prefix="$1"
  local -n _available_kernels="$2"
  local grub_cfg
  local output
  local super=0

  grub_cfg="$prefix/boot/grub/grub.cfg"

  output=$(awk -F\' '/menuentry / {print $2}' "$grub_cfg" 2> /dev/null)

  if [[ "$?" != 0 ]]; then
    if ! [[ -r "$grub_cfg" ]]; then
      printf '%s' 'For showing the available kernel in your system we have ' \
        'to take a look at "/boot/grub/grub.cfg", however, it looks like ' \
        ' you have no read permission.' $'\n'
      if [[ $(ask_yN 'Do you want to proceed with sudo?') =~ '0' ]]; then
        printf '%s\n' 'List kernel operation aborted'
        return 0
      fi
      super=1
    fi
  fi

  if [[ "$super" == 1 ]]; then
    output=$(sudo awk -F\' '/menuentry / {print $2}' "$grub_cfg")
  fi

  output=$(printf '%s\n' "$output" | grep recovery -v | grep with | awk -F" " '{print $NF}')

  while read -r kernel; do
    if [[ -f "$prefix/boot/vmlinuz-$kernel" && ! "$kernel" =~ .*\.old$ ]]; then
      _available_kernels+=("$kernel")
    fi
  done <<< "$output"
}

function reboot_machine()
{
  local reboot="$1"
  local local="$2"
  local flag="$3"

  [[ "$local" == 'local' ]] && sudo_cmd='sudo -E '

  if [[ "$reboot" == '1' ]]; then
    cmd="$sudo_cmd"'reboot'
    cmd_manager "$flag" "$cmd"
  fi
}

function install_modules()
{
  local module_name="$1"
  local flag="$2"
  local modules_path
  local ret
  local tar_cmd

  flag=${flag:-'SILENT'}

  modules_path="$KW_DEPLOY_TMP_FILE/$module_name"

  if [[ ! -f "$modules_path" ]]; then
    return 2 # ENOENT
  fi

  tar_cmd="tar --directory='/lib/modules' --extract --file='$modules_path'"

  cmd_manager "$flag" "$tar_cmd"
  ret="$?"

  if [[ "$ret" != 0 ]]; then
    printf '%s\n' 'Warning: Could not extract module archive.'
  fi
}

# Update bootloader API
# This function behaves like the template pattern, which means that we have a
# generic function name that will be called in a specific order to update the
# bootloader in the target machine. The trick here consists of first loading
# the target bootloader and specific distro script and executing the required
# update. Also notice that in some cases we need to update the initramfs.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/kwlib.sh` function `cmd_manager`
# @name Kernel name used during the deploy
# @target Target can be 1 (VM_TARGET), 2 (LOCAL_TARGET), and 3 (REMOTE_TARGET)
# @kernel_image_name Kernel binary file name
# @distro Target distro (e.g., arch or debian)
# @prefix Set a base prefix for searching for kernels.
function update_bootloader()
{
  local flag="$1"
  local name="$2"
  local target="$3"
  local kernel_image_name="$4"
  local distro="$5"
  local prefix="$6"
  local deploy_data_string
  local bootloader_path_prefix
  local ret
  local generate_initram=0

  [[ -n "$distro" ]] && generate_initram=1
  [[ -z "$prefix" ]] && prefix='/'

  if [[ "$target" == 'vm' ]]; then
    vm_mount
  fi

  if [[ "$target" != 'remote' || "$flag" == 'TEST_MODE' ]]; then
    bootloader_path_prefix="$KW_PLUGINS_DIR/kernel_install/"
  fi

  deploy_data_string=$(collect_deploy_info "$flag" "$target" "$prefix")

  declare -A deploy_data="($deploy_data_string)"

  case "${deploy_data['bootloader']}" in
    GRUB)
      bootloader_path_prefix+='grub.sh'
      ;;
    RPI_BOOTLOADER)
      bootloader_path_prefix+='rpi_bootloader.sh'
      ;;
    *)
      return 95 # ENOTSUP
      ;;
  esac

  # Load specific bootloader action
  . "$bootloader_path_prefix" --source-only

  # Each distro has their own way to generate their temporary root file system.
  if [[ "$generate_initram" == 1 ]]; then
    # For example, Debian uses update-initramfs, Arch uses mkinitcpio, etc
    cmd="generate_${distro}_temporary_root_file_system"
    cmd+=" $flag $name $target ${deploy_data['bootloader']} $path_prefix"

    cmd_manager "$flag" "$cmd"
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      complain 'Error when trying to generate the temporary root file system'
      [[ "$target" == 'vm' ]] && vm_umount
      exit "$ret"
    fi
  fi

  # Update bootloader
  run_bootloader_update "$flag" "$target" "$name" "$kernel_image_name"
  ret="$?"
  [[ "$target" == 'vm' ]] && vm_umount

  return "$ret"
}

function do_uninstall()
{
  local target="$1"
  local prefix="$2"
  local flag="$3"
  local modules_lib_path="${prefix}/lib/modules/${target}"
  local -a files_to_be_removed=(
    "${prefix}/etc/mkinitcpio.d/${target}.preset"
    "${prefix}/var/lib/initramfs-tools/${target}"
  )

  if [[ -z "$target" ]]; then
    printf '%s\n' 'No parameter, nothing to do'
    exit 22 # EINVAL
  fi

  to_remove_from_boot=$(find "${prefix}/boot/" -name "*$target*" | sort)
  # shellcheck disable=SC2068
  for element in ${to_remove_from_boot[@]}; do
    if [[ -f "$element" ]]; then
      printf ' %s\n' "Removing: $element"
      cmd_manager "$flag" "rm $element"
    else
      printf ' %s\n' "Can't find $element"
    fi
  done

  for del_file in "${files_to_be_removed[@]}"; do
    if [[ -f "$del_file" ]]; then
      printf ' %s\n' "Removing: $del_file"
      cmd_manager "$flag" "rm $del_file"
    else
      printf ' %s\n' "Can't find $del_file"
    fi
  done

  if [[ -d "$modules_lib_path" && "$modules_lib_path" != '/lib/modules' ]]; then
    printf ' %s\n' "Removing: $modules_lib_path"
    cmd_manager "$flag" "rm -rf $modules_lib_path"
  else
    printf ' %s\n' "Can't find $modules_lib_path"
  fi
}

function kernel_uninstall()
{
  local reboot="$1"
  local target="$2"
  local kernel_list_string="$3"
  local flag="$4"
  local force="$5"
  local prefix="$6"
  local update_grub=0

  cmd_manager "$flag" "sudo mkdir -p $REMOTE_KW_DEPLOY"
  cmd_manager "$flag" "sudo touch '$INSTALLED_KERNELS_PATH'"

  kernel_list_string=$(printf '%s' "$kernel_list_string" | tr --delete ' ')

  if [[ -z "$kernel_list_string" ]]; then
    printf '%s\n' 'Invalid argument'
    exit 22 #EINVAL
  fi

  IFS=', ' read -r -a kernel_names <<< "$kernel_list_string"
  for kernel in "${kernel_names[@]}"; do
    cmd="sudo grep -q '$kernel' '$INSTALLED_KERNELS_PATH'"
    cmd_manager "$flag" "$cmd"
    if [[ "$?" != 0 && -z "$force" ]]; then
      printf '%s\n' "$kernel not managed by kw. Use --force/-f to uninstall anyway."
      continue # EINVAL
    fi

    printf '%s\n' "Removing: $kernel"
    do_uninstall "$kernel" "$prefix" "$flag"

    # Clean from the log
    cmd_manager "$flag" "sudo sed -i '/$kernel/d' '$INSTALLED_KERNELS_PATH'"
    ((update_grub++))
  done

  # Each distro script should implement update_bootloader
  if [[ "$update_grub" -gt 0 ]]; then
    #printf '%s\n' "update_bootloader $kernel $target $flag"
    update_bootloader "$flag" "$kernel" "$target" "$kernel_image_name" '' "$path_prefix"

    # Reboot
    reboot_machine "$reboot" "$target" "$flag"
  fi
}

# Install kernel
function install_kernel()
{
  local name="$1"
  local distro="$2"
  local kernel_image_name="$3"
  local reboot="$4"
  local architecture="$5"
  local target="$6"
  local flag="$7"
  local sudo_cmd=''
  local cmd=''
  local path_prefix=''
  local verbose_cp

  flag=${flag:-'SILENT'}
  target=${target:-'remote'}

  [[ "$flag" == 'VERBOSE' ]] && verbose_cp='-v'

  if [[ "$target" == 'local' ]]; then
    sudo_cmd='sudo -E'
  fi

  if [[ -z "$name" ]]; then
    printf '%s\n' 'Invalid name'
    return 22
  fi

  if [[ "$target" == 'vm' ]]; then
    # Check if vm is mounted and get its path
    if [[ $(findmnt "${configurations[mount_point]}") ]]; then
      path_prefix="${configurations[mount_point]}"
      INSTALLED_KERNELS_PATH="$path_prefix/$INSTALLED_KERNELS_PATH"
      # Copy config file
      cmd_manager "$flag" "cp $verbose_cp .config $path_prefix/boot/config-$name"
    else
      complain 'Did you check if your VM is mounted?'
      return 125 # ECANCELED
    fi
  fi

  # Copy kernel image
  if [[ -f "$path_prefix/boot/vmlinuz-$name" ]]; then
    cmd="$sudo_cmd cp $path_prefix/boot/vmlinuz-$name $path_prefix/boot/vmlinuz-$name.old"
    cmd_manager "$flag" "$cmd"
  fi

  if [[ "$target" == 'remote' ]]; then
    cmd="$sudo_cmd tar -xaf ${KW_DEPLOY_TMP_FILE}/${name}_boot.tar"
    cmd+=" --directory=/ --no-same-owner"
    cmd_manager "$flag" "$cmd"
  fi

  # Each distro has their own way to update their bootloader
  update_bootloader "$flag" "$name" "$target" "$kernel_image_name" "$distro" "$path_prefix"
  ret="$?"

  if [[ "$ret" != 0 ]]; then
    complain 'kw was not able to update the target bootloader'
    [[ "$target" == 'vm' ]] && vm_umount
    exit "$ret"
  fi

  # In case vm is umounted for other commands
  [[ "$target" == 'vm' ]] && vm_mount

  # Registering a new kernel
  if [[ ! -f "$INSTALLED_KERNELS_PATH" ]]; then
    cmd_manager "$flag" "touch $INSTALLED_KERNELS_PATH"
  fi

  # See shellcheck warning SC2024: sudo doesn't affect redirects. That
  # is why we use tee. Also note that the stdin is passed to the eval
  # inside cmd_manager.
  cmd="grep -Fxq $name $INSTALLED_KERNELS_PATH"
  cmd_manager "$flag" "$cmd"
  if [[ "$?" != 0 ]]; then
    cmd="$sudo_cmd tee -a '$INSTALLED_KERNELS_PATH' > /dev/null"
    printf '%s\n' "$name" | cmd_manager "$flag" "$cmd"
  fi

  # Reboot
  if [[ "$target" != 'vm' && "$reboot" == '1' ]]; then
    cmd="$sudo_cmd reboot"
    reboot_machine "$reboot" "$target" "$flag"
  fi

  # If VM is mounted, umount before update boot loader
  if [[ "$target" == 'vm' ]]; then
    [[ $(findmnt "${configurations[mount_point]}") ]] && vm_umount
  fi
}
