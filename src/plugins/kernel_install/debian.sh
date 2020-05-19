# Kworkflow treats this script as a plugin for installing a new Kernel or
# module on ArchLinux. It is essential to highlight that this file follows an
# API that can be seen in the "deploy.sh" file, if you make any change here,
# you have to do it inside the install_modules() and install_kernel().
#
# Note: We use this script for Debian and Ubuntu

# Install modules
function install_modules()
{
  local module_target="$1"
  local ret

  if [[ -z "$module_target" ]]; then
    module_target=*.tar
  fi

  tar -C /lib/modules -xf "$module_target"
  ret="$?"

  if [[ "$ret" != 0 ]]; then
    echo "Warning: Couldn't extract module archive."
  fi
}

# Update initramfs and grub on VM using Guestfish
#
# After configuring the handle (adding a disk image in write mode), the
# guestfish performs the followed steps: (1) mount image;
# (2) update-initramfs (needs kernel image name); (3) create a dummy device.map
# that tells Grub to look for /dev/sda; (4) install and update grub.
#
# Note: The virtual machine must be turned off and umounted before you use this
# command, and disk images must not be edited concurrently.
#
# @name Kernel name for the deploy
# @cmd_grub Command to update grub
#
# Returns: if there is no VM in the expected path, the function is
# canceled and returns 125
function vm_update_boot_loader()
{
  local name="$1"
  local cmd_grub="$2"
  local cmd=""
  local mount_root=": mount /dev/sda1 /"
  local mkdir_init=": mkdir-p /etc/initramfs-tools"
  local cmd_init="update-initramfs -c -k $name"
  local mkdir_grub=": mkdir-p /boot/grub"
  local setup_grub=": write /boot/grub/device.map '(hd0) /dev/sda'"
  local grub_install="grub-install --root-directory=/ --target=i386-pc --force /dev/sda1"
  local flag

  flag=${flag:-"SILENT"}

  sleep 0.5s

  cmd="guestfish --rw -a ${configurations[qemu_path_image]} run \
      $mount_root \
      $mkdir_init : command '$cmd_init' \
      $setup_grub : command '$grub_install' : command '$cmd_grub'"

  if [[ -f "${configurations[qemu_path_image]}" ]]; then
    warning " -> Updating initramfs and grub for $name on VM. This can take a few minutes."
    {
      cmd_manager "$flag" "$cmd"
    } 1> /dev/null # No visible stdout but still shows errors
    say "Done."
  else
    complain "There is no VM in ${configurations[qemu_path_image]}"
    return 125 # ECANCELED
  fi

  return 0
}

# Update boot loader API
function update_boot_loader()
{
  local name="$1"
  local target="$2"
  local flag="$3"

  if [[ "$target" == 'local' ]]; then
    sudo_cmd="sudo -E"
  fi

  cmd="$sudo_cmd grub-mkconfig -o /boot/grub/grub.cfg"

  # Update grub
  if [[ "$target" == 'vm' ]] ; then
    vm_update_boot_loader "$name" "$cmd"
  else
    cmd_manager "$flag" "$cmd"
  fi
}

# Install kernel
function install_kernel()
{
  local name="$1"
  local reboot="$2"
  local target="$3"
  local architecture="$4"
  local flag="$5"
  local sudo_cmd=""
  local cmd=""
  local path_prefix=""

  flag=${flag:-"SILENT"}

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
      cp -v .config "$path_prefix/boot/config-$name"
    else
      complain "Did you check if your VM is mounted?"
      return 125 # ECANCELED
    fi
  fi

  # Copy kernel image
  if [[ -f "$path_prefix/boot/vmlinuz-$name" ]]; then
    cmd="$sudo_cmd cp $path_prefix/boot/vmlinuz-$name $path_prefix/boot/vmlinuz-$name.old"
    cmd_manager "$flag" "$cmd"
  fi

  if [[ ! -z "$target" ]]; then
    [[ ! -z "$architecture" ]] && architecture="x86_64"
    cmd="$sudo_cmd cp -v arch/$architecture/boot/bzImage $path_prefix/boot/vmlinuz-$name"
    cmd_manager "$flag" "$cmd"
  else
    cmd="$sudo_cmd cp -v vmlinuz-$name $path_prefix/boot/vmlinuz-$name"
    cmd_manager "$flag" "$cmd"
  fi

  if [[ "$target" != 'vm' ]]; then
    # Update initramfs
    cmd="$sudo_cmd update-initramfs -c -k $name"
    cmd_manager "$flag" "$cmd"
  fi

  # If VM is mounted, umount before update boot loader
  if [[ "$target" == 'vm' ]]; then
    [[ $(findmnt "${configurations[mount_point]}") ]] && vm_umount
  fi

  update_boot_loader "$name" "$target" "$flag"

  # Reboot
  if [[ "$target" != 'vm' && "$reboot" == "1" ]]; then
    cmd="$sudo_cmd reboot"
    cmd_manager "$flag" "$cmd"
  fi
}
