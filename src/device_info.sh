# This file deals with functions related to hardware information

include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/lib/remote.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/vm.sh"

declare -gA device_info_data=(['ram']='' # RAM memory in KB
  ['cpu_model']=''                       # CPU model vendor
  ['cpu_architecture']=''                # CPU architecture
  ['cpu_currently']=''                   # Current frequency of CPU in MHz
  ['cpu_max']=''                         # Maximum frequency of CPU in MHz
  ['cpu_min']=''                         # Minimum frequency of CPU in MHz
  ['desktop_environment']=''             # Desktop environment
  ['kernel_name']=''                     # Kernel name
  ['kernel_version']=''                  # Kernel version
  ['disk_size']=''                       # Disk size in KB
  ['root_path']=''                       # Root directory path
  ['fs_mount']=''                        # Path where root is mounted
  ['os_name']=''                         # Distro's name
  ['os_version']=''                      # Distro's version
  ['os_id_like']=''                      # Distro which this distro is based on
  ['motherboard_name']=''                # Motherboard name
  ['motherboard_vendor']=''              # Motherboard vendor
  ['chassis']=''                         # Chassis type
  ['img_size']=''                        # Size of VM image in KB
  ['img_type']=''                        # Type of VM image
  ['n_displays']=''                      # Total number of connected displays
  ['n_active']=''                        # Number of active displays
  ['name_resol']=''                      # Name and resolution of active displays
  ['active_displays']=''                 # Name of active displays
  ['display_resolution']='')             # Resolution of active displays

declare -gA gpus

declare -gA options_values

