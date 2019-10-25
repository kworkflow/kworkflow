# Kworkflow treats this script as a plugin for installing a new Kernel or
# module on ArchLinux. It is essential to highlight that this file follows an
# API that can be seen in the "deploy.sh" file, if you make any change here,
# you have to do it inside the install_modules() and install_kernel().

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

# Install kernel
function install_kernel()
{
  local name="$1"
  local reboot="$2"

  if [[ -z "$name" ]]; then
    name="kw"
  fi

  # Copy kernel image
  if [[ -f "/boot/vmlinuz-$name" ]]; then
    cp "/boot/vmlinuz-$name" "/boot/vmlinuz-$name.old"
  fi

  cp -v "vmlinuz-$name" "/boot/vmlinuz-$name"
  # Update initramfs
  update-initramfs -c -k "$name"

  # Update grub
  grub-mkconfig -o /boot/grub/grub.cfg

  # Reboot
  if [[ "$reboot" = "1" ]]; then
    reboot
  fi
}
