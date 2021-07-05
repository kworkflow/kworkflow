# This file deals with functions related to hardware information

include "$KW_LIB_DIR/remote.sh"
include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/vm.sh"

declare -gA device_info_data=(['ram']='' # RAM memory in KB
  ['cpu_model']=''                       # CPU model vendor
  ['cpu_currently']=''                   # Current frequency of CPU in MHz
  ['cpu_max']=''                         # Maximum frequency of CPU in MHz
  ['cpu_min']=''                         # Minimum frequency of CPU in MHz
  ['desktop_environment']=''             # Desktop environment
  ['disk_size']=''                       # Disk size in KB
  ['root_path']=''                       # Root directory path
  ['fs_mount']=''                        # Path where root is mounted
  ['os']=''                              # Operating system name
  ['motherboard_name']=''                # Motherboard name
  ['motherboard_vendor']=''              # Motherboard vendor
  ['chassis']=''                         # Chassis type
  ['img_size']=''                        # Size of VM image in KB
  ['img_type']='')                       # Type of VM image

declare -gA gpus

declare -gA device_options

# This function calls other functions to process and display the hardware
# information of a target machine.
function device_info()
{
  local ret
  device_info_parser "$@"

  ret="$?"
  if [[ "$ret" != 0 ]]; then
    return "$ret"
  fi

  learn_device "${device_options['target']}"
  show_data
}

# This function populates the ram element from the device_info_data global
# variable with the total RAM memory from the target machine in kB.
#
# @target Target machine
function get_ram()
{
  local target="$1"
  local flag="$2"
  local ip="$3"
  local port="$4"
  local ram
  local cmd

  ip=${ip:-"${device_options['ip']}"}
  port=${port:-"${device_options['port']}"}
  flag=${flag:-'SILENT'}
  cmd="[ -f '/proc/meminfo' ] && cat /proc/meminfo | grep 'MemTotal' | grep -o '[0-9]*'"
  case "$target" in
    1) # VM_TARGET
      ram="$(echo "${configurations[qemu_hw_options]}" | sed -r 's/.*-m ?([0-9]+).*/\1/')"
      ram="$(numfmt --from-unit=M --to-unit=K "$ram")"
      ;;
    2) # LOCAL_TARGET
      ram=$(cmd_manager "$flag" "$cmd")
      ;;
    3) # REMOTE_TARGET
      ram=$(cmd_remotely "$cmd" "$flag" "$ip" "$port")
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    echo "$ram"
    return 0
  fi

  device_info_data['ram']="$ram"
}

# This function provides the model and frequency of the CPU from a machine
#
# @target Target machine
function get_cpu()
{
  local target="$1"
  local flag="$2"
  local ip="$3"
  local port="$4"
  local cpu_model
  local cpu_frequency
  local cpu_currently
  local cpu_max
  local cpu_min

  ip=${ip:-"${device_options['ip']}"}
  port=${port:-"${device_options['port']}"}
  flag=${flag:-'SILENT'}
  cmd_frequency="lscpu | grep MHz | sed -r 's/(CPU.*)/\t\t\1/'"
  cmd_model="lscpu | grep 'Model name:' | sed -r 's/Model name:\s+//g' | cut -d' ' -f1"
  case "$target" in
    1) #VM_TARGET
      cpu_model='Virtual'
      ;;
    2) # LOCAL_TARGET
      cpu_model=$(cmd_manager "$flag" "$cmd_model")
      cpu_frequency=$(cmd_manager "$flag" "$cmd_frequency")
      ;;
    3) # REMOTE_TARGET
      cpu_model=$(cmd_remotely "$cmd_model" "$flag" "$ip" "$port")
      cpu_frequency=$(cmd_remotely "$cmd_frequency" "$flag" "$ip" "$port")
      ;;
  esac

  device_info_data['cpu_model']="$cpu_model"

  if [[ "$flag" == 'TEST_MODE' ]]; then
    echo "$cpu_model"
    echo "$cpu_frequency"
    return 0
  fi

  cpu_currently=$(echo "$cpu_frequency" | grep 'CPU MHz')
  cpu_max=$(echo "$cpu_frequency" | grep 'CPU max MHz')
  cpu_min=$(echo "$cpu_frequency" | grep 'CPU min MHz')

  cpu_currently=${cpu_currently//[!0-9,.]/}
  cpu_max=${cpu_max//[!0-9,.]/}
  cpu_min=${cpu_min//[!0-9,.]/}

  device_info_data['cpu_currently']="$cpu_currently"
  device_info_data['cpu_max']="$cpu_max"
  device_info_data['cpu_min']="$cpu_min"
}

# This function populates the values from the size and fs (filesystem) key of
# the device_info_data variable.
#
# @target Target machine
function get_disk()
{
  local target="$1"
  local flag="$2"
  local ip="$3"
  local port="$4"
  local cmd
  local info
  local size
  local mount
  local fs

  ip=${ip:-"${device_options['ip']}"}
  port=${port:-"${device_options['port']}"}
  flag=${flag:-'SILENT'}
  cmd="df -h / | tail -n 1 | tr -s ' '"
  case "$target" in
    1) # VM_TARGET
      cmd="df -h ${configurations[mount_point]} | tail -n 1 | tr -s ' '"
      info=$(cmd_manager "$flag" "$cmd")
      ;;
    2) # LOCAL_TARGET
      info=$(cmd_manager "$flag" "$cmd")
      ;;
    3) # REMOTE_TARGET
      info=$(cmd_remotely "$cmd" "$flag" "$ip" "$port")
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    echo "$info"
    return 0
  fi

  fs="$(echo "$info" | cut -d' ' -f1)"
  size="$(echo "$info" | cut -d' ' -f2)"
  mount="$(echo "$info" | cut -d' ' -f6)"

  device_info_data['disk_size']="$size"
  device_info_data['root_path']="$fs"
  device_info_data['fs_mount']="$mount"
}

