include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kwlib.sh"

declare -g prefix='/'
declare -gA options_values

function vm_main()
{
  if [[ "$#" -eq 0 ]]; then
    complain 'Expected string or parameter. See man for detail.'
    exit 22 # EINVAL
  fi

  if [[ "$1" =~ -h|--help ]]; then
    vm_help "$1"
    exit 0
  fi

  parse_vm_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  if [[ -n "${options_values['MOUNT']}" ]]; then
    shift
    vm_mount "$@"

    alert_completion 'kw vm' "${options_values['ALERT_COMPLETION']}"
    return "$?"
  fi

  if [[ -n "${options_values['UMOUNT']}" ]]; then
    shift
    vm_umount "$@"

    alert_completion 'kw vm' "${options_values['ALERT_COMPLETION']}"
    return "$?"
  fi

  if [[ -n "${options_values['UP']}" ]]; then
    shift
    vm_up "$@"
    exit 0
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

function parse_vm_options()
{
  local long_options='mount,umount,up,alert:'
  local short_options='m,n,u'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw vm' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['MOUNT']=''
  options_values['UMOUNT']=''
  options_values['UP']=''
  options_values['ALERT_COMPLETION']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --mount | -m)
        options_values['MOUNT']=1
        shift
        ;;
      --umount | -n)
        options_values['UMOUNT']=1
        shift
        ;;
      --up | -u)
        options_values['UP']=1
        shift
        ;;
      --alert)
        options_values['ALERT_COMPLETION']="--alert=$2"
        shift 2
        ;;
      --) # End of options, beginning of arguments
        shift
        ;;
      *)
        options_values['ERROR']="Unrecognized argument: $1"
        return 22 # EINVAL
        shift
        ;;
    esac
  done
}

function vm_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'vm'
    return
  fi
  printf '%s\n' 'kw vm:' \
    ' vm (-m|--mount) - Mount VM' \
    ' vm (-n|--umount) - Unmount VM' \
    ' vm (-u|--up) - Starts VM'
}
