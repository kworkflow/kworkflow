include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kw_config_loader.sh"

declare -gA options_values

# This function retrieves and prints information related to the kernel that
# will be compiled.
function build_info()
{
  local flag="$1"
  local kernel_name
  local kernel_version
  local compiled_modules
  local env_path="${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  local config_path='.config'

  kernel_name=$(get_kernel_release "$flag")
  kernel_version=$(get_kernel_version "$flag")

  say 'Kernel source information'
  printf '%s\n' "  Name: $kernel_name" \
    "  Version: $kernel_version"

  [[ -f "${env_path}/.config" ]] && config_path="${env_path}/.config"

  if [[ -f "$config_path" ]]; then
    compiled_modules=$(grep -c '=m' "$config_path")
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
  local platform_ops
  local menu_config
  local doc_type
  local optimizations
  local cpu_scaling_factor
  local parallel_cores
  local warning
  local output_path
  local llvm
  local env_name
  local output_kbuild_flag=''

  parse_build_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    build_help
    exit 22 # EINVAL
  fi

  env_name=$(get_current_env_name)
  if [[ "$?" == 0 ]]; then
    options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']="${KW_CACHE_DIR}/${env_name}"
    output_kbuild_flag=" O=${options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']}"
  fi

  cross_compile="${options_values['CROSS_COMPILE']}"
  menu_config=${options_values['MENU_CONFIG']}
  parallel_cores=${options_values['PARALLEL_CORES']}
  doc_type=${options_values['DOC_TYPE']}
  cpu_scaling_factor=${options_values['CPU_SCALING_FACTOR']}
  warnings=${options_values['WARNINGS']}
  output_path=${options_values['LOG_PATH']}
  llvm=${options_values['USE_LLVM_TOOLCHAIN']}

  if [[ -n "${options_values['INFO']}" ]]; then
    build_info ''
    exit
  fi

  if [[ -n "$warnings" ]]; then
    warnings=" W=$warnings"
  fi

  if [[ -n "$output_path" ]]; then
    output_path=" 2>&1 | tee $output_path"
  fi

  if [[ -n "$llvm" ]]; then
    llvm='LLVM=1 '
  fi

  platform_ops=${options_values['ARCH']}

  if [[ -n "$cross_compile" ]]; then
    platform_ops="${platform_ops} CROSS_COMPILE=${cross_compile}"
  fi

  if [[ -n "$menu_config" ]]; then
    command="make -j ${llvm}ARCH=${platform_ops} ${menu_config}${output_kbuild_flag}"
    cmd_manager "$flag" "$command"
    exit
  fi

  if ! is_kernel_root "$PWD"; then
    complain 'Execute this command in a kernel tree.'
    exit 125 # ECANCELED
  fi

  if command_exists nproc; then
    parallel_cores="$(nproc --all)"
  else
    parallel_cores="$(grep -c ^processor /proc/cpuinfo)"
  fi

  optimizations="-j$((parallel_cores * cpu_scaling_factor / 100))"

  if [[ -n "${options_values['CCACHE']}" ]]; then
    [[ -n "$llvm" ]] && compiler='clang' || compiler='gcc'
    optimizations="CC=\"ccache ${compiler} -fdiagnostics-color\" ${optimizations}"
  fi

  if [[ -n "$doc_type" ]]; then
    command="make ${optimizations} ${doc_type}${output_path}${output_kbuild_flag}"
    cmd_manager "$flag" "$command"
    return
  fi

  command="make ${optimizations} ${llvm}ARCH=${platform_ops}${warnings}${output_path}${output_kbuild_flag}"

  # Let's avoid menu question by default
  cmd_manager "$flag" "make -j ${llvm}ARCH=${platform_ops} --silent olddefconfig${output_kbuild_flag}"

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

# This function loads the kw build configuration files into memory, populating
# the $build_config hashtable. The files are parsed in a specific order,
# allowing higher level setting definitions to overwrite lower level ones.
function load_build_config()
{
  if [[ -v build_config && "$OVERRIDE_BUILD_CONFIG" != 1 ]]; then
    unset OVERRIDE_BUILD_CONFIG
    return
  fi

  local -a config_dirs
  local config_dirs_size

  if [[ -v XDG_CONFIG_DIRS ]]; then
    IFS=: read -ra config_dirs <<< "$XDG_CONFIG_DIRS"
  else
    [[ -d '/etc/xdg' ]] && config_dirs=('/etc/xdg')
  fi

  # Old users may not have split their configs yet
  parse_configuration "$KW_ETC_DIR/$BUILD_CONFIG_FILENAME" build_config

  # XDG_CONFIG_DIRS is a colon-separated list of directories for config
  # files to be searched, in order of preference. Since this function
  # reads config files in a reversed order of preference, we must
  # traverse it from back to top. Example: if
  # XDG_CONFIG_DIRS=/etc/xdg:/home/user/myconfig:/etc/myconfig
  # we will want to parse /etc/myconfig, then /home/user/myconfig, then
  # /etc/xdg.
  config_dirs_size="${#config_dirs[@]}"
  for ((i = config_dirs_size - 1; i >= 0; i--)); do
    parse_configuration "${config_dirs["$i"]}/$KWORKFLOW/$BUILD_CONFIG_FILENAME" build_config
  done

  parse_configuration "${XDG_CONFIG_HOME:-"$HOME/.config"}/$KWORKFLOW/$BUILD_CONFIG_FILENAME" build_config

  if [[ -f "$PWD/$KW_DIR/$BUILD_CONFIG_FILENAME" ]]; then
    parse_configuration "$PWD/$KW_DIR/$BUILD_CONFIG_FILENAME" build_config
  else
    # Old users may not have used kw init yet, so they wouldn't have .kw
    warning "Please use kw init to update your config files"
  fi
}

function parse_build_options()
{
  local long_options='help,info,menu,doc,ccache,cpu-scaling:,warnings::,save-log-to:,llvm'
  local short_options='h,i,n,d,c:,w::,s:'
  local doc_type
  local file_name_size

  kw_parse "$short_options" "$long_options" "$@" > /dev/null

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw build' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  arch_fallback="${build_config[arch]:-x86_64}"
  options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']=''
  options_values['ARCH']="${build_config[arch]:-$arch_fallback}"
  options_values['MENU_CONFIG']=''
  options_values['CROSS_COMPILE']="${build_config[cross_compile]}"
  options_values['CCACHE']="${build_config[ccache]}"
  options_values['CPU_SCALING_FACTOR']="${build_config[cpu_scaling_factor]:-100}"
  options_values['INFO']=''
  options_values['DOC_TYPE']=''
  options_values['WARNINGS']="${build_config[warning_level]}"
  options_values['LOG_PATH']="${build_config[log_path]:-${configurations[log_path]}}"
  options_values['USE_LLVM_TOOLCHAIN']="${build_config[use_llvm]:-${configurations[use_llvm]}}"

  # Check llvm option
  if [[ ${options_values['USE_LLVM_TOOLCHAIN']} =~ 'yes' ]]; then
    options_values['USE_LLVM_TOOLCHAIN']=1
  else
    options_values['USE_LLVM_TOOLCHAIN']=''
  fi

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
        menu_fallback="${configurations[menu_config]:-nconfig}"
        options_values['MENU_CONFIG']="${build_config[menu_config]:-$menu_fallback}"
        shift
        ;;
      --cpu-scaling | -c)
        if [[ ! "$2" =~ [0-9]+ ]]; then
          options_values['ERROR']="$2"
          return 22 # EINVAL
        fi
        if [[ "$2" -gt 100 ]]; then
          complain 'Upscaling CPU performance in compilation tasks may have unintended consequences!'
        fi
        options_values['CPU_SCALING_FACTOR']="$2"
        shift 2
        ;;
      --ccache)
        options_values['CCACHE']=1
        shift
        ;;
      --llvm)
        options_values['USE_LLVM_TOOLCHAIN']=1
        shift
        ;;
      --doc | -d)
        doc_type_fallback="${configurations[doc_type]:-htmldocs}"
        options_values['DOC_TYPE']="${build_config[doc_type]:-$doc_type_fallback}"
        shift
        ;;
      --warnings | -w)
        # Handling optional parameter
        if [[ "$2" =~ [0-9]+ ]]; then
          options_values['WARNINGS']="$2"
          shift 2
        else
          options_values['WARNINGS']="${configurations[warning_level]:-1}"
          shift
        fi
        ;;
      --save-log-to | -s)
        file_name_size=$(str_length "$2")
        if [[ "$file_name_size" -eq 0 ]]; then
          options_values['ERROR']="$2"
          return 22 # EINVAL
        fi

        options_values['LOG_PATH']="$2"
        shift 2
        ;;
      --)
        shift
        ;;
      *)
        options_values['ERROR']="$1"
        return 22 # EINVAL
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
    '  build (-d | --doc) - Build kernel documentation' \
    '  build (-c | --cpu-scaling) <percentage> - Scale CPU usage by factor' \
    '  build (--ccache) - Enable use of ccache' \
    '  build (-w | --warnings) [warning_levels] - Enable warnings' \
    '  build (-s | --save-log-to) <path> - Save compilation log to path' \
    '  build (--llvm) - Enable use of the LLVM toolchain'
}

# Every time build.sh is loaded its proper configuration has to be loaded as well
load_build_config
load_notification_config