# This function calls other functions to process and display the hardware
# information of a target machine.
function device_main()
{
  local flag

  if [[ "$1" =~ -h|--help ]]; then
    device_info_help "$1"
    exit 0
  fi

  device_info_parser "$@"
  if [[ "$?" != 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    device_info_help
    exit 22 # EINVAL
  fi

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'
  flag=${flag:-'SILENT'}

  if [[ "${options_values['TARGET']}" == "$REMOTE_TARGET" ]]; then
    # Check connection before try to work with remote
    is_ssh_connection_configured "$flag"
    if [[ "$?" != 0 ]]; then
      ssh_connection_failure_message
      exit 101 # ENETUNREACH
    fi
  fi

  learn_device "${options_values['TARGET']}" "$flag"
  show_data "$flag"
}

# This function populates the ram element from the device_info_data global
# variable with the total RAM memory from the target machine in kB.
#
# @target Target machine
function get_ram()
{
  local flag="$1"
  local target=${options_values['TARGET']}
  local ram
  local cmd

  flag=${flag:-'SILENT'}
  cmd="[ -f '/proc/meminfo' ] && cat /proc/meminfo | grep 'MemTotal' | grep --only-matching '[0-9]*'"

  case "$target" in
    1) # VM_TARGET
      ram="$(printf '%s\n' "${vm_config[qemu_hw_options]}" | sed --regexp-extended 's/.*-m ?([0-9]+).*/\1/')"
      cmd="numfmt --from-unit=M --to-unit=K ${ram}"
      show_verbose "$flag" "$cmd"
      ram=$(cmd_manager 'SILENT' "$cmd")
      ;;
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      ram=$(cmd_manager 'SILENT' "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      ram=$(cmd_remotely "$cmd" 'SILENT')
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    printf '%s\n' "$ram"
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
  local cpu_model
  local cpu_frequency
  local cpu_architecture
  local cpu_currently
  local cpu_max
  local cpu_min
  local cmd

  flag=${flag:-'SILENT'}
  cmd_model="lscpu | grep 'Model name:' | sed --regexp-extended 's/Model name:\s+//g' | cut --delimiter=' ' -f1"
  cmd_frequency="lscpu | grep MHz | sed --regexp-extended 's/(CPU.*)/\t\t\1/'"
  cmd_architecture="lscpu | grep 'Architecture:' | sed --regexp-extended 's/Architecture:\s+//g' | cut --delimiter=' ' -f1"

  case "$target" in
    1) #VM_TARGET
      cpu_model='Virtual'

      show_verbose "$flag" "$cmd_architecture"
      cpu_architecture=$(cmd_manager 'SILENT' "$cmd_architecture")
      ;;
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd_model"
      cpu_model=$(cmd_manager 'SILENT' "$cmd_model")

      show_verbose "$flag" "$cmd_frequency"
      cpu_frequency=$(cmd_manager 'SILENT' "$cmd_frequency")

      show_verbose "$flag" "$cmd_architecture"
      cpu_architecture=$(cmd_manager 'SILENT' "$cmd_architecture")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd_model"
      cpu_model=$(cmd_remotely "$cmd_model" 'SILENT')

      show_verbose "$flag" "$cmd_frequency"
      cpu_frequency=$(cmd_remotely "$cmd_frequency" 'SILENT')

      show_verbose "$flag" "$cmd_architecture"
      cpu_architecture=$(cmd_manager 'SILENT' "$cmd_architecture")
      ;;
  esac

  device_info_data['cpu_model']="$cpu_model"
  device_info_data['cpu_architecture']="$cpu_architecture"

  if [[ "$flag" == 'TEST_MODE' ]]; then
    printf '%s\n%s\n%s\n' "$cpu_model" "$cpu_frequency" "$cpu_architecture"
    return 0
  fi

  cmd="printf '%s\n' '${cpu_frequency}' | grep 'CPU MHz'"
  show_verbose "$flag" "$cmd"
  cpu_currently=$(cmd_manager 'SILENT' "$cmd")

  cmd="printf '%s\n' '${cpu_frequency}' | grep 'CPU max MHz'"
  show_verbose "$flag" "$cmd"
  cpu_max=$(cmd_manager 'SILENT' "$cmd")

  cmd="printf '%s\n' '${cpu_frequency}' | grep 'CPU min MHz'"
  show_verbose "$flag" "$cmd"
  cpu_min=$(cmd_manager 'SILENT' "$cmd")

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
  local info
  local size
  local mount
  local cmd
  local fs

  cmd="df -h / | tail --lines=1 | tr --squeeze-repeats ' '"
  case "$target" in
    1) # VM_TARGET
      cmd="df -h ${vm_config[mount_point]} | tail --lines=1 | tr --squeeze-repeats ' '"
      show_verbose "$flag" "$cmd"
      info=$(cmd_manager 'SILENT' "$cmd")
      ;;
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      info=$(cmd_manager 'SILENT' "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      info=$(cmd_remotely "$cmd" 'SILENT')
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    printf '%s\n' "$info"
    return 0
  fi

  cmd="printf '%s\n' '${info}' | cut -d' ' -f1"
  show_verbose "$flag" "$cmd"
  fs=$(cmd_manager 'SILENT' "$cmd")

  cmd="printf '%s\n' '${info}' | cut -d' ' -f2"
  show_verbose "$flag" "$cmd"
  size=$(cmd_manager 'SILENT' "$cmd")

  cmd="printf '%s\n' '${info}' | cut -d' ' -f6"
  show_verbose "$flag" "$cmd"
  mount=$(cmd_manager 'SILENT' "$cmd")

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
  local raw_os_release
  local root_path
  local os_release_path='/etc/os-release'
  local cmd
  local os_name
  local os_version
  local os_id_like

  target=${target:-"${options_values['TARGET']}"}

  case "$target" in
    1) # VM_TARGET
      root_path="${vm_config[mount_point]}"
      cmd="cat $(join_path "$root_path" "$os_release_path")"
      show_verbose "$flag" "$cmd"
      raw_os_release=$(cmd_manager 'SILENT' "$cmd")
      ;;
    2) # LOCAL_TARGET
      root_path='/'
      cmd="cat $(join_path "$root_path" "$os_release_path")"
      show_verbose "$flag" "$cmd"
      raw_os_release=$(cmd_manager 'SILENT' "$cmd")
      ;;
    3) # REMOTE_TARGET
      root_path='/'
      cmd="cat $(join_path "$root_path" "$os_release_path")"
      show_verbose "$flag" "$cmd"
      raw_os_release=$(cmd_remotely "$cmd" 'SILENT')
      ;;
  esac

  cmd="printf '%s\n' '${raw_os_release}' | sed --quiet --expression='/^NAME=/p' --expression='/^VERSION=/p' --expression='/^ID_LIKE=/p'"
  show_verbose "$flag" "$cmd"
  raw_os_release=$(cmd_manager 'SILENT' "$cmd")

  # the last sed serves to remove the double quotes if present
  cmd="printf '%s\n' '${raw_os_release}' | sed --quiet --regexp-extended 's/^NAME=//p' | tail -n1 | sed --regexp-extended \"s|^(['\\\"])(.*)\1$|\2|g\""
  show_verbose "$flag" "$cmd"
  os_name=$(cmd_manager 'SILENT' "$cmd")

  cmd="printf '%s\n' '${raw_os_release}' | sed --quiet --regexp-extended 's/^VERSION=//p' | tail -n1 | sed --regexp-extended \"s|^(['\\\"])(.*)\1$|\2|g\""
  show_verbose "$flag" "$cmd"
  os_version=$(cmd_manager 'SILENT' "$cmd")

  cmd="printf '%s\n' '${raw_os_release}' | sed --quiet --regexp-extended 's/^ID_LIKE=//p' | tail -n1 | sed --regexp-extended \"s|^(['\\\"])(.*)\1$|\2|g\""
  show_verbose "$flag" "$cmd"
  os_id_like=$(cmd_manager 'SILENT' "$cmd")

  if [[ "$flag" == 'TEST_MODE' ]]; then
    printf '%s\n' "$cmd"
    return 0
  fi

  device_info_data['os_name']="$os_name"
  device_info_data['os_version']="$os_version"
  device_info_data['os_id_like']="$os_id_like"
}

