# This file is specific to the GRUB bootloader, and since it is part of kw, it
# follows the bootloader API. In other words, we have two entry point
# functions:
# 1. run_bootloader_update: Update GRUB in a local and remote machine.
# 2. run_bootloader_for_vm: Update GRUB in a virtual machine.

declare -rg DEFAULT_GRUB_CMD_UPDATE='grub-mkconfig -o /boot/grub/grub.cfg'

# Update grub bootloader in a target machine.
function run_bootloader_update()
{
  local flag="$1"
  local target="$2"
  local cmd_grub

  if [[ "$target" == 'local' ]]; then
    cmd_grub='sudo -E '
  elif [[ "$target" == 'vm' ]]; then
    run_bootloader_for_vm "$flag"
    return "$?"
  fi

  cmd_grub+="$DEFAULT_GRUB_CMD_UPDATE"
  cmd_manager "$flag" "$cmd_grub"
}

# After configuring the handle (adding a disk image in write mode), the
# guestfish performes the followed steps: (1) mount image; (2) updates kernel
# images list; (3) create a dummy device.map that tells Grub to look for
# /dev/sda; (4) install and update grub.
#
# Note: The virtual machine must be shut down and umounted before you use this
# command, and disk images must not be edited concurrently.
#
# @name Kernel name for the deploy
function run_bootloader_for_vm()
{
  local flag="$1"
  # We assume Debian as a default option
  local mount_root=': mount /dev/sda1 /'
  local mkdir_grub=': mkdir-p /boot/grub'
  local setup_grub=": write /boot/grub/device.map '(hd0,1) /dev/sda'"
  local grub_install='grub-install --directory=/usr/lib/grub/i386-pc --target=i386-pc --boot-directory=/boot --recheck --debug /dev/sda'
  local cmd_grub="$DEFAULT_GRUB_CMD_UPDATE"
  local cmd=''
  local ret=0

  flag=${flag:-'SILENT'}

  if [[ -f "${configurations[qemu_path_image]}" ]]; then
    complain "There is no VM in ${configurations[qemu_path_image]}"
    return 125 # ECANCELED
  fi

  cmd="guestfish --rw -a ${configurations[qemu_path_image]} run \
      $mount_root \
      $mkdir_grub $setup_grub : command '$grub_install' \
      : command '$cmd_grub'"

  warning " -> Updating grub for $name on VM. This can take a few minutes."

  cmd_manager "$flag" 'sleep 0.5s'
  {
    cmd_manager "$flag" "$cmd"
    ret="$?"
  } 1> /dev/null # No visible stdout but still shows errors

  # TODO: The below line is here for test purpose. We need a better way to
  # do that.
  [[ "$flag" == 'TEST_MODE' ]] && printf '%s\n' "$cmd"

  say 'Done.'

  return "$ret"
}
