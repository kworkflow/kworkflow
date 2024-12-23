# This file deals with functions related to hardware information

include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/lib/remote.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/distros.sh"

declare -gA device_info_data=(['ram_total']='' # RAM memory in GiB
  ['ram_available']=''                         # Available RAM
  ['ram_type']=''                              # Ram Type
  ['ram_capacity']=''                          # Total RAM capacity
  ['ram_installed']=''                         # Total installed RAM
  ['cpu_model']=''                       # CPU model vendor
  ['cpu_model_name']=''                  # CPU model vendor name
  ['cpu_architecture']=''                # CPU architecture
  ['cpu_speed']=''                       # CPU speed in MHz
  ['cpu_total_cores']=''                 # Total of cores
  ['desktop_environment']=''             # Desktop environment
  ['compositor']=''                      # Compositor name
  ['window_system']=''                   # Window system type
  ['gpu']=''                             # GPU name
  ['gpu_driver']=''                      # GPU driver name
  ['kernel_name']=''                     # Kernel name
  ['kernel_release']=''                  # Kernel release
  ['kernel_version']=''                  # Kernel version
  ['kernel_machine']=''                  # Kernel machine type
  ['disk_size']=''                       # Disk size in KB
  ['root_path']=''                       # Root directory path
  ['fs_mount']=''                        # Path where root is mounted
  ['fs_type']=''                         # Filesystem type info
  ['disk_used']=''                       # Total of used space
  ['os_name']=''                         # Distro's name
  ['motherboard_name']=''                # Motherboard name
  ['motherboard_vendor']=''              # Motherboard vendor
  ['chassis']=''                         # Chassis type
  ['img_size']=''                        # Size of VM image in KB
  ['img_type']='')                       # Type of VM image

declare -ga gpus

declare -gA options_values

