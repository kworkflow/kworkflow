declare -g kw_path='/opt/kw'
declare -g kw_tmp_files='/tmp/kw'
declare -g INSTALLED_KERNELS_PATH="$kw_path/INSTALLED_KERNELS"

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
    *)
      printf '%s\n' "$@"
      ;;
  esac

  eval "$@"
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

  cmd_manager "$flag" "sudo mkdir -p $kw_path"
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

  modules_path="$kw_tmp_files/$module_name"

  if [[ ! -f "$modules_path" ]]; then
    return 2 # ENOENT
  fi

  cmd_manager "$flag" "tar -C /lib/modules -xf $modules_path"
  ret="$?"

  if [[ "$ret" != 0 ]]; then
    printf '%s\n' 'Warning: Could not extract module archive.'
  fi
}

# Update boot loader API
function update_boot_loader()
{
  local name="$1"
  local distro="$2"
  local target="$3"
  local cmd_init="$4"
  local setup_grub="$5"
  local grub_install="$6"
  local flag="$7"

  if [[ "$target" == 'local' ]]; then
    sudo_cmd='sudo -E '
  fi

  cmd_grub="$sudo_cmd"'grub-mkconfig -o /boot/grub/grub.cfg'

  # Update grub
  if [[ "$target" == 'vm' ]]; then
    vm_update_boot_loader "$name" "$distro" "$cmd_grub" "$cmd_init" "$setup_grub" "$grub_install" "$flag"
  else
    cmd_manager "$flag" "$cmd_grub"
  fi
}

# After configuring the handle (adding a disk image in write mode), the
# guestfish performes the followed steps: (1) mount image;
# (2) dracut (updates kernel images list); (3) create a dummy device.map
# that tells Grub to look for /dev/sda; (4) install and update grub.
#
# Note: The virtual machine must be shut down and umounted before you use this
# command, and disk images must not be edited concurrently.
#
# @name Kernel name for the deploy
# @cmd_grub Command to update grub
# mkinitcpio -g /boot/initramfs-linux.img -k /boot/vmlinuz-linux
function vm_update_boot_loader()
{
  local name="$1"
  local distro="$2"
  local cmd_grub="$3"
  local cmd_init="$4"
  local setup_grub="$5"
  local grub_install="$6"
  local flag="$7"
  local cmd=''
  # We assume Debian as a default option
  local mount_root=': mount /dev/sda1 /'
  local mkdir_init=': mkdir-p /etc/initramfs-tools'

  flag=${flag:-'SILENT'}

  if [[ -z "$distro" ]]; then
    complain 'No distro specified. We are unable to deploy'
    return 22 # EINVAL
  fi

  cmd="guestfish --rw -a ${configurations[qemu_path_image]} run \
      $mount_root \
      $mkdir_init : command '$cmd_init' \
      $setup_grub : command '$grub_install' : command '$cmd_grub'"

  if [[ "$distro" == 'arch' ]]; then
    local mkdir_grub=': mkdir-p /boot/grub'

    cmd="guestfish --rw -a ${configurations[qemu_path_image]} run \
        $mount_root : command '$cmd_init' \
        $mkdir_grub $setup_grub : command '$grub_install' \
        : command '$cmd_grub'"
  fi

  if [[ -f "${configurations[qemu_path_image]}" ]]; then
    warning " -> Updating initramfs and grub for $name on VM. This can take a few minutes."
    cmd_manager "$flag" 'sleep 0.5s'
    {
      cmd_manager "$flag" "$cmd"
    } 1> /dev/null # No visible stdout but still shows errors

    # TODO: The below line is here for test purpose. We need a better way to
    # do that.
    [[ "$flag" == 'TEST_MODE' ]] && printf '%s\n' "$cmd"

    say 'Done.'
  else
    complain "There is no VM in ${configurations[qemu_path_image]}"
    return 125 # ECANCELED
  fi

  return 0
}