# This function populates the desktop environment variables from the
# device_info_data variable.
#
# @target Target machine
# @remote IP address of the target machine
# @port Destination for sending the file
function get_desktop_environment()
{
  local target="$1"
  local flag="$2"
  local cmd
  local desktop_env
  local formatted_de='unidentified'
  local ux_regx="'gnome-shell$|kde|mate|cinnamon|lxsession|openbox$'"

  target=${target:-"${options_values['TARGET']}"}
  cmd="ps -A | grep --invert-match dev | grep --ignore-case --only-matching --extended-regexp --max-count=1 ${ux_regx}"

  case "$target" in
    1) # VM_TARGET
      desktop_env=$(find "${vm_config[mount_point]}/usr/share/xsessions" -type f -printf '%f ' | sed --regexp-extended 's/\.desktop//g')
      ;;
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      desktop_env=$(cmd_manager 'SILENT' "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      desktop_env=$(cmd_remotely "$cmd" 'SILENT')
      ;;
  esac

  case "$desktop_env" in
    gnome-shell)
      formatted_de='gnome'
      ;;
    lxsession)
      formatted_de='lxde'
      ;;
    openbox)
      formatted_de='openbox'
      ;;
    kde)
      formatted_de='kde'
      ;;
    mate)
      formatted_de='mate'
      ;;
    cinnamon)
      formatted_de='cinnamon'
      ;;
  esac

  device_info_data['desktop_environment']="$formatted_de"
}

function get_kernel_version()
{
  local target="$1"
  local flag="$2"
  local cmd_version
  local kernel_version

  cmd_name='uname -s'
  cmd_version="uname -r"

  case "$target" in
    1) # VM_TARGET
      kernel_name=$("$cmd_name")
      kernel_version=$("$cmd_version")
      ;;
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd_name"
      kernel_name=$(cmd_manager 'SILENT' "$cmd_name")

      show_verbose "$flag" "$cmd_version"
      kernel_version=$(cmd_manager 'SILENT' "$cmd_version")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd_name"
      kernel_name=$(cmd_manager 'SILENT' "$cmd_name")

      show_verbose "$flag" "$cmd_version"
      kernel_version=$(cmd_remotely "$cmd_version" 'SILENT')
      ;;
  esac

  device_info_data['kernel_name']="$kernel_name"
  device_info_data['kernel_version']="$kernel_version"
}

