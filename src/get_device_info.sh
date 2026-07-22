# This file deals with functions related to hardware information

include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/lib/remote.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/distros.sh"
include "${KW_LIB_DIR}/utils.sh"

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
declare -gA crtcs
declare -ga monitors

declare -gA options_values

declare -g RAW_JSON

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

  handle_inxi_dependence "$flag" "${options_values['TARGET']}"

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

# Check if inxi is installed, if not, install it.
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# Return 0 if inxi is available. If it is not available, setup the target
# machine and install inxi in the process. If the target is unknown, return 22.
function handle_inxi_dependence()
{
  local flag="$1"
  local target="$2"
  local ret

  case "$target" in
    2) # LOCAL_TARGET
      command_exists 'inxi'
      ret="$?"
      ;;
    3) # REMOTE_TARGET
      command_exists_in_remote "$flag" 'inxi' "${remote_parameters['REMOTE_IP']}" \
        "${remote_parameters['REMOTE_PORT']}" "${remote_parameters['REMOTE_USER']}"
      ret="$?"
      ;;
    *)
      return 22
      ;;
  esac

  [[ "$ret" -eq 0 ]] && return 0

  target_machine_setup "${options_values['TARGET']}" "$flag"
}

# Collect all hardware information from the target machine in a single inxi
# invocation using JSON output, and store the result in the global RAW_JSON
# variable. This avoids the overhead of one SSH connection per data category
# when querying a remote target.
#
# If inxi >= 3.3.34 is not available on the target, this function is not called
# and RAW_JSON remains empty; each data-gathering function then falls back to
# its own per-command inxi text-parsing path.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
#
# Return:
# In TEST_MODE, prints the raw JSON string to stdout. Otherwise, populates the
# global RAW_JSON variable and returns 0.
function get_all_info_json()
{
  local flag="$1"
  local target="$2"
  local cmd

  cmd='inxi --tty --memory-short --graphics --expanded -xx --filter --output json --output-file=print'

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      RAW_JSON=$(cmd_manager 'SILENT' "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      RAW_JSON=$(cmd_remotely 'SILENT' "$cmd")
      ;;
  esac

  if [[ "$flag" == 'TEST_MODE' ]]; then
    printf '%s\n' "$RAW_JSON"
    return 0
  fi
}

# This function builds and returns a jq command string that extracts a specific
# value from the inxi JSON output stored in RAW_JSON.
#
# The generated command traverses the inxi JSON output in five steps:
#   1. '.. | objects': recursively descend into every object in the JSON tree
#   2. 'with_entries(select(.key | endswith("$section")))': keep only the
#      entries whose key ends with the requested section name (e.g. "Memory").
#   3. 'values[] | select(type == "array")[]': unwrap the section value, which
#      is an array of objects, and iterate over each element.
#   4. 'to_entries[] | select(.key | endswith("$value"))': convert each object
#      to key/value pairs and keep only the entry whose key ends with the
#      requested field name (e.g. "total").
#   5. '.value': emit the matched value.
#
# @section The top-level inxi section to search in (e.g. 'Memory', 'CPU')
# @value   The key name whose value should be extracted (e.g. 'total', 'model')
#
# Return:
# The generated jq command string is printed to stdout. The caller is
# responsible for appending the JSON input (e.g. via <<< or a file argument)
# and evaluating the result.
function get_jq_cmd()
{
  local section="$1"
  local value="$2"
  local jq_cmd

  jq_cmd="jq --raw-output '.. | objects | with_entries(select(.key | "
  jq_cmd+="endswith(\"$section\"))) |"
  jq_cmd+="values[] | select(type == \"array\")[] | to_entries[] | "
  jq_cmd+="select(.key | endswith(\"$value\")) | "
  jq_cmd+=".value'"

  printf '%s' "${jq_cmd}"
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
  local ram_total
  local ram_available
  local ram_type
  local ram_capacity
  local ram_installed

  flag=${flag:-'SILENT'}

  # TODO: This manual data request can be removed once inxi >= 3.3.34 becomes
  # more widely available.
  if [[ -z "$RAW_JSON" ]]; then
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

    if [[ "$flag" == 'TEST_MODE' ]]; then
      printf '%s\n' "$ram"
      return 0
    fi

    ram_total="$(get_string_after_delimiter "$ram" 'total: ')"
    ram_available="$(get_string_after_delimiter "$ram" 'available: ')"
    ram_type="$(get_string_after_delimiter "$ram" 'type: ')"
    ram_capacity="$(get_string_after_delimiter "$ram" 'capacity: ')"
    ram_installed="$(get_string_after_delimiter "$ram" 'installed: ')"
  else
    cmd=$(get_jq_cmd 'Memory' 'total')
    cmd="${cmd} <<< '${RAW_JSON}'"
    ram_total=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'Memory' 'available')
    cmd="${cmd} <<< '${RAW_JSON}'"
    ram_available=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'Memory' 'capacity')
    cmd="${cmd} <<< '${RAW_JSON}'"
    ram_capacity=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'Memory' 'type')
    cmd="${cmd} <<< '${RAW_JSON}'"
    ram_type=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'Memory' 'installed')
    cmd="${cmd} <<< '${RAW_JSON}'"
    ram_installed=$(cmd_manager 'SILENT' "$cmd")
  fi

  device_info_data['ram_total']="$ram_total"
  device_info_data['ram_available']="$ram_available"
  device_info_data['ram_type']="$ram_type"
  device_info_data['ram_capacity']="$ram_capacity"
  device_info_data['ram_installed']="$ram_installed"
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


  if [[ -z "$RAW_JSON" ]]; then
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
  else
    cmd=$(get_jq_cmd 'CPU' 'model')
    cmd="${cmd} <<< '${RAW_JSON}'"
    cpu_vendor_name=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'CPU' 'avg')
    cmd="${cmd} <<< '${RAW_JSON}'"
    cpu_speed=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'CPU' 'Info')
    cmd="${cmd} <<< '${RAW_JSON}'"
    cpu_total_cores=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'System' 'arch')
    cmd="${cmd} <<< '${RAW_JSON}'"
    cpu_architecture=$(cmd_manager 'SILENT' "$cmd")
  fi
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

  # TODO: This manual data request can be removed once inxi >= 3.3.34 becomes
  # more widely available.
  if [[ -z "$RAW_JSON" ]]; then
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
  else
    cmd=$(get_jq_cmd 'Drives' 'total')
    cmd="${cmd} <<< '${RAW_JSON}'"
    size=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'Drives' 'used')
    cmd="${cmd} <<< '${RAW_JSON}'"
    used_size=$(cmd_manager 'SILENT' "$cmd")
    # TODO: When using inxi we need some extra processing here. Check this later.
  fi

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

  # TODO: This manual data request can be removed once inxi >= 3.3.34 becomes
  # more widely available.
  if [[ -z "$RAW_JSON" ]]; then
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
  else
    cmd=$(get_jq_cmd 'System' 'Distro')
    cmd="${cmd} <<< '${RAW_JSON}'"
    os_name=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'Graphics' 'compositor')
    cmd="${cmd} <<< '${RAW_JSON}'"
    desktop=$(cmd_manager 'SILENT' "$cmd")
  fi

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

  # TODO: This manual data request can be removed once inxi >= 3.3.34 becomes
  # more widely available.
  if [[ -z "$RAW_JSON" ]]; then
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
  else
    cmd=$(get_jq_cmd 'Graphics' 'compositor')
    cmd="${cmd} <<< '${RAW_JSON}'"
    desktop_env=$(cmd_manager 'SILENT' "$cmd")
  fi

  case "$desktop_env" in
    gnome-shell | mutter)
      formatted_de='gnome'
      ;;
    lxsession)
      formatted_de='lxde'
      ;;
    openbox)
      formatted_de='openbox'
      ;;
    xfwm4)
      formatted_de='xfce'
      ;;
    kde | kwin_wayland | kwin_x11)
      formatted_de='kde'
      ;;
    mate)
      formatted_de='mate'
      ;;
    cinnamon | muffin)
      formatted_de='cinnamon'
      ;;
    gamescope)
      formatted_de='gamescope'
      ;;
    marco)
      formatted_de='Mate'
      ;;
    sway)
      formatted_de='sway'
      ;;
  esac

  # TODO: This should be changed to desktop_environment, and we should add the
  # compositor information as an extra info

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

  # TODO: This manual data request can be removed once inxi >= 3.3.34 becomes
  # more widely available.
  if [[ -z "$RAW_JSON" ]]; then
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
  else
    cmd=$(get_jq_cmd 'System' 'Kernel')
    cmd="${cmd} <<< '${RAW_JSON}'"
    kernel_release=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'System' 'arch')
    cmd="${cmd} <<< '${RAW_JSON}'"
    kernel_machine=$(cmd_manager 'SILENT' "$cmd")
  fi

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
  local cmd
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

  # TODO: This manual data request can be removed once inxi >= 3.3.34 becomes
  # more widely available.
  if [[ -z "$RAW_JSON" ]]; then
    cmd='inxi --tty --width 1 --color 0 --graphics'

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
  else
    cmd=$(get_jq_cmd 'Graphics' 'Device')
    cmd="${cmd} <<< '${RAW_JSON}'"
    raw_devices=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'Graphics' 'driver')
    cmd="${cmd} <<< '${RAW_JSON}'"
    raw_drivers=$(cmd_manager 'SILENT' "$cmd")

    while IFS= read -r line; do
      [[ -n "$line" ]] && _device_names+=("$line")
    done <<< "$raw_devices"

    while IFS= read -r line; do
      [[ -n "$line" ]] && _driver_names+=("$line")
    done <<< "$raw_drivers"

    cmd=$(get_jq_cmd 'Graphics' 'Display')
    cmd="${cmd} <<< '${RAW_JSON}'"
    window_system=$(cmd_manager 'SILENT' "$cmd")
  fi

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

  # TODO: This manual data request can be removed once inxi >= 3.3.34 becomes
  # more widely available.
  if [[ -z "$RAW_JSON" ]]; then
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
  else
    cmd=$(get_jq_cmd 'Machine' 'Mobo')
    cmd="${cmd} <<< '${RAW_JSON}'"
    motherboard_vendor=$(cmd_manager 'SILENT' "$cmd")

    cmd=$(get_jq_cmd 'Machine' 'model')
    cmd="${cmd} <<< '${RAW_JSON}'"
    motherboard_model=$(cmd_manager 'SILENT' "$cmd")
  fi

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
  local chassis

  flag=${flag:-'SILENT'}
  [[ "$flag" == 'TEST_MODE' ]] && test_flag='TEST_MODE'

  # TODO: This manual data request can be removed once inxi >= 3.3.34 becomes
  # more widely available.
  if [[ -z "$RAW_JSON" ]]; then

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

    chassis=$(get_string_after_delimiter "$inxi_machine_output" 'Type: ')
  else
    cmd=$(get_jq_cmd 'Machine' 'Type')
    cmd="${cmd} <<< '${RAW_JSON}'"
    chassis=$(cmd_manager 'SILENT' "$cmd")
  fi

  device_info_data['chassis']="$chassis"
}