# This function populates the os and desktop environment variables from the
# device_info_data variable.
#
# @target Target machine
function get_os()
{
  local target="$1"
  local flag="$2"
  local ip="$3"
  local port="$4"
  local cmd
  local os
  local desktop_env

  flag=${flag:-'SILENT'}
  target=${target:-"${device_options['target']}"}
  ip=${ip:-"${device_options['ip']}"}
  port=${port:-"${device_options['port']}"}
  cmd="find /usr/share/xsessions -type f -printf '%f ' | sed -r 's/\.desktop//g'"
  case "$target" in
    1) # VM_TARGET
      os=$(detect_distro "${configurations[mount_point]}")
      desktop_env=$(find "${configurations[mount_point]}/usr/share/xsessions" -type f -printf '%f ' | sed -r 's/\.desktop//g')
      ;;
    2) # LOCAL_TARGET
      os=$(detect_distro '/')
      desktop_env=$(cmd_manager "$flag" "$cmd")
      ;;
    3) # REMOTE_TARGET
      os=$(which_distro "$ip" "$port")
      desktop_env=$(cmd_remotely "$cmd" "$flag" "$ip" "$port")
      ;;
  esac

  device_info_data['os']="$os"
  device_info_data['desktop_environment']="$desktop_env"
}

# This function populates the gpu associative array with the vendor and
# fetchable memory from each GPU found in the target machine.
function get_gpu()
{
  local target="$1"
  local flag="$2"
  local ip="$3"
  local port="$4"
  local pci_addresses
  local gpu_info
  local cmd_pci_address

  ip=${ip:-"${device_options['ip']}"}
  port=${port:-"${device_options['port']}"}
  flag=${flag:-'SILENT'}

  # The first thing we want to do is retrieve all PCI addresses from any GPU in
  # the target machine. After that, we will get, for each GPU, the desired
  # information.
  cmd_pci_address="lspci | grep -e VGA -e 3D | cut -d' ' -f1"
  case "$target" in
    2) # LOCAL_TARGET
      pci_addresses=$(cmd_manager "$flag" "$cmd_pci_address")
      for g in $pci_addresses; do
        gpu_info=$(cmd_manager "$flag" "lspci -v -s $g")
        gpu_name=$(echo "$gpu_info" | sed -nr '/Subsystem/s/\s*.*:\s+(.*)/\1/p')
        gpu_provider=$(echo "$gpu_info" | sed -nr '/controller/s/.+controller: *([^\[\(]+).+/\1/p')
        gpus["$g"]="$gpu_name;$gpu_provider"
      done
      ;;
    3) # REMOTE_TARGET
      pci_addresses=$(cmd_remotely "$cmd_pci_address" "$flag" "$ip" "$port")
      for g in $pci_addresses; do
        gpu_info=$(cmd_remotely "lspci -v -s $g" "$flag" "$ip" "$port")
        gpu_name=$(echo "$gpu_info" | sed -nr '/Subsystem/s/\s*.*:\s+(.*)/\1/p')
        gpu_provider=$(echo "$gpu_info" | sed -nr '/controller/s/.+controller: *([^\[\(]+).+/\1/p')
        gpus["$g"]="$gpu_name;$gpu_provider"
      done
      ;;
  esac
}

