# Kworkflow treats this script as a plugin for installing a new Kernel or
# module in a target system. It is essential to highlight that this file
# follows an API that can be seen in the "deploy.sh" file, if you make any
# change here, you have to do it inside the install_modules() and
# install_kernel().
#
# Note: We use this script for Debian based distros

# Update boot loader API
function update_debian_boot_loader()
{
  local name="$1"
  local target="$2"
  local flag="$3"
  local cmd_init="update-initramfs -c -k $name"
  local setup_grub=": write /boot/grub/device.map '(hd0) /dev/sda'"
  local grub_install="grub-install --root-directory=/ --target=i386-pc --force /dev/sda1"

  update_boot_loader "$name" 'debian' "$target" "$cmd_init" "$setup_grub" "$grub_install" "$flag"
}

function generate_debian_temporary_root_file_system()
{
  local name="$1"
  local target="$2"
  local flag="$3"
  local cmd=""
  local sudo_cmd=""

  if [[ "$target" == 'local' ]]; then
    sudo_cmd="sudo -E"
  fi

  if [[ "$target" != 'vm' ]]; then
    # Update initramfs
    cmd="$sudo_cmd update-initramfs -c -k $name"
    cmd_manager "$flag" "$cmd"
  fi
}
