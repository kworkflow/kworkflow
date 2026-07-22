#!/usr/bin/env bash

include './tests/unit/utils.sh'
include './tests/integration/utils.sh'
include './src/get_device_info.sh'
include './src/lib/kw_string.sh'

declare -gA DEVICE_INFO_RESULTS

function oneTimeSetUp()
{
  local distro
  local container
  local kw_device_container_output
  local output

  # The VERBOSE variable is set and exported in the run_tests.sh script based
  # on the command-line options provided by the user. It controls the verbosity
  # of the output during the test runs.
  setup_container_environment "$VERBOSE" 'get_device_info'

  # Retrieves and processes the output of the 'kw get-device-info --local' command from
  # various distribution containers.
  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"

    kw_device_container_output=$(container_exec "$container" 'kw get-device-info --local')
    DEVICE_INFO_RESULTS["$distro"]="$kw_device_container_output"
  done
}

# Test the RAM information reported by 'kw get-device-info --local'
function test_kw_device_local_ram()
{
  local distro
  local container_name
  local actual_ram_kb
  local expected_ram
  local output_ram

  for distro in "${DISTROS[@]}"; do
    container_name="kw-${distro}"

    # The cut part removes a percentage that might change and make this test fails for no good reason.
    expected_ram=$(container_exec "$container_name" "inxi --memory-short" | grep "System RAM" | cut --delimiter 'u' --field 1)
    output_ram=$(printf "%s" "${DEVICE_INFO_RESULTS[$distro]}" | grep "System RAM" | cut --delimiter 'u' --field 1)

    assert_equals_helper "'kw get-device-info' RAM check failed for ${distro}" "$LINENO" "$expected_ram" "$output_ram"
  done
}

# Test the storage information reported by 'kw get-device-info --local'
function test_kw_device_local_storage()
{
  local distro
  local container_name
  local output_root_filesystem
  local output_filesystem_size
  local output_mount_point
  local expected_root_filesystem
  local expected_filesystem_size
  local expected_mount_point

  for distro in "${DISTROS[@]}"; do
    container_name="kw-${distro}"

    expected_root_filesystem=$(container_exec "$container_name" "df --human-readable / | tail --lines 1 | cut --delimiter ' ' --fields 1")
    output_root_filesystem=$(printf "%s" "${DEVICE_INFO_RESULTS[$distro]}" | grep 'Root filesystem:' | cut --delimiter ':' --fields 2 | tr --delete ' ')
    assert_equals_helper "'kw get-device-info' Root filesystem mismatch for ${distro}" "$LINENO" "$expected_root_filesystem" "$output_root_filesystem"

    expected_filesystem_size=$(container_exec "$container_name" "df --human-readable / | grep '/' | tr --squeeze-repeats ' ' | cut --delimiter ' ' --fields 2")
    output_filesystem_size=$(printf "%s" "${DEVICE_INFO_RESULTS[$distro]}" | grep 'Size:' | cut --delimiter ' ' --fields 4)
    assert_equals_helper "'kw get-device-info' Root filesystem size mismatch for ${distro}" "$LINENO" "$expected_filesystem_size" "$output_filesystem_size"

    expected_mount_point=$(container_exec "$container_name" "df --human-readable / | tail --lines 1 | tr --squeeze-repeats ' ' | cut --delimiter ' ' --fields 6")
    output_mount_point=$(printf "%s" "${DEVICE_INFO_RESULTS[$distro]}" | grep 'Mounted on:' | tr --squeeze-repeats ' ' | cut --delimiter ' ' --fields 4)
    assert_equals_helper "'kw get-device-info' Root filesystem mounted on mismatch for ${distro}" "$LINENO" "$expected_mount_point" "$output_mount_point"
  done
}

# Test the operating system information reported by 'kw get-device-info --local'
function test_kw_device_local_os()
{
  local distro
  local container
  local expected_distro
  local output_distro

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"

    expected_distro=$(container_exec "$container" "grep ^NAME= /etc/os-release | cut --delimiter '\"' --fields 2")
    output_distro=$(printf "%s" "${DEVICE_INFO_RESULTS[$distro]}" | grep 'Distribution:' | cut --delimiter ':' --fields 2 | sed 's/^ *//g')
    assert_equals_helper "'kw get-device-info' Distribution name mismatch for ${distro}" "$LINENO" "$expected_distro" "$output_distro"
  done
}

