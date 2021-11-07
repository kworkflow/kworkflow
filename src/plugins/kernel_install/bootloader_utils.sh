# Most of the code available here was heavily inspired in the bootinfonscript
# source, for more details see:
#  - https://github.com/arvidjaar/bootinfoscript
declare -gA device_to_mount_point
declare -ga available_hard_driver_system
declare -g DEV_PATH='/dev'

# This function will populate the device_to_mount_point with device info in the
# key and the mount point in the value
function discover_device_and_partition()
{
  local ignore_matches_regex
  local output
  local device
  local mount_on
  declare -a ignore_from_df=(
    'loop'
    'fuse'
    'udev'
    'tmpfs'
    'Filesystem'
  )

  printf -v ignore_matches_regex "%s|" "${ignore_from_df[@]}" >> /dev/null
  ignore_matches_regex="$ignore_matches_regex"'Monted'
  output=$(df --output='source,target' | grep -Ev "$ignore_matches_regex")

  # Let's populate device_to_partition
  while IFS= read -r line; do
    device=$(echo "$line" | cut -d ' ' -f1)
    mount_on=$(echo "$line" | cut -d ' ' -f2)
    device_to_mount_point["$device"]="$mount_on"
  done <<< "$output"
}

# This function's goal is to identify the type of disk device available in the
# target system. This function uses a regex match in the /dev directory to
# populate the array available_hard_driver_system with the disks entries found
# in the system.
function discover_all_hard_drive()
{
  local all_patterns=''
  local last_char=''
  local output=''
  local index=0
  # This list might be updated in the future
  declare -a hard_driver_patterns=(
    "$DEV_PATH/hd[a-z]"
    "$DEV_PATH/hd[a-z][a-z]"
    "$DEV_PATH/sd[a-z]"
    "$DEV_PATH/sd[a-z][a-z]"
    "$DEV_PATH/mmcblk[0-9][a-z][0-9]"         # mmcblkXzY
    "$DEV_PATH/nvme[0-9][a-z][0-9][a-z][0-9]" # nvmeXYZPQ
  )
  printf -v all_patterns '%s ' "${hard_driver_patterns[@]}"

  # We will try to list some patterns that may not be available, that's
  # why we are redirecting the error to dev/null
  output=$(eval "ls $all_patterns" 2> /dev/null)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    # Check if we had a folder in the list
    printf -v last_char '%s' "${line: -1}"
    [[ "$last_char" == ':' ]] && continue

    available_hard_driver_system["$index"]="$line"
    ((index++))
  done <<< "$output"
}