function get_monitors()
{
  local target="$1"
  local flag="$2"
  local cmd='inxi --tty --width 1 --color 0 --edid'
  local raw_monitor_data
  local test_flag='SILENT'
  local monitor_index=0
  local total_of_monitors=0
  local monitors_data
  local monitor_string
  local monitor_model
  local monitor_serial
  local monitor_res
  local connector_type

  flag=${flag:-'SILENT'}
  [[ "$flag" == 'TEST_MODE' ]] && test_flag='TEST_MODE'

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      raw_monitor_data=$(cmd_manager "$test_flag" "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      raw_monitor_data=$(cmd_remotely "$test_flag" "$cmd")
      ;;
  esac

  monitors_data=$(printf '%s' "$raw_monitor_data" | sed -n '/Monitor.*/,$p')

  # Parse monitors
  while IFS= read -r line; do
    if [[ "$line" =~ \s*model.* ]]; then
      monitor_model=$(get_string_after_delimiter "$line" 'model: ')
      monitor_model="Model: ${monitor_model}"
      continue
    fi

    if [[ "$line" =~ \s*serial:.* ]]; then
      monitor_serial=$(get_string_after_delimiter "$line" 'serial: ')
      monitor_serial="Serial: ${monitor_serial}"
      continue
    fi

    if [[ "$line" =~ \s*res:.* ]]; then
      monitor_res=$(get_string_after_delimiter "$line" 'res: ')
      monitor_res="Preferred Resolution: ${monitor_res}"
      continue
    fi

    if [[ "$line" =~ \s*Monitor-.* ]]; then
      if [[ "$total_of_monitors" -ge 1 ]]; then
        monitor_string="${connector_type},${monitor_model},${monitor_serial},${monitor_res}"
        monitors["$monitor_index"]=${monitor_string}
        ((monitor_index++))
      fi

      connector_type=$(get_string_after_delimiter "$line" ': ')
      connector_type="Connector type: ${connector_type}"
      ((total_of_monitors++))
      continue
    fi
  done <<< "$monitors_data"

  monitor_string="${connector_type},${monitor_model},${monitor_serial},${monitor_res}"
  monitors["$monitor_index"]="${monitor_string}"
}

function parse_dri_state()
{
  local dri_state_file="$1"
  local collect_start=0
  local current_crtc
  local size
  local type
  local width
  local color_encoding
  local crtc_id
  local capture_refresh_rate=0
  local refresh_rate
  local capture_connector=0
  local connector_type
  local crtc_active_re='[[:space:]]*crtc=[^(]'

  while IFS=$'\n' read -r line; do
    # Capture the active crtc
    if [[ "$line" =~ $crtc_active_re ]]; then
      collect_start=1
      current_crtc=$(get_string_after_delimiter "$line" '=')
      if [[ "$capture_connector" -eq 1 ]]; then
        crtcs["$current_crtc"]+="connector=${connector_type};"
      fi
      continue
    fi

    if [[ "$line" =~ \s*crtc=\(null\) ]]; then
      collect_start=0
      capture_connector=0
      connector_type=''
      continue
    fi

    # Collect refresh rate
    if [[ "$line" =~ crtc\[.*\]: ]]; then
      crtc_id=$(get_string_after_delimiter "$line" ': ')

      for crtc_key in "${!crtcs[@]}"; do
        if [[ "$crtc_key" == "$crtc_id" ]]; then
          current_crtc="$crtc_id"
          capture_refresh_rate=1
          continue
        fi
      done
    fi

    if [[ "$line" =~ mode: && "$capture_refresh_rate" -eq 1 ]]; then
      refresh_rate=$(printf '%s' "$line" | cut --delimiter ':' --fields=2- | cut --delimiter ' ' --fields=3)
      crtcs["$current_crtc"]+="refresh_rate=${refresh_rate};"
      capture_refresh_rate=0
      current_crtc=''
    fi

    # Capture the connector type
    if [[ "$line" =~ connector\[.*\]: ]]; then
      connector_type=$(get_string_after_delimiter "$line" ':')
      connector_type=$(str_drop_all_spaces "$connector_type")
      capture_connector=1
    fi

    # Get resolution
    if [[ "$line" =~ \s*size=.*x.* && "$collect_start" -eq 1 ]]; then
      size=$(get_string_after_delimiter "$line" '=')
      width=$(get_string_after_delimiter "$size" 'x')

      # Check if it is a cursor
      type='primary'
      if [[ "$width" -le '400' ]]; then
        type='cursor'
        continue
      fi
      crtcs["$current_crtc"]+="type=${type};resolution=${size};"
    fi

    if [[ "$line" =~ \s*color-encoding=.* && "$collect_start" -eq 1 && "$type" == 'primary' ]]; then
      color_encoding=$(get_string_after_delimiter "$line" '=')
      crtcs["$current_crtc"]+="color_encoding=${color_encoding};"
    fi
  done <<< "$dri_state_file"
}

function get_modesetting()
{
  local target="$1"
  local flag="$2"
  local cmd_get_kms_state
  local kms_state_raw
  local modesetting_list
  local test_flag='SILENT'

  flag=${flag:-'SILENT'}
  [[ "$flag" == 'TEST_MODE' ]] && test_flag='TEST_MODE'

  # The below command iterates over the kms devices and print the states
  cmd_get_kms_state='for i in {0..10}; do '
  cmd_get_kms_state+='[[ ! -f "/sys/kernel/debug/dri/${i}/state" ]] && continue; '
  cmd_get_kms_state+='c=$(< "/sys/kernel/debug/dri/${i}/state") && [[ -n "$c" ]] && printf "%s" "$c"; done'

  case "$target" in
    2) # LOCAL_TARGET
      cmd_get_kms_state="sudo bash -c '${cmd_get_kms_state}'"
      show_verbose "$flag" "$cmd_get_kms_state"
      kms_state_raw=$(cmd_manager "$test_flag" "$cmd_get_kms_state")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd_get_kms_state"
      kms_state_raw=$(cmd_remotely "$test_flag" "$cmd_get_kms_state" '' '' '' '1')
      ;;
  esac

  parse_dri_state "$kms_state_raw"
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

# This function checks whether the inxi version on the target machine meets the
# minimum required version (3.3.34) for JSON output support.
#
# TODO: this function is temporary and should be removed once inxi >= 3.3.34
# becomes widely available across common distributions.
#
# @flag   How to display a command, the default value is
#   "SILENT". For more options, see `src/lib/kwlib.sh` function `cmd_manager`
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
#
# Return:
# Returns 0 if the installed version is >= 3.3.34, 1 otherwise.
function check_inxi_version()
{
  local flag="$1"
  local target="$2"
  local inxi_version
  local minimum_version='3.3.34'
  local version_for_cmp
  local cmd="inxi --version | head -1 | cut --delimiter ' ' --fields=2"

  case "$target" in
    2) # LOCAL_TARGET
      show_verbose "$flag" "$cmd"
      inxi_version=$(cmd_manager 'SILENT' "$cmd")
      ;;
    3) # REMOTE_TARGET
      show_verbose "$flag" "$cmd"
      inxi_version=$(cmd_remotely 'SILENT' "$cmd")
      ;;
  esac

  version_for_cmp=$(printf '%s\n%s' "$minimum_version" "$inxi_version" | sort --version-sort | head -1)
  [[ "$version_for_cmp" == "$minimum_version" ]] && return 0
  return 1
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

  # TODO: At some point we can drop the version check and fully rely on inxi
  check_inxi_version "$flag" "$target"
  if [[ "$?" -eq 0 ]]; then
    get_all_info_json "$flag" "$target"
  fi

  get_ram "$flag"
  get_cpu "$target" "$flag"
  get_os "$target" "$flag"
  get_kernel_info "$target" "$flag"
  get_graphics "$target" "$flag"
  get_motherboard "$target" "$flag"
  get_chassis "$target" "$flag"
  get_desktop_environment "$target" "$flag"
  get_monitors "$target" "$flag"
  get_modesetting "$target" "$flag"
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
  local monitor
  local -a info_array
  local modesetting
  local -a crtc_key_values
  local key
  local value

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

  say 'Display:'
  monitor=1
  for display_info in "${monitors[@]}"; do
    printf '  Monitor: %s\n' "$monitor"
    convert_string_to_array_based_on_delimiter "$display_info" info_array ','
    for info in "${info_array[@]}"; do
      [[ -z "$info" ]] && continue
      printf '   %s\n' "${info}"
    done
    ((monitor++))
  done

  say 'Modesetting:'
  for crtc_id in "${!crtcs[@]}"; do

    IFS=';' read -r -a crtc_key_values <<< "${crtcs[${crtc_id}]}"
    modesetting=''
    for key_value in "${crtc_key_values[@]}"; do
      key=$(printf '%s' "$key_value" | cut --delimiter '=' --fields=1)
      value=$(get_string_after_delimiter "$key_value" '=')

      # Let's ignore those infos for now
      [[ "$key" == 'type' || "$key" == 'connector' || "$key" == 'color_encoding' ]] && continue

      [[ "$key" == 'resolution' ]] && modesetting="$value" && continue

      if [[ "$key" == 'refresh_rate' ]]; then
        modesetting+="@${value}"
        continue
      fi

      printf '   %s\n' "$value"
    done
    [[ -n "$modesetting" ]] && printf '   %s\n' "$modesetting"
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