# Test the motherboard information reported by 'kw get-device-info --local'
function test_kw_device_local_motherboard()
{
  local distro
  local container
  local expected_motherboard_vendor
  local expected_motherboard_name
  local output_motherboard_vendor
  local output_motherboard_name
  local raw_inxi_output

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"

    motherboard_section=$(printf "%s" "${DEVICE_INFO_RESULTS[$distro]}" | grep --extended-regexp --after-context=3 'Motherboard:')
    vendor_line=$(get_string_after_delimiter "$motherboard_section" 'Vendor: ')
    name_line=$(get_string_after_delimiter "$motherboard_section" 'Name: ')

    raw_inxi_output=$(container_exec "$container" 'inxi --tty --width 1 --color 0 --machine')
    output_motherboard_vendor=$(get_string_after_delimiter "$raw_inxi_output" 'Mobo: ')
    output_motherboard_name=$(get_string_after_delimiter "$raw_inxi_output" 'model: ')

    assert_equals_helper "'kw get-device-info' Motherboard vendor mismatch for ${distro}" "$LINENO" "$vendor_line" "$output_motherboard_vendor"
    assert_equals_helper "'kw get-device-info' Motherboard name mismatch for ${distro}" "$LINENO" "$name_line" "$output_motherboard_name"
  done
}

# Test the chassis information reported by 'kw get-device-info --local'
function test_kw_device_local_chassis()
{
  local distro
  local container
  local output_chassis
  local expected_chassis='Unknown'
  local chassis_table=('Other' 'Unknown' 'Desktop' 'Low Profile Desktop'
    'Pizza Box' 'Mini Tower' 'Tower' 'Portable' 'Laptop' 'Notebook' 'Hand Held'
    'Docking Station' 'All in One' 'Sub Notebook' 'Space-Saving' 'Lunch Box'
    'Main System Chassis' 'Expansion Chassis' 'SubChassis' 'Bus Expansion Chassis'
    'Peripheral Chassis' 'Storage Chassis' 'Rack Mount Chassis' 'Sealed-Case PC'
    'VM')

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"

    chassis_type=$(container_exec "$container" 'head --lines 1 /sys/devices/virtual/dmi/id/chassis_type')
    if [[ "$chassis_type" -gt 0 && "$chassis_type" -le "${#chassis_table[@]}" ]]; then
      expected_chassis="${chassis_table[chassis_type - 1]}"
    fi

    output_chassis=$(printf "%s" "${DEVICE_INFO_RESULTS[$distro]}" | grep 'Type:' | cut --delimiter ':' --fields 2 | sed 's/^ *//g')
    assert_equals_helper "'kw get-device-info' Chassis type mismatch for ${distro}" "$LINENO" "$expected_chassis" "$output_chassis"
  done
}

# Test the GPU information reported by 'kw get-device-info --local'
function test_kw_device_local_gpu()
{
  local distro
  local container
  local pci_addresses
  local pci_address
  local gpu_info
  local expected_gpu_model
  local expected_gpu_provider
  local output_gpu
  local expected
  local actual_output
  local found=false
  local formatted_output=()
  declare -A expected_gpus

  for distro in "${DISTROS[@]}"; do
    container="kw-${distro}"

    pci_addresses=$(container_exec "$container" "lspci | grep --regexp=VGA --regexp=Display --regexp=3D | cut --delimiter=' ' --fields 1")
    for pci_address in $pci_addresses; do
      gpu_info=$(container_exec "$container" "lspci -v -s ${pci_address}")
      expected_gpu_model=$(printf '%s\n' "${gpu_info}" | sed --quiet --regexp-extended '/Subsystem/s/\s*.*:\s+(.*)/\1/p' | xargs)
      expected_gpu_provider=$(printf '%s\n' "${gpu_info}" | sed --quiet --regexp-extended '/controller/s/.+controller: *([^\[\(]+).+/\1/p' | xargs)
      expected_gpus["$pci_address"]="${expected_gpu_model};${expected_gpu_provider}"
    done

    # Capture all lines starting from 'GPU:' until the next empty line
    output_gpu=$(printf "%s" "${DEVICE_INFO_RESULTS[$distro]}" | sed -n '/^GPU:/,/^$/p')

    # Format output_gpu to compare with expected_gpus
    while read -r line; do
      if [[ "$line" == Model:* ]]; then
        model=${line#Model: }
      elif [[ "$line" == Provider:* ]]; then
        provider=${line#Provider: }
        formatted_output+=("${model};${provider}")
      fi
    done <<< "$output_gpu"

    for pci_address in "${!expected_gpus[@]}"; do
      expected="${expected_gpus[$pci_address]}"
      for actual_output in "${formatted_output[@]}"; do
        if [[ "$expected" == "$actual_output" ]]; then
          found=true
          break
        fi
      done
      if [[ ! "$found" ]]; then
        assert_equals_helper "'kw get-device-info' GPU mismatch for $pci_address" "$LINENO" "$expected" "${formatted_output[*]}"
      fi
    done
  done
}

invoke_shunit
