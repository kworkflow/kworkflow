# Most of the code available here was heavily inspired in the bootinfonscript
# source, for more details see:
#  - https://github.com/arvidjaar/bootinfoscript
declare -gA device_to_mount_point
declare -ga available_hard_driver_system
declare -g DEV_PATH='/dev'

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

# This function will populate the device_to_mount_point with device info in the
# key and the mount point in the value
function discover_device_and_partition()
{
  local ignore_matches_regex
  local output
  local device
  local mount_on
  declare -a ignore_from_df=(
    'loop'
    'fuse'
    'udev'
    'tmpfs'
    'Filesystem'
  )

  printf -v ignore_matches_regex "%s|" "${ignore_from_df[@]}" >> /dev/null
  ignore_matches_regex="$ignore_matches_regex"'Monted'
  output=$(df --output='source,target' | grep -Ev "$ignore_matches_regex")

  # Let's populate device_to_partition
  while IFS= read -r line; do
    device=$(echo "$line" | cut -d ' ' -f1)
    mount_on=$(echo "$line" | rev | cut -d' ' -f1 | rev)
    device_to_mount_point["$device"]="$mount_on"
  done <<< "$output"
}

# This function's goal is to identify the type of disk device available in the
# target system. This function uses a regex match in the /dev directory to
# populate the array available_hard_driver_system with the disks entries found
# in the system.
function discover_all_hard_drive()
{
  local all_patterns=''
  local last_char=''
  local output=''
  local index=0
  # This list might be updated in the future
  declare -a hard_driver_patterns=(
    "$DEV_PATH/hd[a-z]"
    "$DEV_PATH/hd[a-z][a-z]"
    "$DEV_PATH/sd[a-z]"
    "$DEV_PATH/sd[a-z][a-z]"
    "$DEV_PATH/mmcblk[0-9][a-z][0-9]"         # mmcblkXzY
    "$DEV_PATH/nvme[0-9][a-z][0-9][a-z][0-9]" # nvmeXYZPQ
  )
  printf -v all_patterns '%s ' "${hard_driver_patterns[@]}"

  # We will try to list some patterns that may not be available, that's
  # why we are redirecting the error to dev/null
  output=$(eval "ls $all_patterns" 2> /dev/null)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Check if we had a folder in the list
    printf -v last_char '%s' "${line: -1}"
    [[ "$last_char" == ':' ]] && continue

    available_hard_driver_system["$index"]="$line"
    ((index++))
  done <<< "$output"
}

# This function tries to identify the partition table type by reading the first
# four bytes from the target hard drive.
#
# @hard_driver: Reference to a /dev/HARD_DRIVER
#
# Return:
# Return the partition type. If we get MSDos, treat it as a hint but do not
# rely on it because it can also mean that we could not correctly identify the
# output.
#
# See:
# https://en.wikipedia.org/wiki/Design_of_the_FAT_file_system
function partition_table_type()
{
  local hard_driver="$1"
  local hexdump_info

  [[ -z "$hard_driver" ]] && return 0

  # Let's read the FS information sector
  hexdump_info=$(hexdump -v -s 512 -n 4 -e '"%_u"' "$hard_driver")
  case "$hexdump_info" in
    'EMBR')
      printf '%s' 'EMBR'
      ;;
    'EFI ')
      printf '%s' 'EFI'
      ;;
    'RRaA')
      printf '%s' 'RRaA'
      ;;
    *)
      printf '%s' 'MSDos'
      ;;
  esac
}

