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

# Update bootloader API
#
# update_bootloader() behaves like the template pattern, which means that we
# have a generic function name that will be called in a specific order to
# update the bootloader in the target machine. The trick here consists of first
# loading the target bootloader and specific distro script and executing the
# required update. Also notice that in some cases we need to update the
# initramfs.
#
# @flag: How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @name: Kernel name used during the deploy
# @target: Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @kernel_image_name: Kernel binary file name
# @distro: Target distro (e.g., arch or debian)
# @prefix: Set a base prefix for searching for kernels.
# @root_file_system: Specific rootfs
# @force: Avoid question if initramfs has any error
function update_bootloader()
{
  local flag="$1"
  local name="$2"
  local target="$3"
  local kernel_image_name="$4"
  local distro="$5"
  local prefix="$6"
  local root_file_system="$7"
  local force="$8"
  local deploy_data_string
  local bootloader_path_prefix="${REMOTE_KW_DEPLOY}/"
  local ret
  local generate_initram=0

  [[ -n "$distro" ]] && generate_initram=1
  [[ -z "$prefix" ]] && prefix='/'

  if [[ "$target" == 'local' || "$flag" == 'TEST_MODE' ]]; then
    bootloader_path_prefix="${KW_PLUGINS_DIR}/kernel_install/"
  fi

  deploy_data_string=$(collect_deploy_info "$flag" "$target" "$prefix")

  declare -A deploy_data="(${deploy_data_string})"

  case "${deploy_data['bootloader']}" in
    GRUB)
      bootloader_path_prefix+='grub.sh'
      ;;
    RPI_BOOTLOADER)
      bootloader_path_prefix+='rpi_bootloader.sh'
      ;;
    *)
      return 95 # ENOTSUP
      ;;
  esac

  # Load specific bootloader action
  include "$bootloader_path_prefix"

  # Each distro has their own way to generate their temporary root file system.
  if [[ "$generate_initram" == 1 ]]; then
    # For example, Debian uses update-initramfs, Arch uses mkinitcpio, etc
    cmd="generate_${distro}_temporary_root_file_system"
    cmd+=" ${flag} ${name} ${target} ${deploy_data['bootloader']} ${path_prefix} ${root_file_system}"

    cmd_manager "$flag" "$cmd"
    ret="$?"
    # If the generate root fs function returns 2, it means we don't have
    # initramfs; hence, stop deploying.
    if [[ "$ret" == 2 ]]; then
      printf 'The initramfs were not generated, which will cause boot issues.\n'
      printf 'Stop the deploy.\n'
      return "$ret"
    fi

    # We have an error, but it may not be fatal. Let the user decide.
    if [[ "$ret" == 68 ]]; then
      printf '\n\t kw identified possible non-fatal errors in the generated initramfs.\n'
      if [[ "$force" == 0 ]]; then

        ask_yN 'There are some errors in the generated initramfs. Do you want to proceed with the installation?'
        if [[ "$?" != 1 ]]; then
          printf '%s\n' "Kernel ${kernel_image_name} installation canceled"
          exit 124 # ECANCELED
        fi
      fi
    fi
  fi

  # Update bootloader
  run_bootloader_update "$flag" "$target" "$name" "$kernel_image_name"
  ret="$?"

  return "$ret"
}

function collect_deploy_info()
{
  local flag="$1"
  local target="$2"
  local prefix="$3"
  local distro
  local bootloader

  bootloader=$(identify_bootloader_from_files "$prefix" "$target")
  bootloader="[bootloader]=${bootloader}"

  # Get distro
  distro=$(cat /etc/*-release | grep --word-regexp 'ID\(_LIKE\)\?' | cut --delimiter='=' --fields=2 | xargs printf '%s ')
  distro="${distro::-1}"
  distro="[distro]='${distro}'"

  # Build associative array data
  printf '%s' "${bootloader} ${distro}"
}

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
