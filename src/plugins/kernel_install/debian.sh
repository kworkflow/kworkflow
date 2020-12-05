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

# Update boot loader API
function update_boot_loader()
{
  local name="$1"
  local local="$2"
  local flag="$3"

  if [[ "$local" == 'local' ]]; then
    sudo_cmd="sudo -E"
  fi

  # Update grub
  cmd="$sudo_cmd grub-mkconfig -o /boot/grub/grub.cfg"
  cmd_manager "$flag" "$cmd"
}

# Install kernel
function install_kernel()
{
  local name="$1"
  local kernel_image_name="$2"
  local reboot="$3"
  local architecture="$4"
  local local="$5"
  local flag="$6"
  local sudo_cmd=""
  local cmd=""

  flag=${flag:-"SILENT"}

  if [[ ! -z "$local" ]]; then
    sudo_cmd="sudo -E"
  fi

  if [[ -z "$name" ]]; then
    echo "Invalid name"
    return 22
  fi

  # Copy kernel image
  if [[ -f "/boot/vmlinuz-$name" ]]; then
    cmd="$sudo_cmd cp /boot/vmlinuz-$name /boot/vmlinuz-$name.old"
    cmd_manager "$flag" "$cmd"
  fi

  if [[ ! -z "$local" ]]; then
    [[ -z "$architecture" ]] && architecture="x86_64"
    cmd="$sudo_cmd cp -v arch/$architecture/boot/$kernel_image_name /boot/vmlinuz-$name"
    cmd_manager "$flag" "$cmd"
  else
    cmd="$sudo_cmd cp -v vmlinuz-$name /boot/vmlinuz-$name"
    cmd_manager "$flag" "$cmd"
  fi

  # Update initramfs
  cmd="$sudo_cmd update-initramfs -c -k $name"
  cmd_manager "$flag" "$cmd"

  update_boot_loader "$name" "$local" "$flag"

  # Reboot
  if [[ "$reboot" = "1" ]]; then
    cmd="$sudo_cmd reboot"
    cmd_manager "$flag" "$cmd"
  fi
}
