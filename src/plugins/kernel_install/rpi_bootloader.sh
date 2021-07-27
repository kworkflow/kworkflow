# List available kernels
# @single_line If this option is set to 1 this function will display all
#   available kernels in a single line separated by commas. If it gets 0 it
#   will display each kernel name by line.
# @prefix Set a base prefix for searching for kernels.
function list_installed_kernels()
{
  local single_line="$1"
  local prefix="$2"

  if [[ $single_line == 1 ]]; then
    find "$prefix"/boot/*.img -exec basename '{}' '.img' ';' | tr '\n' ' '
  else
    find "$prefix"/boot/*.img -exec basename '{}' '.img' ';'
  fi
}

function do_uninstall()
{
  local kernel_to_be_uninstalled="$1"
  local prefix="$2"
  local flag="$3"
  cmd_manager "$flag" "sudo rm $prefix/boot/$kernel_to_be_uninstalled.img"
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
  local sudo_cmd=""
  local cmd=""
  local path_prefix=""

  flag=${flag:-'SILENT'}
  target=${target:-'remote'}

  if [[ "$target" == 'local' ]]; then
    sudo_cmd="sudo -E"
  fi

  if [[ -z "$name" ]]; then
    echo "Invalid name"
    return 22
  fi

  if [[ "$target" == 'vm' ]]; then
    # Check if vm is mounted and get its path
    if [[ $(findmnt "${configurations[mount_point]}") ]]; then
      path_prefix="${configurations[mount_point]}"
      # Copy config file
      cmd_manager "$flag" "cp -v .config $path_prefix/boot/config-$name"
    else
      complain "Did you check if your VM is mounted?"
      return 125 # ECANCELED
    fi
  fi

  # Copy kernel image
  if [[ -f "$path_prefix/boot/$name" ]]; then
    cmd="$sudo_cmd cp $path_prefix/boot/$name $path_prefix/boot/$name.old"
    cmd_manager "$flag" "$cmd"
  fi

  if [[ "$target" != 'remote' ]]; then
    cmd="$sudo_cmd cp -v arch/$architecture/boot/$kernel_image_name $path_prefix/boot/$name.img"
    cmd_manager "$flag" "$cmd"
  else
    cmd="$sudo_cmd cp -v $name $path_prefix/boot/$name.img"
    cmd_manager "$flag" "$cmd"
  fi

  update_rpi_boot_loader "$name"

  # Reboot
  if [[ "$target" != 'vm' && "$reboot" == "1" ]]; then
    cmd="$sudo_cmd reboot"
    cmd_manager "$flag" "$cmd"
  fi
}

# Update boot loader API
function update_rpi_boot_loader()
{
  local name="$1"
  # The kernel to be booted is determined by the `kernel` parameter in the
  # config.txt file for more information please refer to the oficial documentation
  # https://www.raspberrypi.org/documentation/configuration/config-txt/boot.md

  if grep --quiet 'kernel' /boot/config.txt; then
    sudo sed -ri "/kernel/s/=.+/=$name/g" /boot/config.txt
  else
    echo "kernel=$name" | sudo tee -a /boot/config.txt
  fi
}
