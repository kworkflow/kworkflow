include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kw_config_loader.sh"

declare -gA options_values

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

  say 'Kernel source information'
  printf '%s\n' "  Name: $kernel_name" \
    "  Version: $kernel_version"

  if [[ -f '.config' ]]; then
    compiled_modules=$(grep -c '=m' .config)
    printf '%s\n' "  Total modules to be compiled: $compiled_modules"
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
  local command
  local start
  local end
  local cross_compile
  local arch
  local menu_config
  local parallel_cores
  local doc_type

  parse_build_options "$@"
  if [[ "$?" != 0 ]]; then
    exit 22 # EINVAL
  fi

  cross_compile="${options_values['CROSS_COMPILE']}"
  arch=${options_values['ARCH']}
  menu_config=${options_values['MENU_CONFIG']}
  parallel_cores=${options_values['PARALLEL_CORES']}
  doc_type=${options_values['DOC_TYPE']}

  if [[ -n "${options_values['INFO']}" ]]; then
    build_info
    exit
  fi

  if [[ -n "$cross_compile" ]]; then
    cross_compile="CROSS_COMPILE=$cross_compile"
  fi

  if [[ -n "$menu_config" ]]; then
    command="make ARCH=$arch $cross_compile $menu_config"
    cmd_manager "$flag" "$command"
    return
  fi

  if [[ -n "$doc_type" ]]; then
    command="make $doc_type"
    cmd_manager "$flag" "$command"
    return
  fi

  if ! is_kernel_root "$PWD"; then
    complain 'Execute this command in a kernel tree.'
    exit 125 # ECANCELED
  fi

  if [ -x "$(command -v nproc)" ]; then
    parallel_cores=$(nproc --all)
  else
    parallel_cores=$(grep -c ^processor /proc/cpuinfo)
  fi

  # Let's avoid menu question by default
  cmd_manager "$flag" "make ARCH=$arch $cross_compile olddefconfig --silent"

  command="make -j$parallel_cores ARCH=$arch $cross_compile"

  start=$(date +%s)
  cmd_manager "$flag" "$command"
  ret="$?"
  end=$(date +%s)

  runtime=$((end - start))

  if [[ "$ret" != 0 ]]; then
    statistics_manager 'build_failure' "$runtime"
  else
    statistics_manager 'build' "$runtime"
  fi

  return "$ret"
}

function parse_build_options()
{
  local long_options='help,info,menu,doc'
  local short_options='h,i,n,d'
  local doc_type

  options="$(getopt \
    --name 'kw build' \
    --options "$short_options" \
    --longoptions "$long_options" \
    -- "$@")"

  if [[ "$?" != 0 ]]; then
    return 22 # EINVAL
  fi

  # Default values
  options_values['ARCH']="${configurations[arch]:-'x86_64'}"
  options_values['MENU_CONFIG']=''
  options_values['CROSS_COMPILE']="${configurations[cross_compile]}"
  options_values['PARALLEL_CORES']=1
  options_values['INFO']=''
  options_values['DOC_TYPE']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help | -h)
        build_help "$1"
        exit
        ;;
      --info | -i)
        options_values['INFO']=1
        shift
        ;;
      --menu | -n)
        options_values['MENU_CONFIG']="${configurations[menu_config]:-nconfig}"
        shift
        ;;
      --doc | -d)
        options_values['DOC_TYPE']="${configurations[doc_type]:-htmldocs}"
        shift
        ;;
      --)
        shift
        ;;
      *)
        complain "Invalid option: $option"
        exit 22 # EINVAL
        ;;
    esac
  done

}

function build_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'build'
    return
  fi
  printf '%s\n' 'kw build:' \
    '  build - Build kernel' \
    '  build (-n | --menu) - Open kernel menu config' \
    '  build (-i | --info) - Display build information' \
    '  build (-d | --doc) - Build kernel documentation'
}
