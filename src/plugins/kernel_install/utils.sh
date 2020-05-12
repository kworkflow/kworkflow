# List available kernels
# @single_line If this option is set to 1 this function will display all
#   available kernels in a single line separated by commas. If it gets 0 it
#   will display each kernel name by line.
# @prefix Set a base prefix for searching for kernels.
function list_installed_kernels()
{
  local single_line="$1"
  local prefix="$2"
  local output
  local ret
  local super=0
  local available_kernels=()
  local grub_cfg=""

  grub_cfg="$prefix/boot/grub/grub.cfg"

  output=$(awk -F\' '/menuentry / {print $2}' "$grub_cfg" 2>/dev/null)

  if [[ "$?" != 0 ]]; then
    if ! [[ -r "$grub_cfg" ]] ; then
      echo "For showing the available kernel in your system we have to take" \
           "a look at '/boot/grub/grub.cfg', however, it looks like that" \
           "that you have no read permission."
      if [[ $(ask_yN "Do you want to proceed with sudo?") =~ "0" ]]; then
        echo "List kernel operation aborted"
        return 0
      fi
      super=1
    fi
  fi

  if [[ "$super" == 1 ]]; then
    output=$(sudo awk -F\' '/menuentry / {print $2}' "$grub_cfg")
  fi

  output=$(echo "$output" | grep recovery -v | grep with |  awk -F" "  '{print $NF}')

  while read kernel
  do
    if [[ -f "$prefix/boot/vmlinuz-$kernel" ]]; then
       available_kernels+=( "$kernel" )
    fi
  done <<< "$output"

  echo

  if [[ "$single_line" != 1 ]]; then
    printf '%s\n' "${available_kernels[@]}"
  else
    echo -n ${available_kernels[0]}
    available_kernels=("${available_kernels[@]:1}")
    printf ',%s' "${available_kernels[@]}"
    echo ""
  fi

  return 0
}

function reboot_machine()
{
  local reboot="$1"
  local local="$2"

  if [[ "$local" == 'local' ]]; then
    sudo_cmd="sudo -E"
  fi

  if [[ "$reboot" == "1" ]]; then
    cmd="$sudo_cmd reboot"
    cmd_manager "$flag" "$cmd"
  fi
}

function do_uninstall()
{
  local target="$1"
  local kernelpath="/boot/vmlinuz-$target"
  local initrdpath="/boot/initrd.img-$target"
  local modulespath="/lib/modules/$target"
  local libpath="/var/lib/initramfs-tools/$target"

  if [ -z "$target" ]; then
    echo "No parameter, nothing to do"
    exit 0
  fi

  local today=$(date +%Y_%m_%d-%H_%M_%S)
  local temp_rm="/tmp/$today"
  mkdir -p "$temp_rm/{lib,modules}"

  if [ -f "$kernelpath" ]; then
    echo "Removing: $kernelpath"
    rm "$kernelpath"
  else
    echo "Can't find $kernelpath"
  fi

  if [ -f "$kernelpath.old" ]; then
    echo "Removing: $kernelpath.old"
    rm "$kernelpath.old"
  else
    echo "Can't find $kernelpath.old"
  fi

  if [ -f "$initrdpath" ]; then
    echo "Removing: $initrdpath"
    rm -rf "$initrdpath"
  else
    echo "Can't find: $initrdpath"
  fi

  if [[ -d "$modulespath" && "$modulespath" != "/lib/modules" ]]; then
    echo "Removing: $modulespath"
    rm -rf "$modulespath"
  else
    echo "Can't find $modulespath"
  fi

  if [ -f "$libpath" ]; then
    echo "Removing: $libpath"
    rm -rf "$libpath"
  else
    echo "Cant't find $libpath"
  fi
}

function kernel_uninstall()
{
  local reboot="$1"
  local local_deploy="$2"
  local kernel="$3"
  local flag="$4"

  if [[ -z "$kernel" ]];then
    echo "Invalid argument"
    exit 22 #EINVAL
  fi

  IFS=', ' read -r -a kernel_names <<< "$kernel"
  for kernel in "${kernel_names[@]}"; do
    echo "Removing: $kernel"
    do_uninstall "$kernel"
  done

  # Each distro script should implement update_boot_loader
  echo "update_boot_loader $kernel $local_deploy $flag"
  update_boot_loader "$kernel" "$local_deploy" "$flag"

  # Reboot
  reboot_machine "$reboot" "$local_deploy"
}
