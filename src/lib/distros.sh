# Identifying and manipulating distros is a common task, so this file
# centralizes the operations associated with it.

include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/lib/remote.sh"

declare -gA distro_to_package_manager=(
  ['debian']='apt install --yes'
  ['arch']='yes | pacman -Syu'
  ['fedora']='dnf install --assumeyes'
)

# Manages the package installation in the target distro.
#
# @flag How to display a command, the default value is
#   "SILENT". For more options see `src/lib/kwlib.sh` function `cmd_manager`
# @_package_list
# @remote: IP address of the target machine (default from config file)
# @port: Destination for sending the file (default from config file)
# @user: User in the host machine. Default value is "root" (default from config file)
# @target Target can be 2 (LOCAL_TARGET) and 3 (REMOTE_TARGET)
#
# Return:
# - 95: If the distro is not supported.
# - 22: If the package parameter or target is invalid.
function install_package()
{
  local flag="$1"
  local -n _package_list="$2"
  local remote="${3:-${remote_parameters['REMOTE_IP']}}"
  local port="${4:-${remote_parameters['REMOTE_PORT']}}"
  local user="${5:-${remote_parameters['REMOTE_USER']}}"
  local target="$6"
  local sudo_cmd=''
  local compose_cmd
  local flat_package_list

  flat_package_list=${_package_list[*]}
  flat_package_list=$(str_strip ${flat_package_list})

  [[ -z "${flat_package_list[@]}" ]] && return 22 # EINVAL

  case "$target" in
    2) # Local
      distro=$(detect_distro '/')
      sudo_cmd='sudo '
      ;;
    3) # Remote
      distro=$(which_distro "$remote" "$port" "$user" 'SILENT')
      ;;
    *)
      return 22
      ;;
  esac

  if [[ "$distro" =~ 'none' ]]; then
    complain "Unfortunately, there's no support for the target distro"
    return 95 # ENOTSUP
  fi

  compose_command="${distro_to_package_manager[${distro}]} ${flat_package_list}"

  if [[ "$target" -eq 2 ]]; then
    compose_command="${sudo_cmd}${compose_command}"
    cmd_manager "$flag" "$compose_command"
    return "$?"
  fi

  cmd_remotely "$flag" "$compose_command" "$remote" "$port" "$user" '' '' 1
}

# This function checks if the target distro is supported by kw. This function
# is handy for plugins that have some dependency with distros.
#
# Accordingly, with os-release documentation, when we find ID_LIKE, we are in a
# derivative distro. If we don't have it, the distro is the original one and
# will only have ID.
#
# @root_path: Expects the root path wherein we can find the /etc
# @str_check: String with a distro name
# @raw_os_release: os-release file in a string
#
# Returns:
# It returns the family name in lowercase, otherwise return none.
function detect_distro()
{
  local root_path="$1"
  local str_check="$2"
  local raw_os_release="$3"
  local distro_ids='none'
  local etc_path
  local os_release_process
  declare -a os_family=('debian' 'arch' 'fedora')

  etc_path=$(join_path "$root_path" '/etc')

  if [[ -d "$etc_path" && -z "$str_check" && -z "$raw_os_release" ]]; then
    os_release_process=$(< "${etc_path}/os-release")
  elif [[ -n "$raw_os_release" ]]; then
    os_release_process="$raw_os_release"
  fi

  if [[ -n "$os_release_process" ]]; then
    distro_ids=$(printf '%s' "$os_release_process" | grep -w 'ID\(_LIKE\)\?' | tr -d '"' | cut -d = -f 2)
  fi

  if [[ -n "$str_check" ]]; then
    distro_ids="$str_check"
  fi

  for distro_id in $distro_ids; do
    if [[ ${os_family[*]} =~ ${distro_id} ]]; then
      printf '%s\n' "$distro_id"
      return
    fi
  done

  printf '%s\n' 'none'
}

# Access the target device and query the distro name.
#
# @remote Origin of the file to be send
# @port Destination for sending the file
# @user User in the host machine. Default value is "root"
# @flag How to display a command, default is SILENT
#
# Return:
# Return the distro name. The caller should call this function inside of
# subshell and save it to a variable.
function which_distro()
{
  local remote=${1:-${remote_parameters[ssh_ip]}}
  local port=${2:-${remote_parameters[ssh_port]}}
  local user=${3:-${remote_parameters[ssh_user]}}
  local flag=${4:-'SILENT'}
  local output

  cmd='cat /etc/os-release'
  output=$(cmd_remotely "$flag" "$cmd" "$remote" "$port" "$user")
  # TODO: I think we can find a better way to test this...
  if [[ "$flag" =~ 'TEST_MODE' ]]; then
    printf '%s' "$output"
    return
  fi

  detect_distro '' '' "$output"
}
