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
  ['kernel_name']=''                     # Kernel name
  ['kernel_release']=''                  # Kernel release
  ['kernel_version']=''                  # Kernel version
  ['kernel_machine']=''                  # Kernel machine type
  ['disk_size']=''                       # Disk size in KB
  ['root_path']=''                       # Root directory path
  ['fs_mount']=''                        # Path where root is mounted
  ['os_name']=''                         # Distro's name
  ['os_version']=''                      # Distro's versios
  ['os_id_like']=''                      # Distro which this distro is based on
  ['motherboard_name']=''                # Motherboard name
  ['motherboard_vendor']=''              # Motherboard vendor
  ['chassis']=''                         # Chassis type
  ['img_size']=''                        # Size of VM image in KB
  ['img_type']='')                       # Type of VM image

declare -gA gpus

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
  local info
  local size
  local mount
  local cmd
  local fs

  cmd="df -h / | tail --lines=1 | tr --squeeze-repeats ' '"
  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      info=$(cmd_manager 'SILENT' "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      info=$(cmd_remotely 'SILENT' "$cmd")
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
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
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
      raw_os_release=$(cmd_remotely 'SILENT' "$cmd")
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
  local ux_regx="'gnome-shell$|kde|mate|cinnamon|lxsession|openbox$'"

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
  esac

  device_info_data['desktop_environment']="$formatted_de"
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
      pci_addresses=$(cmd_remotely 'SILENT' "$cmd_pci_address")
      for g in $pci_addresses; do
        cmd="lspci -v -s ${g}"
        show_verbose "$flag" "$cmd"
        gpu_info=$(cmd_remotely 'SILENT' "$cmd")

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
  get_gpu "$target" "$flag"
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
  printf '  Release: %s\n' "${device_info_data['kernel_release']}"
  printf '  Version: %s\n' "${device_info_data['kernel_version']}"
  printf '  Machine hardware name: %s\n' "${device_info_data['kernel_machine']}"

  say 'Motherboard:'
  printf '  Vendor: %s\n' "${device_info_data['motherboard_vendor']}"
  printf '  Name: %s\n' "${device_info_data['motherboard_name']}"

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
