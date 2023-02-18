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

# Setup hook
function distro_pre_setup()
{
  : # NOTHING
}

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

  cmd_manager "$flag" "$cmd_prefix grub2-editenv - unset menu_auto_hide"
  cmd_manager "$flag" "$cmd_prefix sed -i -e '$grub_regex' /etc/default/grub"

  # Update initramfs
  cmd_manager "$flag" "$cmd_prefix $cmd"
}
