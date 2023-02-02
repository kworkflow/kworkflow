SYSTEMD_BOOT_ENTRIES_DIR='/boot/loader/entries'

function run_bootloader_update()
{
  local flag="$1"
  local target="$2"
  local name="$3"
  local sudo_cmd
  local loader_conf="${SYSTEMD_BOOT_ENTRIES_DIR}/kw_${name}_linux.conf"

  if [[ -e "/boot/vmlinuz-${name}" ]]; then
    add_systemd_boot_entry "$flag" "$target" "$name"
  fi
}

function add_systemd_boot_entry()
{
  local flag="$1"
  local target="$2"
  local name="$3"
  local loader_conf_path="${SYSTEMD_BOOT_ENTRIES_DIR}/kw_${name}.conf"
  local template_loader_path="${REMOTE_KW_DEPLOY}/template_loader.conf"
  local kernel_parameters
  local cmd
  local sudo_cmd

  [[ "$target" == 'local' ]] && sudo_cmd='sudo'

  # Get kernel parameters from default entry
  #TODO: only use jq to do the parsing
  kernel_parameters=$(bootctl --json=short list | jq '.options' | head -n1 | tr -d '"')

  cmd='sed -e "s/NAME/${name}/g" -e "s/KERNEL_PARAMETERS/${kernel_parameters}/g" "${template_loader_path}" |'
  cmd+='${sudo_cmd} tee "${loader_conf_path}" >/dev/null'
  cmd_manager "$flag" "$cmd"
}

function remove_systemd_boot_entry()
{
  local flag="$1"
  local name="$2"
  local loader_conf="${SYSTEMD_BOOT_ENTRIES_DIR}/kw_${name}.conf"

  sudo rm "$loader_conf"
}