# This function retrieves both the name and vendor from the motherboard of a
# target machine.
#
# @target Target machine
function get_motherboard()
{
  local target="$1"
  local flag="$2"
  local ip="$3"
  local port="$4"
  local mb_name
  local mb_vendor
  local cmd_name
  local cmd_vendor

  ip=${ip:-"${device_options['ip']}"}
  port=${port:-"${device_options['port']}"}
  flag=${flag:-'SILENT'}
  cmd_name='[ -f /sys/devices/virtual/dmi/id/board_name ] && cat /sys/devices/virtual/dmi/id/board_name'
  cmd_vendor='[ -f /sys/devices/virtual/dmi/id/board_vendor ] && cat /sys/devices/virtual/dmi/id/board_vendor'
  case "$target" in
    2) # LOCAL_TARGET
      mb_name=$(cmd_manager "$flag" "$cmd_name")
      mb_vendor=$(cmd_manager "$flag" "$cmd_vendor")
      ;;
    3) # REMOTE_TARGET
      mb_name=$(cmd_remotely "$cmd_name" "$flag" "$ip" "$port")
      mb_vendor=$(cmd_remotely "$cmd_vendor" "$flag" "$ip" "$port")
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    echo "$cmd_name"
    echo "$cmd_vendor"
    return 0
  fi

  device_info_data['motherboard_name']="$mb_name"
  device_info_data['motherboard_vendor']="$mb_vendor"
}

# This function gets the chassis type of the target machine.
#
# @target Target machine
function get_chassis()
{
  local target="$1"
  local flag="$2"
  local ip="$3"
  local port="$4"
  local cmd
  local chassis_type

  declare -a chassis_table=('Other' 'Unknown' 'Desktop' 'Low Profile Desktop'
    'Pizza Box' 'Mini Tower' 'Tower' 'Portable' 'Laptop' 'Notebook' 'Hand Held'
    'Docking Station' 'All in One' 'Sub Notebook' 'Space-Saving' 'Lunch Box'
    'Main System Chassis' 'Expansion Chassis' 'SubChassis' 'Bus Expansion Chassis'
    'Peripheral Chassis' 'Storage Chassis' 'Rack Mount Chassis' 'Sealed-Case PC'
    'VM')

  ip=${ip:-"${device_options['ip']}"}
  port=${port:-"${device_options['port']}"}
  flag=${flag:-'SILENT'}
  cmd='cat /sys/devices/virtual/dmi/id/chassis_type'
  case "$target" in
    1) # VM_TARGET
      chassis_type=25
      ;;
    2) # LOCAL_TARGET
      chassis_type=$(cmd_manager "$flag" "$cmd")
      ;;
    3) # REMOTE_TARGET
      chassis_type=$(cmd_remotely "$cmd" "$flag" "$ip" "$port")
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    echo "$cmd"
    return 0
  fi

  device_info_data['chassis']="${chassis_table[(($chassis_type - 1))]}"
}

# This function populates the img_size and img_type values from the
# device_info_data variable.
function get_img_info()
{
  local img_info
  local img_size
  local img_type

  img_info=$(file "${configurations[qemu_path_image]}")
  img_size=$(echo "$img_info" | sed -r 's/.*: .+, ([0-9]+) bytes/\1/')
  img_type=$(echo "$img_info" | sed -r 's/.*: (.+),.+/\1/')

  # The variable img_size stores the image size in bytes. It has to be converted
  # to kB when we store it in the device_info_data variable.
  device_info_data['img_size']=$(numfmt --to-unit=1000 "$img_size")
  device_info_data['img_type']="$img_type"
}

# This function calls other functions to populate the device_info_data variable
# with the data related to the hardware from the target machine.
#
# @target Target machine
function learn_device()
{
  local target="$1"
  local flag="$2"
  local ip="$3"
  local port="$4"

  flag=${flag:-'SILENT'}

  target=${target:-"${device_options['target']}"}
  ip=${ip:-"${device_options['ip']}"}
  port=${port:-"${device_options['port']}"}
  if [[ "$target" == "$VM_TARGET" ]]; then
    vm_mount > /dev/null
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      complain 'Please shut down or unmount your VM to continue.'
      exit "$ret"
    fi
  fi

  get_ram "$target" "$flag"
  get_cpu "$target" "$flag"
  get_disk "$target" "$flag"
  get_os "$target" "$flag"
  get_gpu "$target" "$flag"
  get_motherboard "$target" "$flag"
  get_chassis "$target" "$flag"

  if [[ "$target" == "$VM_TARGET" ]]; then
    vm_umount > /dev/null
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      complain "We couldn't unmount your VM."
      exit "$ret"
    fi
    get_img_info
  fi
}