# This function calls other functions to process and display the hardware
# information of a target machine.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
function device_info_main()
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
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
function get_ram()
{
  local target="$1"
  local flag="$2"
  local ram
  local cmd

  flag=${flag:-'SILENT'}
  cmd='inxi --tty --width 1 --color 0 --memory-short'

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      ram=$(cmd_manager 'SILENT' "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      ram=$(cmd_remotely 'SILENT' "$cmd")
      ;;
  esac

  device_info_data['ram_total']="$(get_string_after_delimiter "$ram" 'total: ')"
  device_info_data['ram_available']="$(get_string_after_delimiter "$ram" 'available: ')"
  device_info_data['ram_type']="$(get_string_after_delimiter "$ram" 'type: ')"
  device_info_data['ram_capacity']="$(get_string_after_delimiter "$ram" 'capacity: ')"
  device_info_data['ram_installed']="$(get_string_after_delimiter "$ram" 'installed: ')"
}

# This function provides the model and frequency of the CPU from a machine
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
function get_cpu()
{
  local target="$1"
  local flag="$2"
  local cpu_info_output
  local cpu_vendor_name
  local cpu_total_cores
  local cmd_cpu_info
  local cmd_architecture
  local cpu_architecture
  local cpu_speed
  local cmd
  local test_flag='SILENT'

  flag=${flag:-'SILENT'}
  cmd_cpu_info='inxi --tty --width 1 --color 0 --cpu'
  cmd_architecture='uname --machine'

  if [[ "$flag" == 'TEST_MODE' ]]; then
    test_flag='TEST_MODE'
  fi

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd_cpu_info"
      cpu_info_output=$(cmd_manager "$test_flag" "$cmd_cpu_info")

      show_verbose "$flag" "$cmd_architecture"
      cpu_architecture=$(cmd_manager "$test_flag" "$cmd_architecture")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd_cpu_info"
      cpu_info_output=$(cmd_remotely "$test_flag" "$cmd_cpu_info")

      show_verbose "$flag" "$cmd_architecture"
      cpu_architecture=$(cmd_remotely "$test_flag" "$cmd_architecture")
      ;;
  esac

  cpu_vendor_name=$(get_string_after_delimiter "$cpu_info_output" 'model: ')
  cpu_speed=$(get_string_after_delimiter "$cpu_info_output" 'avg: ')
  cpu_total_cores=$(printf '%s' "$cpu_info_output" | tail -2 | head -1)
  cpu_total_cores=$(printf '%s' "$cpu_total_cores" | cut --delimiter ':' --fields=1)
  cpu_total_cores=$(str_strip "$cpu_total_cores")

  device_info_data['cpu_model_name']="$cpu_vendor_name"
  device_info_data['cpu_speed']="$cpu_speed"
  device_info_data['cpu_total_cores']="$cpu_total_cores"
  device_info_data['cpu_architecture']="$cpu_architecture"
}

# This function populates the values from the size and fs (filesystem) key of
# the device_info_data variable.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
function get_disk()
{
  local target="$1"
  local flag="$2"
  local partition_info
  local size
  local mount
  local cmd
  local fs
  local dev
  local used_size
  local test_flag='SILENT'

  flag=${flag:-'SILENT'}
  [[ "$flag" == 'TEST_MODE' ]] && test_flag='TEST_MODE'

  cmd='inxi --tty --width 1 --color 0 --partitions-full'
  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      partition_info=$(cmd_manager "$test_flag" "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      partition_info=$(cmd_remotely "$test_flag" "$cmd")
      ;;
  esac

  partition_info=$(printf '%s' "$partition_info" | grep --extended-regexp --after-context=4 ': /$')
  mount=$(printf '%s' "$partition_info" | head -1)
  mount=$(get_string_after_delimiter "$mount" ':')

  fs=$(get_string_after_delimiter "$partition_info" 'fs: ')
  size=$(get_string_after_delimiter "$partition_info" 'size: ')
  used_size=$(get_string_after_delimiter "$partition_info" 'used: ')
  dev=$(get_string_after_delimiter "$partition_info" 'dev: ')

  device_info_data['disk_size']="$size"
  device_info_data['root_path']="$dev"
  device_info_data['fs_mount']="$mount"
  device_info_data['fs_type']="$fs"
  device_info_data['disk_used']="$used_size"
}

# This function populates the os and desktop environment variables from the
# device_info_data variable.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
function get_os()
{
  local target="$1"
  local flag="$2"
  local raw_system_info
  local cmd='inxi --tty --width 1 --color 0 --system'
  local os_name
  local test_flag='SILENT'

  flag=${flag:-'SILENT'}
  [[ "$flag" == 'TEST_MODE' ]] && test_flag='TEST_MODE'

  target=${target:-"${options_values['TARGET']}"}

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      raw_system_info=$(cmd_manager "$test_flag" "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      raw_system_info=$(cmd_remotely "$test_flag" "$cmd")
      ;;
  esac

  os_name=$(get_string_after_delimiter "$raw_system_info" 'Distro: ')
  desktop=$(get_string_after_delimiter "$raw_system_info" 'Desktop: ')

  device_info_data['os_name']="$os_name"
  device_info_data['desktop_environment']="$desktop"
}

# This function populates the desktop environment variables from the
# device_info_data variable.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
# @remote IP address of the target machine
# @port Destination for sending the file
function get_desktop_environment()
{
  local target="$1"
  local flag="$2"
  local cmd
  local desktop_env
  local formatted_de='unidentified'
  local ux_regx="'gnome-shell$|kde|mate|cinnamon|lxsession|gamescope|openbox$'"

  target=${target:-"${options_values['TARGET']}"}
  cmd="ps -A | grep --invert-match dev | grep --ignore-case --only-matching --extended-regexp --max-count=1 ${ux_regx}"

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      desktop_env=$(cmd_manager 'SILENT' "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      desktop_env=$(cmd_remotely 'SILENT' "$cmd")
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
    gamescope)
      formatted_de='gamescope'
      ;;
  esac

  device_info_data['compositor']="$formatted_de"
}

# This function populates kernel variables from the device_info_data
# variable.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
function get_kernel_info()
{
  local target="$1"
  local flag="$2"
  local cmd_name
  local cmd_version
  local cmd_release
  local cmd_machine
  local kernel_name
  local kernel_version
  local kernel_release
  local kernel_machine_type

  cmd_name='uname --kernel-name'
  cmd_release='uname --kernel-release'
  cmd_version='uname --kernel-version'
  cmd_machine='uname --machine'

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd_name"
      kernel_name=$(cmd_manager 'SILENT' "$cmd_name")

      show_verbose "$flag" "$cmd_release"
      kernel_release=$(cmd_manager 'SILENT' "$cmd_release")

      show_verbose "$flag" "$cmd_version"
      kernel_version=$(cmd_manager 'SILENT' "$cmd_version")

      show_verbose "$flag" "$cmd_machine"
      kernel_machine=$(cmd_manager 'SILENT' "$cmd_machine")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd_name"
      kernel_name=$(cmd_remotely 'SILENT' "$cmd_name")

      show_verbose "$flag" "$cmd_release"
      kernel_release=$(cmd_remotely 'SILENT' "$cmd_release")

      show_verbose "$flag" "$cmd_version"
      kernel_version=$(cmd_remotely 'SILENT' "$cmd_version")

      show_verbose "$flag" "$cmd_machine"
      kernel_machine=$(cmd_remotely 'SILENT' "$cmd_machine")
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    printf '%s\n%s\n' "$cmd_name" "$cmd_release" "$cmd_version" "$cmd_machine"
    return 0
  fi

  device_info_data['kernel_name']="$kernel_name"
  device_info_data['kernel_release']="$kernel_release"
  device_info_data['kernel_version']="$kernel_version"
  device_info_data['kernel_machine']="$kernel_machine"
}

# This function populates the gpu associative array with the vendor and
# fetchable memory from each GPU found in the target machine.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
function get_graphics()
{
  local target="$1"
  local flag="$2"
  local cmd='inxi --tty --width 1 --color 0 --graphics'
  local -a _device_names=()
  local -a _driver_names=()
  local gpu_count
  local window_system
  local display_data
  local graphics_data
  local raw_devices
  local raw_drivers
  local test_flag='SILENT'

  flag=${flag:-'SILENT'}
  [[ "$flag" == 'TEST_MODE' ]] && test_flag='TEST_MODE'

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      graphics_data=$(cmd_manager "$test_flag" "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      graphics_data=$(cmd_remotely "$test_flag" "$cmd")
  esac

  display_data=$(printf '%s' "$graphics_data" | grep --extended-regexp --after-context=10 'Display: ')

  while IFS= read -r line; do
    _device_names+=("$line")
  done < <(printf '%s' "$graphics_data" | grep --only-matching --perl-regexp 'Device-[0-9]+: \K.*')

  while IFS= read -r line; do
    _driver_names+=("$line")
  done < <(printf '%s' "$graphics_data" | grep --only-matching --perl-regexp 'driver: \K.*')

  window_system=$(get_string_after_delimiter "$display_data" 'Display: ')

  gpu_count="${#_device_names[@]}"
  for ((i = 0; i < gpu_count; i++)); do
    gpus["$i"]="${_device_names[$i]},${_driver_names[$i]:-N/A}"
  done

  device_info_data['window_system']="$window_system"
}

# This function retrieves both the name and vendor from the motherboard of a
# target machine.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
function get_motherboard()
{
  local target="$1"
  local flag="$2"
  local motherboard_name
  local motherboard_vendor
  local inxi_machine_output
  local cmd='inxi --tty --width 1 --color 0 --machine'
  local test_flag='SILENT'

  flag=${flag:-'SILENT'}
  [[ "$flag" == 'TEST_MODE' ]] && test_flag='TEST_MODE'

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      inxi_machine_output=$(cmd_manager "$test_flag" "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      inxi_machine_output=$(cmd_remotely "$test_flag" "$cmd")
      ;;
  esac

  motherboard_vendor=$(get_string_after_delimiter "$inxi_machine_output" 'Mobo: ')
  motherboard_model=$(get_string_after_delimiter "$inxi_machine_output" 'model: ')

  device_info_data['motherboard_vendor']="$motherboard_vendor"
  device_info_data['motherboard_name']="$motherboard_model"
}

# This function gets the chassis type of the target machine.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
function get_chassis()
{
  local target="$1"
  local flag="$2"
  local cmd='inxi --tty --width 1 --color 0 --machine'
  local inxi_machine_output
  local test_flag='SILENT'

  flag=${flag:-'SILENT'}
  [[ "$flag" == 'TEST_MODE' ]] && test_flag='TEST_MODE'

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      inxi_machine_output=$(cmd_manager "$test_flag" "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      inxi_machine_output=$(cmd_remotely "$test_flag" "$cmd")
      ;;
  esac

  device_info_data['chassis']=$(get_string_after_delimiter "$inxi_machine_output" 'Type: ')
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

# This function calls other functions to populate the device_info_data variable
# with the data related to the hardware from the target machine.
#
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
function learn_device()
{
  local target="$1"
  local flag="$2"

  flag=${flag:-'SILENT'}

  target=${target:-"${options_values['TARGET']}"}

  get_ram "$target" "$flag"
  get_cpu "$target" "$flag"
  get_disk "$target" "$flag"
  get_os "$target" "$flag"
  get_desktop_environment "$target" "$flag"
  get_kernel_info "$target" "$flag"
  get_graphics "$target" "$flag"
  get_motherboard "$target" "$flag"
  get_chassis "$target" "$flag"
}

# This function shows the information stored in the device_info_data variable.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
function show_data()
{
  local flag="$1"
  local target

  target=${target:-"${options_values['TARGET']}"}

  case "$target" in
    3) # REMOTE_TARGET
      say 'Remote device'
      ;;
  esac

  say 'Chassis:'
  printf '  Type: %s\n' "${device_info_data['chassis']}"

  say 'CPU:'
  printf '  Model: %s\n' "${device_info_data['cpu_model_name']}"
  printf '  Architecture: %s\n' "${device_info_data['cpu_architecture']}"

  if [[ -n "${device_info_data['cpu_speed']}" ]]; then
    printf '  Frequency (MHz/Avg): %s\n' "${device_info_data['cpu_speed']}"
  fi

  if [[ -n "${device_info_data['cpu_total_cores']}" ]]; then
    printf '  Total Cores: %s\n' "${device_info_data['cpu_total_cores']}"
  fi

  say 'Memory:'
  printf '  Total RAM: %s\n' "${device_info_data['ram_total']}"
  printf '  Available RAM: %s\n' "${device_info_data['ram_available']}"
  printf '  RAM Type: %s\n' "${device_info_data['ram_type']}"
  printf '  RAM capacity: %s\n' "${device_info_data['ram_capacity']}"
  printf '  Total RAM installed: %s\n' "${device_info_data['ram_installed']}"

  say 'Storage boot partitions:'
  printf '  Root filesystem: %s\n' "${device_info_data['root_path']}"
  printf '  Size: %s\n' "${device_info_data['disk_size']}"
  printf '  Used size: %s\n' "${device_info_data['disk_used']}"
  printf '  File system type: %s\n' "${device_info_data['fs_type']}"
  printf '  Mounted on: %s\n' "${device_info_data['fs_mount']}"

  say 'Distro info:'
  printf '  Distribution: %s\n' "${device_info_data['os_name']}"
  if [[ -n ${device_info_data['desktop_environment']} ]]; then
    printf '  Desktop environment: %s\n' "${device_info_data['desktop_environment']}"
  fi

  if [[ -n ${device_info_data['window_system']} ]]; then
    printf '  Window System: %s\n' "${device_info_data['window_system']}"
  fi

  if [[ -n ${device_info_data['compositor']} ]]; then
    printf '  Compositor: %s\n' "${device_info_data['compositor']}"
  fi

  say 'Kernel:'
  printf '  Name: %s\n' "${device_info_data['kernel_name']}"
  printf '  Release: %s\n' "${device_info_data['kernel_release']}"
  printf '  Version: %s\n' "${device_info_data['kernel_version']}"
  printf '  Machine hardware name: %s\n' "${device_info_data['kernel_machine']}"

  say 'Motherboard:'
  printf '  Vendor: %s\n' "${device_info_data['motherboard_vendor']}"
  printf '  Name: %s\n' "${device_info_data['motherboard_name']}"

  say 'GPU:'
  for gpu_info in "${gpus[@]}"; do
    printf '  Device Name: %s\n' "${gpu_info%%,*}"
    printf '  Driver Name: %s\n' "${gpu_info#*,}"
  done
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
