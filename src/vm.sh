include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kwlib.sh"

declare -g prefix='/'
declare -gA options_values

function vm()
{
  if [[ -z "$*" ]]; then
    complain 'Please, provide an argument'
    vm_help
    exit 22 #EINVAL
  fi

  vm_parser "$@"
  shift

  if [[ -n "${options_values['OPERATION']}" ]]; then
    if [[ "${options_values['OPERATION']}" = "MOUNT" ]]; then
      vm_mount "$@"
    fi

    if [[ "${options_values['OPERATION']}" = "UMOUNT" ]]; then
      vm_umount "$@"
    fi

    if [[ "${options_values['OPERATION']}" = "UP" ]]; then
      vm_up "$@"
    fi
  fi
}

function vm_parser()
{
  local raw_options="$*"
  local operation=0

  if [[ "$1" =~ -h|--help ]]; then
    vm_help "$1" 'vm'
    exit 0
  fi

  options_values['OPERATION']=''
  options_values['QEMU_IMG']=''
  options_values['MOUNT_POINT']=''

  IFS=' ' read -r -a options <<< "$raw_options"

  for option in "${options[@]}"; do
    if [[ "$option" =~ ^(--.*|-.*|test_mode) ]]; then
      case "$option" in
        --mount)
          options_values['OPERATION']="MOUNT"
          operation=1
          continue
          ;;
        --umount)
          options_values['OPERATION']="UMOUNT"
          operation=1
          continue
          ;;
        --up)
          options_values['OPERATION']="UP"
          continue
          ;;
        *)
          complain "Invalid option: $option"
          vm_help
          exit 22 #EINVAL
          ;;
      esac
    else
      if [[ "$operation" == 1 ]]; then

        if [[ -z ${options_values['QEMU_IMG']} ]]; then
          options_values['QEMU_IMG']="$option"

        elif [[ -z ${options_values['MOUNT_POINT']} ]]; then
          options_values['MOUNT_POINT']="$option"
          operation=0

        fi
      fi
    fi
  done

  # Invalid options
  if [[ "$operation" == 1 && (-z ${options_values['QEMU_IMG']} || -z ${options_values['MOUNT_POINT']}) ]]; then
    complain "--${options_values['OPERATION'],,} requires two parameters"
    exit 125 #ECANCELED
  fi
}

function vm_mount()
{
  local flag="$1"
  local qemu_img_path="$2"
  local mount_point_path="$3"
  local guestmount_cmd
  local ret
  local distro

  if [[ "$1" =~ -h|--help ]]; then
    vm_help "$1" 'vm'
    exit 0
  fi

  flag=${flag:-'SILENT'}
  qemu_img_path="${qemu_img_path:-${configurations[qemu_path_image]}}"
  mount_point_path="${mount_point_path:-${configurations[mount_point]}}"

  if [[ ! -r "${prefix}boot/vmlinuz-$(uname -r)" ]]; then
    say 'To mount the VM, the kernel image needs to be readable'
    if [[ $(ask_yN 'Do you want to make your host kernel image readable?') =~ 0 ]]; then
      return 125 # ECANCELED
    fi

    distro=$(detect_distro "${prefix}")
    if [[ "$distro" =~ 'debian' ]]; then
      cmd_manager "$flag" "sudo dpkg-statoverride --update --add root root 0644 ${prefix}boot/vmlinuz-$(uname -r)"
    else
      cmd_manager "$flag" "sudo chmod +r ${prefix}boot/vmlinuz-$(uname -r)"
    fi
  fi

  if [[ -n "$(findmnt "$mount_point_path")" ]]; then
    return 125 # ECANCELED
  fi

  mkdir -p "$mount_point_path"

  say "Mount $qemu_img_path in $mount_point_path"

  guestmount_cmd="guestmount -a $qemu_img_path -i $mount_point_path 2>&1"
  cmd_manager "$flag" "$guestmount_cmd"
  if [[ "$ret" ]]; then
    complain "Something went wrong when tried to mount $qemu_img_path in $mount_point_path"
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

  if [[ "$1" =~ -h|--help ]]; then
    vm_help "$1" 'vm'
    exit 0
  fi

  flag=${flag:-'SILENT'}
  qemu_img_path="${qemu_img_path:-${configurations[qemu_path_image]}}"
  mount_point_path="${mount_point_path:-${configurations[mount_point]}}"

  if [[ $(findmnt "$mount_point_path") ]]; then
    say "Unmount $mount_point_path"

    guestumount_cmd="guestunmount $mount_point_path"
    cmd_manager "$flag" "$guestumount_cmd"
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      complain "Something went wrong when tried to unmount $qemu_img_path in $mount_point_path"
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

  if [[ "$1" =~ -h|--help ]]; then
    vm_help "$1" 'vm'
    exit 0
  fi

  say 'Starting Qemu with:'
  printf '%s' "${configurations[virtualizer]} " \
    "${configurations[qemu_hw_options]} " \
    "${configurations[qemu_net_options]} " \
    "${configurations[qemu_path_image]}" $'\n'

  cmd="${configurations[virtualizer]} ${configurations[qemu_hw_options]}"
  cmd+=" ${configurations[qemu_net_options]}"
  cmd+=" ${configurations[qemu_path_image]}"

  cmd_manager "$flag" "$cmd"
}

function vm_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man "$2"
    return
  fi
  printf '%s\n' 'kw vm (--mount | --umount | --up):' \
    '  --mount - Mount VM' \
    '  --umount - Unmount VM' \
    '  --up - Start VM'
}
