include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kwlib.sh"

function vm_mount()
{
  local flag="$1"
  local qemu_img_path="$2"
  local mount_point_path="$3"
  local guestmount_cmd
  local ret

  flag=${flag:-"SILENT"}
  qemu_img_path="${qemu_img_path:-${configurations[qemu_path_image]}}"
  mount_point_path="${mount_point_path:-${configurations[mount_point]}}"

  [[ $(findmnt "$mount_point_path") ]] && return 125

  mkdir -p "$mount_point_path"

  say "Mount $qemu_img_path in $mount_point_path"

  guestmount_cmd="guestmount -a $qemu_img_path -i $mount_point_path 2>&1"
  cmd_manager "$flag" "$guestmount_cmd"
  if [[ "$ret" ]]; then
    complain "Something went wrong when tried to mount $qemu_img_path" \
      "in $mount_point_path"
    return "$ret"
  fi

  return 0
}

function vm_umount()
{
  local flag="$1"
  local qemu_img_path="$2"
  local mount_point_path="$3"
  local guestumount_cmd
  local ret

  flag=${flag:-"SILENT"}
  qemu_img_path="${qemu_img_path:-${configurations[qemu_path_image]}}"
  mount_point_path="${mount_point_path:-${configurations[mount_point]}}"

  if [[ $(findmnt "$mount_point_path") ]]; then
    say "Unmount $mount_point_path"

    guestumount_cmd="guestunmount $mount_point_path"
    cmd_manager "$flag" "$guestumount_cmd"
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      complain "Something went wrong when tried to unmount $qemu_img_path" \
        "in $mount_point_path"
      return "$ret"
    fi
    return 0
  fi

  return 125 #ECANCELED
}

function vm_up()
{
  local cmd
  local flag='SILENT'

  say "Starting Qemu with: "
  echo "${configurations[virtualizer]} ${configurations[qemu_hw_options]}" \
    "${configurations[qemu_net_options]}" \
    "${configurations[qemu_path_image]}"

  cmd="${configurations[virtualizer]} ${configurations[qemu_hw_options]}"
  cmd+=" ${configurations[qemu_net_options]}"
  cmd+=" ${configurations[qemu_path_image]}"

  cmd_manager "$flag" "$cmd"
}
