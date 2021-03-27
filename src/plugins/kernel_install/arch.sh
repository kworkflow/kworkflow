# Kworkflow treats this script as a plugin for installing a new Kernel or
# module on ArchLinux. It is essential to highlight that this file follows an
# API that can be seen in the "deploy.sh" file, if you make any change here,
# you have to do it inside the install_modules() or install_kernel().
#
# Note: We use this script for ArchLinux and Manjaro

# Make initcpio and update grub on VM using Guestfish

# Update boot loader API
function update_arch_boot_loader()
{
  local name="$1"
  local target="$2"
  local flag="$3"
  local cmd_init="dracut --regenerate-all -f"
  local setup_grub=": write /boot/grub/device.map '(hd0,1) /dev/sda'"
  local grub_install="grub-install --directory=/usr/lib/grub/i386-pc --target=i386-pc --boot-directory=/boot --recheck --debug /dev/sda"

  update_boot_loader "$name" 'arch' "$target" "$cmd_init" "$setup_grub" "$grub_install"  "$flag"
}

function generate_arch_temporary_root_file_system
{
  local name="$1"
  local target="$2"
  local flag="$3"
  local path_prefix="$4"
  local cmd=""
  local sudo_cmd=""
  local LOCAL_KW_ETC="$KW_ETC_DIR/template_mkinitcpio.preset"

  if [[ "$target" == 'local' ]]; then
    sudo_cmd="sudo -E"
  fi

  # Update mkinitcpio
  if [[ "$target" != 'remote' ]]; then
    cmd="$sudo_cmd cp -v $LOCAL_KW_ETC $path_prefix/etc/mkinitcpio.d/$name.preset"
    cmd_manager "$flag" "$cmd"
    cmd="$sudo_cmd sed -i -e \"s/NAME/$name/g\" \"$path_prefix/etc/mkinitcpio.d/$name.preset\""
    cmd_manager "$flag" "$cmd"
  else
    cp -v "$name.preset" $path_prefix/etc/mkinitcpio.d/
  fi

  if [[ "$target" != 'vm' ]]; then
    # Update mkinitcpio
    cmd="$sudo_cmd mkinitcpio -p $name"
    cmd_manager "$flag" "$cmd"
  fi
}
