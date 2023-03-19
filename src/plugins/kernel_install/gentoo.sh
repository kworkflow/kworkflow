# Gentoo package names
declare -ag required_packages=(
  'net-misc/rsync'
  'app-misc/screen'
  'sys-apps/pv'
  'app-arch/lzip'
  'app-arch/xz-utils'
  'app-arch/lzop'
  'app-arch/zstd'
  'sys-boot/os-prober'
  'sys-kernel/dracut'
)

# Gentoo package manager command
declare -g package_manager_cmd='sudo emerge --noreplace'

# Setup hook
function distro_pre_setup()
{
  local flag="$1"
  local target="$2"
  local cmd_prefix=''

  # LOCAL_TARGET
  if [[ "$target" == 2 ]]; then
    cmd_prefix='sudo -E '
  fi

  cmd="{$cmd_prefix}printf '>=sys-boot/grub-2.06-r5 mount' | sudo tee -a /etc/portage/package.use/grub > /dev/null"
  cmd_manager "$flag" "$cmd"
}

function generate_gentoo_temporary_root_file_system()
{
  local flag="$1"
  local name="$2"
  local target="$3"
  local bootloader_type="$4"
  local path_prefix="$5"
  local cmd='dracut -f --kver'
  local prefix='/'

  if [[ -n "$path_prefix" ]]; then
    prefix="${path_prefix}"
  fi

  # We do not support initramfs outside grub scope
  [[ "$bootloader_type" != 'GRUB' ]] && return

  cmd+=" $name"

  if [[ "$target" == 'local' ]]; then
    cmd="sudo -E $cmd"
  fi

  # Update initramfs
  cmd_manager "$flag" "$cmd"
}
