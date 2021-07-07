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
  local command
  local start
  local end
  local cross_compile
  local arch
  local menu_config
  local parallel_cores
  local doc_type
  local pkg
  local pkg_rule

  parse_build_options "$@"
  if [[ "$?" != 0 ]]; then
    exit 22 # EINVAL
  fi

  cross_compile="${options_values['CROSS_COMPILE']}"
  arch=${options_values['ARCH']}
  menu_config=${options_values['MENU_CONFIG']}
  parallel_cores=${options_values['PARALLEL_CORES']}
  doc_type=${options_values['DOC_TYPE']}
  pkg=${options_values['PKG']}

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
    complain "Execute this command in a kernel tree."
    exit 125 # ECANCELED
  fi

  if [[ -x "$(command -v nproc)" ]]; then
    parallel_cores=$(nproc --all)
  else
    parallel_cores=$(grep -c ^processor /proc/cpuinfo)
  fi

  command="make -j$parallel_cores ARCH=$arch $cross_compile"

  if [[ -n "$pkg" ]]; then
    pkg_rule="$(pkg_get_rule "$pkg")"
    if [[ "$?" == 95 ]]; then
      complain "Package type '$pkg' not supported yet. Consider sending a patch for that!"
      return 95 # ENOTSUP
    fi
    command="$command $pkg_rule"
  fi

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

  pkg_info "$pkg"

  return "$ret"
}

function parse_build_options()
{
  local long_options='help,info,menu,doc,pkg:'
  local short_options='h,i,n,d,p'
  local doc_type

  options="$(getopt \
    --name "kw build" \
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
  options_values['PKG']="${configurations[use_pkg]}"

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
        options_values['MENU_CONFIG']="${configurations[menu_config]:-"nconfig"}"
        shift
        ;;
      --doc | -d)
        options_values['DOC_TYPE']="${configurations[doc_type]:-htmldocs}"
        shift
        ;;
      --pkg | -p)
        options_values['PKG']="$2" # Default value is debian
        shift 2
        ;;
      --)
        shift
        ;;
      *)
        complain "Invalid option: $1"
        return 22 # EINVAL
        shift
        ;;
    esac
  done

  if [[ "${options_values['PKG']}" == 'no' ]]; then
    options_values['PKG']=''
  fi
}

# This function returns the makefile rule for creating a package, according to
# the type of package required
#
# @pkg_type The type of package created
#
# Returns:
# The command necessary to create a package
function pkg_get_rule()
{
  local pkg_type="$1"

  case "$pkg_type" in
    debian)
      echo 'bindeb-pkg'
      return
      ;;
    *)
      return 95 # ENOTSUP
      ;;
  esac
}

# This function prints information about recently created debian packages
#
# @pkg_type The type of package created. If empty, nothing is done.
#
function pkg_info()
{
  local pkg_type="$1"

  case "$pkg_type" in
    debian)
      pkg_info_deb
      return
      ;;
  esac
}

# This function prints information about recently created debian packages
#
function pkg_info_deb()
{
  local revision
  local version
  local release
  local created_packages

  revision="$(($(cat .version) - 1))"
  version="$(get_kernel_version 2> /dev/null)"
  release="$(get_kernel_release 2> /dev/null)"

  created_packages=(../*"${release}-${revision}"*'.deb')

  say 'The following packages have been created:'
  for p in "${created_packages[@]}"; do
    say "  $(basename "$p")"
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
    '  build (-d | --doc) - Build kernel documentation' \
    '  build (-p | --pkg ) - Build kernel as a package'
}