# This function populates the gpu associative array with the vendor and
# fetchable memory from each GPU found in the target machine.
function get_gpu()
{
  local target="$1"
  local flag="$2"
  local pci_addresses
  local gpu_info
  local cmd_pci_address
  local cmd

  flag=${flag:-'SILENT'}

  # The first thing we want to do is retrieve all PCI addresses from any GPU in
  # the target machine. After that, we will get, for each GPU, the desired
  # information.
  cmd_pci_address="lspci | grep --regexp=VGA --regexp=Display --regexp=3D | cut --delimiter=' ' -f1"
  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd_pci_address"
      pci_addresses=$(cmd_manager 'SILENT' "$cmd_pci_address")
      for g in $pci_addresses; do
        cmd="lspci -v -s ${g}"
        show_verbose "$flag" "$cmd"
        gpu_info=$(cmd_manager 'SILENT' "$cmd")

        cmd="printf '%s\n' '${gpu_info}' | sed --quiet --regexp-extended '/Subsystem/s/\s*.*:\s+(.*)/\1/p'"
        show_verbose "$flag" "$cmd"
        gpu_name=$(cmd_manager 'SILENT' "$cmd")

        cmd="printf '%s\n' '${gpu_info}' | sed --quiet --regexp-extended '/controller/s/.+controller: *([^\[\(]+).+/\1/p'"
        show_verbose "$flag" "$cmd"
        gpu_provider=$(cmd_manager 'SILENT' "$cmd")
        gpus["$g"]="${gpu_name};${gpu_provider}"
      done
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd_pci_address"
      pci_addresses=$(cmd_remotely "$cmd_pci_address" 'SILENT')
      for g in $pci_addresses; do
        cmd="lspci -v -s ${g}"
        show_verbose "$flag" "$cmd"
        gpu_info=$(cmd_remotely "$cmd" 'SILENT')

        cmd="printf '%s\n' '${gpu_info}' | sed --quiet --regexp-extended '/Subsystem/s/\s*.*:\s+(.*)/\1/p'"
        show_verbose "$flag" "$cmd"
        gpu_name=$(cmd_manager 'SILENT' "$cmd")

        cmd="printf '%s\n' '${gpu_info}' | sed --quiet --regexp-extended '/controller/s/.+controller: *([^\[\(]+).+/\1/p'"
        show_verbose "$flag" "$cmd"
        gpu_provider=$(cmd_manager 'SILENT' "$cmd")
        gpus["$g"]="${gpu_name};${gpu_provider}"
      done
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    printf '%s\n' "$cmd_pci_address"
    return 0
  fi
}

# This function retrieves both the name and vendor from the motherboard of a
# target machine.
#
# @target Target machine
function get_motherboard()
{
  local target="$1"
  local flag="$2"
  local mb_name
  local mb_vendor
  local cmd_name
  local cmd_vendor
  local fallback_name_cmd="cat /proc/cpuinfo | grep Model | cut --delimiter=':' -f2"
  local fallback_vendor_cmd="cat /proc/cpuinfo | grep Hardware | cut --delimiter=':' -f2"

  flag=${flag:-'SILENT'}
  cmd_name='[ -f /sys/devices/virtual/dmi/id/board_name ] && cat /sys/devices/virtual/dmi/id/board_name'
  cmd_vendor='[ -f /sys/devices/virtual/dmi/id/board_vendor ] && cat /sys/devices/virtual/dmi/id/board_vendor'

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd_name"
      mb_name=$(cmd_manager 'SILENT' "$cmd_name")

      show_verbose "$flag" "$cmd_vendor"
      mb_vendor=$(cmd_manager 'SILENT' "$cmd_vendor")

      # Fallback
      if [[ -z "$mb_name" ]]; then
        show_verbose "$flag" "$fallback_name_cmd"
        mb_name=$(cmd_manager 'SILENT' "$fallback_name_cmd")
      fi

      if [[ -z "$mb_vendor" ]]; then
        show_verbose "$flag" "$fallback_vendor_cmd"
        mb_vendor=$(cmd_manager 'SILENT' "$fallback_vendor_cmd")
      fi

      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd_name"
      mb_name=$(cmd_remotely "$cmd_name" 'SILENT')

      show_verbose "$flag" "$cmd_vendor"
      mb_vendor=$(cmd_remotely "$cmd_vendor" 'SILENT')

      # Fallback
      if [[ -z "$mb_name" ]]; then
        show_verbose "$flag" "$fallback_name_cmd"
        mb_name=$(cmd_remotely "$fallback_name_cmd" 'SILENT')
      fi

      if [[ -z "$mb_vendor" ]]; then
        show_verbose "$flag" "$fallback_vendor_cmd"
        mb_vendor=$(cmd_remotely "$fallback_vendor_cmd" 'SILENT')
      fi
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    printf '%s\n' "$cmd_name" \
      "$cmd_vendor"
    return 0
  fi

  device_info_data['motherboard_name']=$(str_strip "$mb_name")
  device_info_data['motherboard_vendor']=$(str_strip "$mb_vendor")
}

