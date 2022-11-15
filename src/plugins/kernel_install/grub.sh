# This file is specific to the GRUB bootloader, and since it is part of kw, it
# follows the bootloader API. In other words, we have one entry point
# functions: run_bootloader_update: Update GRUB in a local and remote machine.

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