# This function shows the information stored in the device_info_data variable.
function show_data()
{
  local target="${device_options['target']}"
  local ip="${device_options['ip']}"
  local port="${device_options['port']}"

  case "$target" in
    1) # VM_TARGET
      say 'Image:'
      printf '  Type: %s\n' "${device_info_data['img_type']}"
      printf '  Size: %s\n' "$(numfmt --from=si --to=iec "${device_info_data['img_size']}K")"
      ;;
    3) # REMOTE_TARGET
      say 'IP:' "$ip" 'Port:' "$port"
      ;;
  esac

  say 'Chassis:'
  printf '  Type: %s\n' "${device_info_data['chassis']}"

  say 'CPU:'
  printf '  Model: %s\n' "${device_info_data['cpu_model']}"

  if [[ -n "${device_info_data['cpu_currently']}" ]]; then
    printf '  Current frequency (MHz): %s\n' "${device_info_data['cpu_currently']}"
  fi

  if [[ -n "${device_info_data['cpu_max']}" ]]; then
    printf '  Max frequency (MHz): %s\n' "${device_info_data['cpu_max']}"
  fi

  if [[ -n "${device_info_data['cpu_min']}" ]]; then
    printf '  Min frequency (MHz): %s\n' "${device_info_data['cpu_min']}"
  fi

  if [[ -n "${device_info_data['ram']}" ]]; then
    say 'RAM:'
    printf '  Total RAM: %s\n' "$(numfmt --from=si --to=iec "${device_info_data['ram']}K")"
  fi

  say 'Storage devices:'
  printf '  Root filesystem: %s\n' "${device_info_data['root_path']}"
  printf '  Size: %s\n' "${device_info_data['disk_size']}"
  printf '  Mounted on: %s\n' "${device_info_data['fs_mount']}"

  say 'Operating System:'
  printf '  Distribution: %s\n' "${device_info_data['os']}"
  printf '  Desktop environments: %s\n' "${device_info_data['desktop_environment']}"

  if [[ "$target" != "$VM_TARGET" ]]; then
    say 'Motherboard:'
    printf '  Vendor: %s\n' "${device_info_data['motherboard_vendor']}"
    printf '  Name: %s\n' "${device_info_data['motherboard_name']}"
  fi

  if [[ -n "${gpus[*]}" ]]; then
    say 'GPU:'
    for g in "${!gpus[@]}"; do
      printf '  Model: %s\n' "$(echo "${gpus[$g]}" | cut -d';' -f1)"
      printf '  Provider: %s\n' "$(echo "${gpus[$g]}" | cut -d';' -f2-)"
    done
  fi
}

# This function parses the options provided to 'kw device' and makes the
# necessary ajustments. If no argument is provided, then the function assigns
# the value from configurations[default_deploy_target] to the option variable;
# if there is no value there either, then option is by default assigned to
# local.
function device_info_parser()
{
  local option="$1"
  local remote="$2"
  device_options['ip']="${configurations[ssh_ip]}"
  device_options['port']="${configurations[ssh_port]}"

  if [[ -z "$option" && -n "${configurations[default_deploy_target]}" ]]; then
    option='--'"${configurations[default_deploy_target]}"
  fi
  option=${option:-'--local'}

  case "$option" in
    --vm)
      device_options['target']="$VM_TARGET"
      ;;
    --local)
      device_options['target']="$LOCAL_TARGET"
      ;;
    --remote)
      if [[ -n "$remote" ]]; then
        device_options['ip']=$(get_based_on_delimiter "$remote" ":" 1)
        device_options['port']=$(get_based_on_delimiter "$remote" ":" 2)
      fi

      device_options['target']="$REMOTE_TARGET"
      ;;
    -h)
      device_info_help
      exit 0
      ;;
    *)
      complain "Invalid option: $option"
      return 22 # EINVAL
      ;;
  esac
}

function device_info_help()
{
  echo -e 'kw device:\n' \
    '\t--local - Retrieve information from this machine\n' \
    '\t--vm - Retrieve information from a virtual machine\n' \
    '\t--remote [IP:PORT] - Retrieve information from a remote machine'
}
