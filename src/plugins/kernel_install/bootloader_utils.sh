# Most of the code available here was heavily inspired in the bootinfonscript
# source, for more details see:
#  - https://github.com/arvidjaar/bootinfoscript
declare -gA device_to_mount_point
declare -ga available_hard_driver_system

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