function do_uninstall()
{
  local target="$1"
  local prefix="$2"
  local flag="$3"
  local kernelpath="$prefix/boot/vmlinuz-$target"
  local initrdpath="$prefix/boot/initrd.img-$target"
  local modulespath="$prefix/lib/modules/$target"
  local libpath="$prefix/var/lib/initramfs-tools/$target"
  local configpath="$prefix/boot/config-$target"

  if [[ -z "$target" ]]; then
    printf '%s\n' 'No parameter, nothing to do'
    exit 0
  fi

  if [[ -f "$kernelpath" ]]; then
    printf ' %s\n' "Removing: $kernelpath"
    cmd_manager "$flag" "rm $kernelpath"
  else
    printf ' %s\n' "Can't find $kernelpath"
  fi

  if [[ -f "$kernelpath.old" ]]; then
    printf ' %s\n' "Removing: $kernelpath.old"
    cmd_manager "$flag" "rm $kernelpath.old"
  else
    printf ' %s\n' "Can't find $kernelpath.old"
  fi

  if [[ -f "$initrdpath" ]]; then
    printf ' %s\n' "Removing: $initrdpath"
    cmd_manager "$flag" "rm -rf $initrdpath"
  else
    printf ' %s\n' "Can't find $initrdpath"
  fi

  if [[ -d "$modulespath" && "$modulespath" != "/lib/modules" ]]; then
    printf ' %s\n' "Removing: $modulespath"
    cmd_manager "$flag" "rm -rf $modulespath"
  else
    printf ' %s\n' "Can't find $modulespath"
  fi

  if [[ -f "$libpath" ]]; then
    printf ' %s\n' "Removing: $libpath"
    cmd_manager "$flag" "rm -rf $libpath"
  else
    printf ' %s\n' "Can't find $libpath"
  fi

  if [[ -f "$configpath" ]]; then
    printf ' %s\n' "Removing: $configpath"
    cmd_manager "$flag" "rm $configpath"
  else
    printf ' %s\n' "Can't find $configpath"
  fi
}

function kernel_uninstall()
{
  local reboot="$1"
  local local_deploy="$2"
  local kernel="$3"
  local flag="$4"
  local force="$5"
  local prefix="$6"
  local update_grub=0

  cmd_manager "$flag" "sudo mkdir -p $kw_path"
  cmd_manager "$flag" "sudo touch '$INSTALLED_KERNELS_PATH'"

  kernel=$(printf '%s' "$kernel" | tr --delete ' ')

  if [[ -z "$kernel" ]]; then
    printf '%s\n' 'Invalid argument'
    exit 22 #EINVAL
  fi

  IFS=', ' read -r -a kernel_names <<< "$kernel"
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

  # Each distro script should implement update_boot_loader
  if [[ "$update_grub" -gt 0 ]]; then
    printf '%s\n' "update_boot_loader $kernel $local_deploy $flag"
    update_boot_loader "$kernel" "$local_deploy" '' '' '' '' "$flag"

    # Reboot
    reboot_machine "$reboot" "$local_deploy" "$flag"
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

  flag=${flag:-'SILENT'}
  target=${target:-'remote'}

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
      # Copy config file
      cmd_manager "$flag" "cp -v .config $path_prefix/boot/config-$name"
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

  if [[ "$target" != 'remote' ]]; then
    [[ -z "$architecture" ]] && architecture='x86_64'
    cmd="$sudo_cmd cp -v arch/$architecture/boot/$kernel_image_name $path_prefix/boot/vmlinuz-$name"
    cmd_manager "$flag" "$cmd"
  else
    cmd="$sudo_cmd cp -v $kw_tmp_files/vmlinuz-$name $path_prefix/boot/vmlinuz-$name"
    cmd_manager "$flag" "$cmd"
  fi

  # Each distro has their own way to generate their temporary root file system.
  # For example, Debian uses update-initramfs, Arch uses mkinitcpio, etc
  cmd="generate_${distro}_temporary_root_file_system"
  eval "$cmd" "$name" "$target" "$flag" "$path_prefix"

  # If VM is mounted, umount before update boot loader
  if [[ "$target" == 'vm' ]]; then
    [[ $(findmnt "${configurations[mount_point]}") ]] && vm_umount
  fi

  # Each distro has their own way to update their bootloader
  eval "update_$distro""_boot_loader $name $target $flag"

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
    cmd="sudo tee -a '$INSTALLED_KERNELS_PATH' > /dev/null"
    printf '%s\n' "$name" | cmd_manager "$flag" "$cmd"
  fi

  # Reboot
  if [[ "$target" != 'vm' && "$reboot" == '1' ]]; then
    cmd="$sudo_cmd reboot"
    reboot_machine "$reboot" "$target" "$flag"
  fi
}