# MBR is not so common these days, but we still find it in ChromeOS
# (development mode) and some embedded systems. This function is responsible
# for checking if a disk has an MBR partition, and if we have it, we extract
# some information that might be useful for identifying the bootloader
# information.
#
# Note: This function was heavily inspired by the bootinfoscript tool and
# multiple sources. See the below references:
# - https://en.wikipedia.org/wiki/Master_boot_record
# - https://www.suse.com/c/making-sense-hexdump/
# - https://neosmart.net/wiki/mbr-boot-process/
# - https://www.pixelbeat.org/docs/disk/
function identify_mbr_per_partition()
{
  local hard_drive="$1"
  local raw_mbr_512=''
  local boot_code_bytes=''
  local boot_code_80_81_bytes=''
  local bootloader_type=''

  # Dump all MBR data (512 bytes) to a single variable
  raw_mbr_512=$(hexdump -v -n 512 -e '/1 "%02x"' "${hard_drive}")

  # We have some special case where bytes 0x80 to 0x81 will describe
  # the bootloader version
  boot_code_80_81_bytes="${raw_mbr_512:256:4}"

  # Inspect the first 4 bytes
  boot_code_bytes="${raw_mbr_512:0:4}"

  case "$boot_code_bytes" in
    eb48) # Grub Legacy
      bootloader_type='Grub-Legacy'
      ;;
    eb4c | eb63) # Grub2 - 1.96, 1.97, 1.99
      bootloader_type='Grub2'
      ;;
    33ed)
      case "$boot_code_80_81_bytes" in
        407c | 83e1)
          # ISOhybrid Syslinux 4.04 and higher
          # ISOhybrid with partition support Syslinux 4.04 and higher
          bootloader_type='ISOhybrid-Syslinux-4_04-and-higher'
          ;;
      esac
      ;;
    fabe)
      bootloader_type='No-boot-loader?'
      ;;
    # Bootloaders are not handled yet due to the lack of a use case.
    # In order: BootIt-NG, GAG, Testdisk, ReactOS, Lilo, MS-DOS-3.30 to Windows-95.A,
    # Paragon, Solaris, Truecrypt-Boot-Loader, XOSL, Plop, HP-Gateway
    fceb | fc33 | fc31 | fafc | faeb | fa33 | eb31 | eb04 | ea1e | ea05 | b800 | 33ff)
      bootloader_type='NOT_SUPPORTED_YET'
      ;;
    0000) # It does not have MBR bootloader, it should be something different
      bootloader_type=''
      printf '%s' "$bootloader_type"
      return
      ;;
  esac

  # If we already identified the bootloader, there is no reason to search more
  if [[ -n "$bootloader_type" ]]; then
    printf '%s' "$bootloader_type"
    return
  fi

  boot_code_bytes="${raw_mbr_512:0:6}"

  # Let's check the first 3 bytes
  case "$boot_code_bytes" in
    33c08e)
      bootloader_type='Windows'
      ;;
    33c0fa)
      # ChromeOS will fall here
      bootloader_type='Syslinux-MBR-4_04-and-higher'
      ;;
    33c090 | eb5e00 | eb5e80 | eb5e90)
      # Bootloaders are not handled yet due to the lack of a use case.
      # In order: DiskCryptor, fbinst, Grub4Dos, WEE
      bootloader_type='NOT_SUPPORTED_YET'
      ;;
    fa31c0 | fa31ed)
      # Look at bytes 0x80-0x81 to be more specific about the Syslinux variant/version.
      case "$boot_code_80_81_bytes" in
        # ISOhybrid syslinux 3.72, 3.73, 3.74, 3.80
        0069 | e879 | 0fb6 | 407c | 83e1 | b6c6 | fbc0)
          # From 0fb6 to fbc0:
          # 1. ISOhybrid with partition support Syslinux 3.82-3.86
          # 2. ISOhybrid Syslinux 3.82-4.03
          # 3. ISOhybrid with partition support Syslinux 4.00 to 4.03
          # 4. ISOhybrid with partition support Syslinux 4.81
          # 5. ISOhybrid Syslinux 4.81
          bootloader_type='ISOhybrid-Syslinux'
          ;;
        # Syslinux MBR 3.61 to 4.03, 3.36 to 3.51, 3.00 to 3.35, 3.52 to 3.60
        7c66 | 7cb8 | b442 | bb00)
          bootloader_type='Syslinux-MBR-3_35-4_03'
          ;;
      esac
      ;;
    fa31c9)
      bootloader_type='Master-Boot-LoaDeR'
      ;;
  esac

  if [[ -n "$bootloader_type" ]]; then
    printf '%s' "$bootloader_type"
    return
  fi

  boot_code_bytes="${raw_mbr_512:0:8}"

  case "$boot_code_bytes" in
    fab80000)
      bootloader_type='FreeDOS-eXtended-FDisk'
      ;;
    fab8*)
      bootloader_type='No-boot-loader'
      ;;
  esac

  if [[ -n "$bootloader_type" ]]; then
    printf '%s' "$bootloader_type"
    return
  fi

  boot_code_bytes="${raw_mbr_512:0:16}"

  case "$boot_code_bytes" in
    31c08ed0bc007c8e)
      bootloader_type='SUSE-generic-MBR'
      ;;
    31c08ed0bc007cfb)
      bootloader_type='Acer-PQService-MBR'
      ;;
  esac

  printf '%s' "$bootloader_type"
  return
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
      file="$path_prefix/$file"

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
