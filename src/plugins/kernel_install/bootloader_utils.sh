declare -gar GRUB=(
  'boot/grub/grub.conf'
  'boot/grub/grub.cfg'
  'boot/grub2/grub.conf'
  'boot/grub2/grub.cfg'
  'boot/efi/EFI/ubuntu/'
  'boot/efi/EFI/steamos'
  'NST/menu.lst'
  'boot/grub/menu.lst'
  'ubuntu/disks/boot/grub/menu.lst'
  'ubuntu/disks/install/boot/grub/menu.lst'
  'ubuntu/winboot/menu.lst'
)

# Syslinux and variants
declare -gar SYSLINUX=(
  'boot/syslinux/syslinux.cfg'
  'boot/syslinux/root.A.cfg'
  'boot/syslinux/root.B.cfg'
  'boot/syslinux/root.C.cfg'
  'boot/syslinux/root.D.cfg'
  'syslinux/syslinux.cfg'
)

# Raspberry PI
declare -gar RPI_BOOTLOADER=(
  'boot/bootcode.bin'
  'boot/config.txt'
  'boot/LICENCE.broadcom'
)

# List of supported bootloaders
declare -gar SUPPORTED_BOOTLOADER=(
  'GRUB'
  'SYSLINUX'
  'RPI_BOOTLOADER'
)

# Based on a set of common files, this function tries to identify the
# bootloader in the target machine.
#
# @path_prefix: Path prefix, this is specially useful for VM deploy
#
# Return:
# Return a string with the bootloader type or an empty result
function identify_bootloader_from_files()
{
  local path_prefix="$1"
  local target="$2"
  local bootloader=''

  path_prefix=${path_prefix:-'/'}

  for bootloader_target in "${SUPPORTED_BOOTLOADER[@]}"; do
    declare -n bootloader_files="$bootloader_target"

    for file in "${bootloader_files[@]}"; do
      file="${path_prefix}/${file}"

      if [[ "$target" == 2 || "$target" == 'local' ]]; then
        sudo [ -e "$file" ] && bootloader="$bootloader_target"
      else
        [[ -e "$file" ]] && bootloader="$bootloader_target"
      fi
    done

    [[ -n "$bootloader" ]] && break
  done

  printf '%s' "$bootloader"
}
