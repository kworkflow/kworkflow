# ATTENTION:
# This function follows the cmd_manager signature (src/kwlib.sh) because we
# share the specific distro in the kw main code. However, when we deploy for a
# remote machine, we need this function, and this is the reason that we added
# this function.
function cmd_manager()
{
  local flag="$1"

  case "$flag" in
    SILENT)
      shift 1
      ;;
    WARNING)
      shift 1
      echo "WARNING"
      echo "$@"
      ;;
    SUCCESS)
      shift 1
      echo "SUCCESS"
      echo "$@"
      ;;
    TEST_MODE)
      shift 1
      echo "$@"
      return 0
      ;;
    *)
      echo "$@"
      ;;
  esac

  eval "$@"
}

function ask_yN()
{
  local message="$*"

  read -r -p "$message [y/N] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    echo "1"
  else
    echo "0"
  fi
}

function reboot_machine()
{
  local reboot="$1"
  local local="$2"
  local flag="$3"

  [[ "$local" == 'local' ]] && sudo_cmd="sudo -E"

  if [[ "$reboot" == "1" ]]; then
    cmd="$sudo_cmd reboot"
    cmd_manager "$flag" "$cmd"
  fi
}

function install_modules()
{
  local module_target="$1"
  local flag="$2"
  local ret

  if [[ -z "$module_target" ]]; then
    module_target='*.tar'
  fi

  cmd_manager "$flag" "tar -C /lib/modules -xf $module_target"
  ret="$?"

  if [[ "$ret" != 0 ]]; then
    echo "Warning: Couldn't extract module archive."
  fi
}

function kernel_uninstall()
{
  local reboot="$1"
  local local_deploy="$2"
  local kernel="$3"
  local flag="$4"

  if [[ -z "$kernel" ]]; then
    echo "Invalid argument"
    exit 22 #EINVAL
  fi

  IFS=', ' read -r -a kernel_names <<< "$kernel"
  for kernel in "${kernel_names[@]}"; do
    echo "Removing: $kernel"
    do_uninstall "$kernel" "" "$flag"
  done

  if [[ $(type -t update_boot_loader) == 'function' ]]; then
    # Each distro script should implement update_boot_loader
    echo "update_boot_loader $kernel $local_deploy $flag"
    update_boot_loader "$kernel" "$local_deploy" "$flag"
  fi

  # Reboot
  reboot_machine "$reboot" "$local_deploy"
}
