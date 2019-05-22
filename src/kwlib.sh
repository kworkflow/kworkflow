# NOTE: src/commons.sh must be included before this file

# This function executes any command and provides a mechanism to display the
# command in the terminal. Additionally, there's a test mode which only
# displays the commands, and it is useful for implementing unit tests.
#
# @flag: Expecting a flag, that could be SILENT, COMPLAIN, WARNING, SUCCESS,
#   and TEST_MODE. By default, cmd_manager does not expects flags and always
#   show the command.
# @@: Target command
#
# Returns:
# Return the exit status of the command defined by the string or 0 in the case
# of TEST_MODE
function cmd_manager()
{
  local flag=$1

  case "$flag" in
    SILENT)
      shift 1
      ;;
    COMPLAIN)
      shift 1
      complain "$@"
      ;;
    WARNING)
      shift 1
      warning "$@"
      ;;
    SUCCESS)
      shift 1
      success "$@"
      ;;
    TEST_MODE)
      shift 1
      say "$@"
      return 0
      ;;
    *)
      say "$@"
      ;;
  esac

  eval $@
}

# Checks if a directory is a kernel tree root
#
# @DIR A directory path
#
# Returns:
# True if given dir is a kernel tree root and false otherwise.
function is_kernel_root()
{
  local -r DIR="$@"

  # The following files are some of the files expected to be at a linux
  # tree root and not expected to change. Their presence (or abscense)
  # is used to tell if a directory is a linux tree root or not. (They
  # are the same ones used by get_maintainer.pl)
  if [[ -f "${DIR}/COPYING" &&
        -f "${DIR}/CREDITS" &&
        -f "${DIR}/Kbuild" &&
        -e "${DIR}/MAINTAINERS" &&
        -f "${DIR}/Makefile" &&
        -f "${DIR}/README" &&
        -d "${DIR}/Documentation" &&
        -d "${DIR}/arch" &&
        -d "${DIR}/include" &&
        -d "${DIR}/drivers" &&
        -d "${DIR}/fs" &&
        -d "${DIR}/init" &&
        -d "${DIR}/ipc" &&
        -d "${DIR}/kernel" &&
        -d "${DIR}/lib" &&
        -d "${DIR}/scripts" ]]; then
    return 0
  fi
  return 1
}

# Finds the root of the linux kernel repo containing the given file
#
# @FILE_OR_DIR The argument is a directory of file path
#
# Returns:
# The path of the kernel tree root (string) which the file or dir belongs to, or
# an empty string if no root was found.
function find_kernel_root
{
  local -r FILE_OR_DIR="$@"
  local current_dir
  local kernel_root=""

  if [[ -f "$FILE_OR_DIR" ]]; then
    current_dir="$(dirname $FILE_OR_DIR)"
  else
    current_dir="$FILE_OR_DIR"
  fi

  if is_kernel_root "$current_dir"; then
    kernel_root="$current_dir"
  else
    while [[ "$current_dir" != "." && "$current_dir" != "/" ]]; do
      current_dir="$(dirname $current_dir)"
      if is_kernel_root "$current_dir"; then
        kernel_root="$current_dir"
        break
      fi
    done
  fi

  echo "$kernel_root"
}

# Checks if the given path is a patch file
#
# @FILE_PATH The argument is the path
#
# Returns:
# True if given path is a patch file and false otherwise.
function is_a_patch
{
  local -r FILE_PATH="$@"

  if [[ ! -f "$FILE_PATH" ]]; then
    return 1
  fi

  local file_content=`cat "$FILE_PATH"`

  # The following array stores strings that are expected to be present
  # in a patch file. The absence of any of these strings makes the
  # given file be considered NOT a patch
  local -ar PATCH_EXPECTED_STRINGS=(
    "diff --git"
    "Subject:"
    "Date:"
    "From:"
    "---"
    "@@"
  )

  for expected_str in "${PATCH_EXPECTED_STRINGS[@]}"; do
    if [[ ! "$file_content" =~ "$expected_str" ]]; then
      return 1
    fi
  done

  return 0
}

# This function joins one path components intelligently. The return value is
# the concatenation of path and any members.
#
# @target_path Path to join
# @member Component to join the path
#
# Returns:
# Return the concatenation of path and member
function join_path()
{
  local target_path=$1
  local member=$2

  # TODO: Extended pattern matching. We should consider to use it as a default
  # in this project.
  shopt -s extglob
  member=${member%%+(/)}
  member=${member##+(/)}

  echo "${target_path%%+(/)}/$member"
}

# This function tries to identify the OS distribution. In order to make it work
# as expected, it is required to inform the root path. This function is useful
# for plugins; because of this, we limited here the supported distributions
#
# @root_path Expects the root path wherein we can find the /etc
#
# Returns:
# It returns the distro name in lowercase, otherwise return none.
function detect_distro()
{
  local root_path=$1
  local etc_path=$(join_path $root_path /etc)
  local distro="none"

  if [[ -d $etc_path ]]; then
    distro=$(cat $etc_path/*-release | grep -w ID | cut -d = -f 2)
  fi

  if [[ $distro =~ "arch" ]]; then
    echo "arch"
  elif [[ $distro =~ "debian" ]]; then
    echo "debian"
  else
    echo "none"
  fi
}
