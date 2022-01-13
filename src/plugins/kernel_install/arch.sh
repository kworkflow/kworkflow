# Kworkflow treats this script as a plugin for installing a new Kernel or
# module on ArchLinux. It is essential to highlight that this file follows an
# API that can be seen in the "deploy.sh" file, if you make any change here,
# you have to do it inside the install_modules() or install_kernel().
#
# Note: We use this script for ArchLinux and Manjaro

# ArchLinux package names
declare -ga required_packages=(
  'rsync'
  'screen'
)

# ArchLinux package manager
declare -g package_manager_cmd='yes | pacman -Syu'

# Make initcpio and update grub on VM using Guestfish
function generate_arch_temporary_root_file_system()
{
  local name="$1"
  local target="$2"
  local flag="$3"
  local path_prefix="$4"
  local cmd=''
  local sudo_cmd
  local template_path
  local mkinitcpio_destination_path
  local LOCAL_KW_ETC="$KW_ETC_DIR/template_mkinitcpio.preset"

  # Step 1: Generate specific preset file
  mkinitcpio_destination_path="$path_prefix/etc/mkinitcpio.d/$name.preset"
  template_path="$KW_ETC_DIR/template_mkinitcpio.preset"

  case "$target" in
    'local') # LOCAL_TARGET
      sudo_cmd='sudo -E'
      cmd="$sudo_cmd "
      ;;
    'remote') # REMOTE_TARGET
      template_path="$kw_path/template_mkinitcpio.preset"
      ;;
  esac

  # We will eval a command that uses sudo and redirection which can cause
  # errors. To avoid problems, let's use bash -c
  cmd+="bash -c \""
  cmd+="sed 's/NAME/$name/g' '$template_path' > $mkinitcpio_destination_path\""

  cmd_manager "$flag" "$cmd"

  # TODO: We need to handle VM
  if [[ "$target" != 'vm' ]]; then
    # Step 2: Make sure that we are generating a consistent modules.dep and map
    cmd="$sudo_cmd depmod --all $name"
    cmd_manager "$flag" "$cmd"

    # Step 3: Generate the initcpio file
    cmd="$sudo_cmd mkinitcpio --preset $name"
    cmd_manager "$flag" "$cmd"
  else
    generate_rootfs_with_libguestfs "$flag" "$name"
  fi
}

function generate_rootfs_with_libguestfs()
{
  local flag="$1"
  local name="$2"
  # We assume Debian as a default option
  local mount_root=': mount /dev/sda1 /'
  local cmd_init='dracut --regenerate-all -f'
  local ret=0

  flag=${flag:-'SILENT'}

  if [[ ! -f "${configurations[qemu_path_image]}" ]]; then
    complain "There is no VM in ${configurations[qemu_path_image]}"
    return 125 # ECANCELED
  fi

  # For executing libguestfs commands we need to umount the vm
  if [[ $(findmnt "${configurations[mount_point]}") ]]; then
    vm_umount
  fi

  cmd="guestfish --rw -a ${configurations[qemu_path_image]} run \
      $mount_root : command '$cmd_init'"

  warning " -> Generating rootfs $name on VM. This can take a few minutes."
  cmd_manager "$flag" "sleep 0.5s"
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
