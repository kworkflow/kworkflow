include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kw_config_loader.sh"

# This function retrieves and prints information related to the kernel that
# will be compiled.
# shellcheck disable=2120
function build_info()
{
  local flag
  local kernel_name
  local kernel_version
  local compiled_modules

  flag="$1"
  kernel_name=$(get_kernel_release "$flag")
  kernel_version=$(get_kernel_version "$flag")

  say "Kernel source information"
  echo -e "\tName: $kernel_name"
  echo -e "\tVersion: $kernel_version"

  if [[ -f '.config' ]]; then
    compiled_modules=$(grep -c '=m' .config)
    echo -e "\tTotal modules to be compiled: $compiled_modules"
  fi
}

# This function is responsible for manipulating kernel build operations such as
# compile/cross-compile and menuconfig.
#
# @flag How to display a command, see `src/kwlib.sh` function `cmd_manager`
# @raw_options String with all user options
#
# Return:
# In case of successful return 0, otherwise, return 22 or 125.
function kernel_build()
{
  local flag="$1"
  shift 1
  local raw_options="$*"
  local PARALLEL_CORES=1
  local CROSS_COMPILE=""
  local command=""
  local start
  local end
  local arch="${configurations[arch]}"
  local menu_config="${configurations[menu_config]}"

  if [[ "$1" == -h ]]; then
    build_help
    exit 0
  fi

  menu_config=${menu_config:-"nconfig"}
  arch=${arch:-"x86_64"}

  if ! is_kernel_root "$PWD"; then
    complain "Execute this command in a kernel tree."
    exit 125 # ECANCELED
  fi

  if [[ -n "${configurations[cross_compile]}" ]]; then
    CROSS_COMPILE="CROSS_COMPILE=${configurations[cross_compile]}"
  fi

  IFS=' ' read -r -a options <<< "$raw_options"
  for option in "${options[@]}"; do
    case "$option" in
      --info | -i)
        build_info
        exit
        ;;
      --menu | -n)
        command="make ARCH=$arch $CROSS_COMPILE $menu_config"
        cmd_manager "$flag" "$command"
        exit
        ;;
      --doc | -d)
        doc_type="${configurations[doc_type]}"
        doc_type=${doc_type:='htmldocs'}
        command="make $doc_type"
        cmd_manager "$flag" "$command"
        return
        ;;
      *)
        complain "Invalid option: $option"
        exit 22 # EINVAL
        ;;
    esac
  done

  if [ -f "$(join_path "$PWD" '.config')" ]; then
    local mkflag=${flag:-'SILENT'}
    cmd_manager "$mkflag" 'make olddefconfig &> /dev/null'
  fi

  if [ -x "$(command -v nproc)" ]; then
    PARALLEL_CORES=$(nproc --all)
  else
    PARALLEL_CORES=$(grep -c ^processor /proc/cpuinfo)
  fi

  command="make -j$PARALLEL_CORES ARCH=$arch $CROSS_COMPILE"

  start=$(date +%s)
  cmd_manager "$flag" "$command"
  ret="$?"
  end=$(date +%s)

  runtime=$((end - start))

  if [[ "$ret" != 0 ]]; then
    statistics_manager "build_failure" "$runtime"
  else
    statistics_manager "build" "$runtime"
  fi

  return "$ret"
}

function build_help()
{
  echo -e "kw build:\n" \
    "  build - Build kernel \n" \
    "  build [--menu|-n] - Open kernel menu config\n" \
    "  build [--info|-i] - Display build information\n" \
    "  build [--doc|-d]  - Build kernel documentation"
}