# This function gets the chassis type of the target machine.
#
# @target Target machine
function get_chassis()
{
  local target="$1"
  local flag="$2"
  local dmi_cmd
  local chassis_type=2 # Unknown
  local dmi_file_path='/sys/devices/virtual/dmi/id/chassis_type'
  local dmi_check_cmd="test -f ${dmi_file_path}"
  local cmd

  declare -a chassis_table=('Other' 'Unknown' 'Desktop' 'Low Profile Desktop'
    'Pizza Box' 'Mini Tower' 'Tower' 'Portable' 'Laptop' 'Notebook' 'Hand Held'
    'Docking Station' 'All in One' 'Sub Notebook' 'Space-Saving' 'Lunch Box'
    'Main System Chassis' 'Expansion Chassis' 'SubChassis' 'Bus Expansion Chassis'
    'Peripheral Chassis' 'Storage Chassis' 'Rack Mount Chassis' 'Sealed-Case PC'
    'VM')

  flag=${flag:-'SILENT'}
  dmi_cmd='cat /sys/devices/virtual/dmi/id/chassis_type'

  case "$target" in
    1) # VM_TARGET
      chassis_type=25
      ;;
    2) # LOCAL_TARGET
      if [[ -f "$dmi_file_path" ]]; then
        show_verbose "$flag" "$dmi_cmd"
        chassis_type=$(cmd_manager 'SILENT' "$dmi_cmd")
      fi
      ;;
    3) # REMOTE_TARGET
      cmd="test -f ${dmi_file_path}"
      show_verbose "$flag" "$cmd"
      cmd_remotely "$cmd" "$flag"
      if [[ "$?" == 0 ]]; then
        show_verbose "$flag" "$dmi_cmd"
        chassis_type=$(cmd_remotely "$dmi_cmd" 'SILENT')
      fi
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    printf '%s\n' "$dmi_cmd"
    return 0
  fi

  device_info_data['chassis']="${chassis_table[((chassis_type - 1))]}"
}

# This function populates the img_size and img_type values from the
# device_info_data variable.
function get_img_info()
{
  local img_info
  local img_size
  local img_type

  img_info=$(file "${vm_config[qemu_path_image]}")
  img_size=$(printf '%s\n' "$img_info" | sed --regexp-extended 's/.*: .+, ([0-9]+) bytes/\1/')
  img_type=$(printf '%s\n' "$img_info" | sed --regexp-extended 's/.*: (.+),.+/\1/')

  # The variable img_size stores the image size in bytes. It has to be converted
  # to kB when we store it in the device_info_data variable.
  device_info_data['img_size']=$(numfmt --to-unit=1000 "$img_size")
  device_info_data['img_type']="$img_type"
}

# This function shows displays information
function get_display_info()
{
  local act_name
  local act_resol
  local name_resol
  local n_display
  local n_active

  n_display=$(xrandr -q | wc -l)

  n_active=$(xrandr -q | grep -c " connected ")

  act_name=$(xrandr | grep " connected " | awk '{ print $1 }')
  act_resol=$(xrandr | grep "\*" | awk '{ print $1 }')
  name_resol=$(xrandr | grep " connected " | awk '{ print $1, "- resolution", $4 }')

  device_info_data['n_display']="$n_display"
  device_info_data['n_active']="$n_active"
  device_info_data['active_displays']="$act_name"
  device_info_data['display_resolution']="$act_resol"
  device_info_data['name_resol']="$name_resol"
}

# This function calls other functions to populate the device_info_data variable
# with the data related to the hardware from the target machine.
#
# @target Target machine
function learn_device()
{
  local target="$1"
  local flag="$2"

  flag=${flag:-'SILENT'}

  target=${target:-"${options_values['TARGET']}"}

  if [[ "$target" == "$VM_TARGET" ]]; then
    vm_mount > /dev/null
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      complain 'Please shut down or unmount your VM to continue.'
      exit "$ret"
    fi
  fi

  get_ram "$flag"
  get_cpu "$target" "$flag"
  get_disk "$target" "$flag"
  get_os "$target" "$flag"
  get_desktop_environment "$target" "$flag"
  get_kernel_version "$target" "$flag"
  get_gpu "$target" "$flag"
  get_motherboard "$target" "$flag"
  get_chassis "$target" "$flag"
  get_display_info

  if [[ "$target" == "$VM_TARGET" ]]; then
    vm_umount > /dev/null
    ret="$?"
    if [[ "$ret" != 0 ]]; then
      complain 'We could not unmount your VM.'
      exit "$ret"
    fi
    get_img_info
  fi
}

