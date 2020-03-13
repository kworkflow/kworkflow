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

