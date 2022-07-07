# Kworkflow treats this script as a plugin for installing a new Kernel or
# module in a target system. It is essential to highlight that this file
# follows an API that can be seen in the "deploy.sh" file, if you make any
# change here, you have to do it inside the install_modules() and
# install_kernel().
#
# Note: We use this script for Fedora based distros

# Fedora package names
declare -ag required_packages=(
  'rsync'
  'screen'
  'pv'
  'bzip2'
  'lzip'
  'xz'
  'lzop'
  'zstd'
)

# Fedora package manager command
declare -g package_manager_cmd='dnf install -y'

function generate_fedora_temporary_root_file_system()
{
  local flag="$1"
  local name="$2"
  local target="$3"
  local bootloader_type="$4"
  local path_prefix="$5"
  local cmd='dracut --force --kver'
  local cmd_prefix=''
  local grub_regex='s/GRUB_ENABLE_BLSCFG=true/GRUB_ENABLE_BLSCFG=false/g'
  local prefix='/'

  if [[ -n "$path_prefix" ]]; then
    prefix="${path_prefix}"
  fi

  # We do not support initramfs outside grub scope
  [[ "$bootloader_type" != 'GRUB' ]] && return

  cmd+=" $name"

  if [[ "$target" == 'local' ]]; then
    cmd_prefix="sudo -E"
  fi

  if [[ "$target" != 'vm' ]]; then
    cmd_manager "$flag" "$cmd_prefix grub2-editenv - unset menu_auto_hide"
    cmd_manager "$flag" "$cmd_prefix sed -i -e '$grub_regex' /etc/default/grub"

    # Update initramfs
    cmd_manager "$flag" "$cmd_prefix $cmd"
  else
    generate_rootfs_with_libguestfs "$flag" "$name"
  fi
}

function generate_rootfs_with_libguestfs()
{
  local flag="$1"
  local name="$2"
  local mount_root=': mount /dev/sda1 /'
  local cmd_init="dracut --force --kver $name"

  flag=${flag:-'SILENT'}

  if [[ ! -f "${vm_config[qemu_path_image]}" ]]; then
    complain "There is no VM in ${vm_config[qemu_path_image]}"
    return 125 # ECANCELED
  fi

  # For executing libguestfs commands we need to umount the vm
  if [[ $(findmnt "${vm_config[mount_point]}") ]]; then
    vm_umount
  fi

  cmd="guestfish --rw -a ${vm_config[qemu_path_image]} run \
      $mount_root : command '$cmd_init'"

  warning " -> Generating rootfs $name on VM. This can take a few minutes."

  cmd_manager "$flag" 'sleep 0.5s'
  {
    cmd_manager "$flag" "$cmd"
  } 1> /dev/null # No visible stdout but still shows errors

  # TODO: The below line is here for test purpose. We need a better way to
  # do that.
  [[ "$flag" == 'TEST_MODE' ]] && printf '%s\n' "$cmd"

  say 'Done.'

  return 0
}