# This function shows the information stored in the device_info_data variable.
function show_data()
{
  local flag="$1"
  local target

  target=${target:-"${options_values['TARGET']}"}

  case "$target" in
    1) # VM_TARGET
      say 'Image:'
      printf '  Type: %s\n' "${device_info_data['img_type']}"
      printf '  Size: %s\n' "$(numfmt --from=si --to=iec "${device_info_data['img_size']}K")"
      ;;
    3) # REMOTE_TARGET
      say 'Remote device'
      ;;
  esac

  say 'Chassis:'
  printf '  Type: %s\n' "${device_info_data['chassis']}"

  say 'Display:'
  printf '  Number of connected displays: %s\n' "${device_info_data['n_display']}"
  printf '  Number of active displays: %s\n' "${device_info_data['n_active']}"
  printf '  Name of active displays: \n'
  for name in ${device_info_data["active_displays"]}; do
    printf '   -%s\n' "${name}"
  done
  printf '  Resolution of active displays: \n'
  for res in ${device_info_data["display_resolution"]}; do
    printf '   -%s\n' "${res}"
  done

  say 'CPU:'
  printf '  Model: %s\n' "${device_info_data['cpu_model']}"
  printf '  Architecture: %s\n' "${device_info_data['cpu_architecture']}"

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
  printf '  Distribution: %s\n' "${device_info_data['os_name']}"
  if [[ -n "${device_info_data['os_version']}" ]]; then
    printf '  Distribution version: %s\n' "${device_info_data['os_version']}"
  fi
  if [[ -n "${device_info_data['os_id_like']}" ]]; then
    printf '  Distribution base: %s\n' "${device_info_data['os_id_like']}"
  fi
  printf '  Desktop environments: %s\n' "${device_info_data['desktop_environment']}"

  say 'Kernel:'
  printf '  Name: %s\n' "${device_info_data['kernel_name']}"
  printf '  Version/Release: %s\n' "${device_info_data['kernel_version']}"

  if [[ "$target" != "$VM_TARGET" ]]; then
    say 'Motherboard:'
    printf '  Vendor: %s\n' "${device_info_data['motherboard_vendor']}"
    printf '  Name: %s\n' "${device_info_data['motherboard_name']}"
  fi

  if [[ -n "${gpus[*]}" ]]; then
    say 'GPU:'
    for g in "${!gpus[@]}"; do
      printf '  Model: %s\n' "$(printf '%s\n' "${gpus[$g]}" | cut -d';' -f1)"
      printf '  Provider: %s\n' "$(printf '%s\n' "${gpus[$g]}" | cut -d';' -f2-)"
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
  local long_options='help,vm,local,remote:,verbose'
  local short_options='h'

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw device' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['VM']=''
  options_values['LOCAL']=''
  options_values['REMOTE']=''
  options_values['VERBOSE']=''

  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_USER']=''

  # Set basic default values
  if [[ -n ${deploy_config[default_deploy_target]} ]]; then
    local config_file_deploy_target=${deploy_config[default_deploy_target]}
    options_values['TARGET']=${deploy_target_opt[$config_file_deploy_target]}
  else
    options_values['TARGET']="$REMOTE_TARGET"
  fi

  populate_remote_info ''
  if [[ "$?" == 22 ]]; then
    options_values['ERROR']="Invalid remote: ${remote}"
    return 22 # EINVAL
  fi

  eval "set -- $options"
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --remote)
        populate_remote_info "$2"
        if [[ "$?" == 22 ]]; then
          options_values['ERROR']="Invalid remote: ${2}"
          return 22 # EINVAL
        fi
        options_values['TARGET']="$REMOTE_TARGET"
        shift 2
        ;;
      --local)
        options_values['TARGET']="$LOCAL_TARGET"
        shift
        ;;
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      --) # End of options, beginning of arguments
        shift
        ;;
      *)
        options_values['ERROR']="$1"
        return 22 # EINVAL
        ;;
    esac
  done
}

function device_info_help()
{
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'device'
    return
  fi
  printf '%s\n' 'kw device:' \
    '  device [--local] - Retrieve information from this machine' \
    '  device [--vm] - Retrieve information from a virtual machine' \
    '  device [--remote [<ip>:<port>]] - Retrieve information from a remote machine' \
    '  device (--verbose) - Show a detailed output'
}

load_kworkflow_config
load_deploy_config
load_vm_config
