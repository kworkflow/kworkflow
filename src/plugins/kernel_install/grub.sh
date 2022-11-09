# This file is specific to the GRUB bootloader, and since it is part of kw, it
# follows the bootloader API. In other words, we have two entry point
# functions:
# 1. run_bootloader_update: Update GRUB in a local and remote machine.
# 2. run_bootloader_for_vm: Update GRUB in a virtual machine.

declare -g DEFAULT_GRUB_CMD_UPDATE='grub-mkconfig -o /boot/grub/grub.cfg'

# Some distributions, such as Fedora, use GRUB2 as the default bootloader. On
# those systems, grub-mkconfig command is replaced by grub2-mkconfig. This function
# checks if the grub-mkconfig command exists and if doesn't, the default grub
# update command is set to grub2-mkconfig.
#
# Returns:
# 0 if a grub update command exists and 2 otherwise.
function define_grub_cmd_update()
{
  local grub_cmd='grub-mkconfig'
  local grub2_cmd='grub2-mkconfig'

  if command_exists 'update-grub'; then
    DEFAULT_GRUB_CMD_UPDATE='update-grub'
    return 0
  fi

  if ! command_exists "$grub_cmd"; then
    if ! command_exists "$grub2_cmd"; then
      return 2 # ENOENT
    fi
    DEFAULT_GRUB_CMD_UPDATE="grub2-mkconfig -o /boot/grub2/grub.cfg"
  fi

  return 0
}

# Update grub bootloader in a target machine.
function run_bootloader_update()
{
  local flag="$1"
  local target="$2"
  local cmd_grub
  local cmd_sudo
  local total_count

  if [[ "$target" == 'local' ]]; then
    cmd_sudo='sudo -E '
    cmd_grub+="$cmd_sudo"
  elif [[ "$target" == 'vm' ]]; then
    run_bootloader_for_vm "$flag"
    return "$?"
  fi

  define_grub_cmd_update
  if [[ "$?" -gt 0 ]]; then
    complain "There is no grub-mkconfig command in the system."
    return 125 # ECANCELED
  fi

  cmd_grub+="$DEFAULT_GRUB_CMD_UPDATE"

  if [[ "$flag" != 'VERBOSE' ]]; then
    total_count=$(total_of_installed_kernels "$flag" "$target")
    total_count=$((total_count * 2 + 7))
    # TODO: For some reason, this is not working via ssh
    #cmd_grub+=" |& pv -p --line-mode --size $total_count > /dev/null"
  fi

  cmd_manager "$flag" "$cmd_grub"
}

function total_of_installed_kernels()
{
  local flag="$1"
  local target="$2"
  local total_count
  local find_cmd="find /boot -name 'vmlinuz*' | wc -l"

  [[ "$target" == 'local' ]] && find_cmd="sudo -E $find_cmd"

  [[ "$flag" != 'TEST_MODE' ]] && total_count=$(eval "$find_cmd")
  total_count=$((total_count * 2 + 7))

  printf '%d' "$total_count"
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

  if [[ ! -f "${vm_config[qemu_path_image]}" ]]; then
    complain "There is no VM in ${vm_config[qemu_path_image]}"
    return 125 # ECANCELED
  fi

  # For executing libguestfs commands we need to umount the vm
  if [[ $(findmnt "${vm_config[mount_point]}") ]]; then
    vm_umount
  fi

  define_grub_cmd_update
  if [[ "$?" -gt 0 ]]; then
    complain "There is no grub-mkconfig command in the system."
    return 125 # ECANCELED
  fi

  cmd="guestfish --rw -a ${vm_config[qemu_path_image]} run \
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
