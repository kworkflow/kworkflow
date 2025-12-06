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

