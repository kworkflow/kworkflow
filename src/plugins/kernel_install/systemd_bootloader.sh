SYSTEMD_BOOT_ENTRIES_DIR="/boot/loader/entries"

function run_bootloader_update()
{
  local flag="$1"
  local target="$2"
  local name="$3"
  local sudo_cmd
  local loader_conf="${SYSTEMD_BOOT_ENTRIES_DIR}/kw_${name}_linux.conf"

  #if [[ ! -e "/boot/vmlinuz-${name}" && -e "$loader_conf" ]]; then
  #  echo removing boot entry
  #  remove_systemd_boot_entry "$flag" "$name"
  #fi

  if [[ -e "/boot/vmlinuz-${name}" ]]; then
    add_systemd_boot_entry "$flag" "$target" "$name"
  fi
}

function add_systemd_boot_entry()
{
  local flag="$1"
  local target="$2"
  local name="$3"
  local loader_conf="${SYSTEMD_BOOT_ENTRIES_DIR}/kw_${name}_linux.conf"
  local kernel_parameters

  [[ "$target" == 'local' ]] && sudo_cmd='sudo'

  # Get kernel parameters from default entry
  #TODO: only use jq to do the parsing
  kernel_parameters=$(bootctl --json=short list | jq '.options' | head -n1 | tr -d '"')

  {
    printf '%s\n' '# Create by kw'
    printf '%s\n' 'title ARCH KW'
    printf '%s\n' "version ${name}"
    printf '%s\n' "linux /vmlinuz-${name}"
    printf '%s\n' "initrd /initramfs-${name}.img"
    printf '%s\n' "options ${kernel_parameters}"
  } | sudo tee "$loader_conf" > /dev/null
}

function remove_systemd_boot_entry()
{
  local flag="$1"
  local name="$2"
  local loader_conf="${SYSTEMD_BOOT_ENTRIES_DIR}/kw_${name}_linux.conf"

  sudo rm "$loader_conf"
}
