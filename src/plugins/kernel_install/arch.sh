# Kworkflow treats this script as a plugin for installing a new Kernel or
# module on ArchLinux. It is essential to highlight that this file follows an
# API that can be seen in the "deploy.sh" file, if you make any change here,
# you have to do it inside the install_modules() or install_kernel().
#
# Note: We use this script for ArchLinux and Manjaro

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

# Make initcpio and update grub on VM using Guestfish
#
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
  local cmd_grub="$2"
  local ret=0
  local cmd=""
  local mount_root=": mount /dev/sda1 /"
  local cmd_init="dracut --regenerate-all -f"
  local mkdir_grub=": mkdir-p /boot/grub"
  local setup_grub=": write /boot/grub/device.map '(hd0,1) /dev/sda'"
  local grub_install="grub-install --directory=/usr/lib/grub/i386-pc --target=i386-pc --boot-directory=/boot --recheck --debug /dev/sda"
  local flag

  flag=${flag:-"SILENT"}

  sleep 0.5s

  cmd="guestfish --rw -a ${configurations[qemu_path_image]} run \
      $mount_root : command '$cmd_init' \
      $mkdir_grub $setup_grub : command '$grub_install' \
      : command '$cmd_grub'"

  if [[ -f ${configurations[qemu_path_image]} ]]; then
    warning " -> Updating grub and boot files for $name. This can take a few minutes. Please, be patient..."
    {
      cmd_manager "$flag" "$cmd"
    } > /dev/null
    say "Done."
  else
    complain "There is no VM in ${configurations[qemu_path_image]}"
    return 125 # ECANCELED
  fi
}

# Update boot loader API
function update_boot_loader()
{
  local name="$1"
  local target="$2"
  local flag="$3"

  if [[ ! -z "$target" ]]; then
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
  local kernel_image_name="$2"
  local reboot="$3"
  local architecture="$4"
  local target="$5"
  local flag="$6"
  local sudo_cmd=""
  local LOCAL_KW_ETC="$KW_ETC_DIR/template_mkinitcpio.preset"
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
    [[ -z "$architecture" ]] && architecture="x86_64"
    cmd="$sudo_cmd cp -v arch/$architecture/boot/$kernel_image_name /boot/vmlinuz-$name"
    cmd_manager "$flag" "$cmd"
  else
    cmd="$sudo_cmd cp -v vmlinuz-$name $path_prefix/boot/vmlinuz-$name"
    cmd_manager "$flag" "$cmd"
  fi

  # Update mkinitcpio
  if [[ ! -z "$target" ]]; then
    cmd="$sudo_cmd cp -v $LOCAL_KW_ETC $path_prefix/etc/mkinitcpio.d/$name.preset"
    cmd_manager "$flag" "$cmd"
    cmd="$sudo_cmd sed -i -e \"s/NAME/$name/g\" \"$path_prefix/etc/mkinitcpio.d/$name.preset\""
    cmd_manager "$flag" "$cmd"
  else
    cp -v "$name.preset" $path_prefix/etc/mkinitcpio.d/
  fi

  if [[ "$target" != 'local' ]]; then
    # Update mkinitcpio
    cmd="$sudo_cmd mkinitcpio -p $name"
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
