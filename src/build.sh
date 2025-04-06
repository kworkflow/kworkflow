include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kw_config_loader.sh"

declare -gA options_values

# This function is responsible for manipulating kernel build operations such as
# compile/cross-compile and menuconfig.
#
# @flag How to display a command, see `src/lib/kwlib.sh` function `cmd_manager`
# @raw_options String with all user options
#
# Return:
# In case of successful return 0, otherwise, return 22 or 125.
function build_kernel_main() {
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
  local warnings
  local output_path
  local llvm
  local env_name
  local clean
  local output_kbuild_flag=''
  local cflags
  local from_sha_arg
  local sha_base
  local merge_base

  parse_build_options "$@"

  if [[ "$?" -gt 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    build_help
    exit 22 # EINVAL
  fi

  env_name=$(get_current_env_name)
  if [[ "$?" == 0 ]]; then
    options_values['ENV_PATH_KBUILD_OUTPUT_FLAG']="${KW_CACHE_DIR}/${ENV_DIR}/${env_name}"
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
  clean=${options_values['CLEAN']}
  full_cleanup=${options_values['FULL_CLEANUP']}
  cflags=${options_values['CFLAGS']}
  from_sha_arg=${options_values['FROM_SHA_ARG']}

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'
  flag=${flag:-'SILENT'}

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

  if [[ -n "$clean" ]]; then
    build_clean "$flag" "$output_kbuild_flag"
    return "$?"
  fi

  if [[ -n "$full_cleanup" ]]; then
    full_cleanup "$flag" "$output_kbuild_flag"
    return "$?"
  fi

  platform_ops=${options_values['ARCH']}

  if [[ -n "$cross_compile" ]]; then
    platform_ops="${platform_ops} CROSS_COMPILE=${cross_compile}"
  fi

  if [[ -n "$menu_config" ]]; then
    build_menu_config "$flag" "$output_kbuild_flag" "$menu_config" "$platform_ops" "$llvm"
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
    build_doc "$flag" "$output_kbuild_flag" "$optimizations" "$doc_type" "$output_path"
    return "$?"
  fi

  if [[ -n "$from_sha_arg" ]]; then
    # Check if there is a rebase in process.
    if [[ -d .git/rebase-merge ]]; then
      warning 'ERROR: Abort the repository rebase before continuing with build from sha (use "git rebase --abort")!'
      return 125 # ECANCELED
    elif [[ -f .git/MERGE_HEAD ]]; then
      warning 'ERROR: Abort the repository merge before continuing with build from sha (use "git rebase --abort")!'
      return 125 # ECANCELED
    elif [[ -f .git/BISECT_LOG ]]; then
      warning 'ERROR: Stop the repository bisect before continuing with build from sha (use "git bisect reset")!'
      return 125 # ECANCELED
    elif [[ -d .git/rebase-apply ]]; then
      printf 'ERROR: Abort the repository patch apply before continuing with build from sha (use "git am --abort")!'
      return 125 # ECANCELED
    fi

    # Check if given SHA represents real commit
    cmd_manager 'SILENT' "git cat-file -e ${from_sha_arg}^{commit} 2> /dev/null"
    if [[ "$?" != 0 ]]; then
      complain "ERROR: The given SHA (${from_sha_arg}) does not represent a valid commit sha."
      return 22 # EINVAL
    fi

    # Check if given SHA is in working tree.
    sha_base=$(git rev-parse --verify "$from_sha_arg")
    merge_base=$(git merge-base "$from_sha_arg" HEAD)
    if [[ "$sha_base" != "$merge_base" ]]; then
      complain "ERROR: Given SHA (${from_sha_arg}) is invalid. Check if it is an ancestor of the branch head."
      return 22 # EINVAL
    fi

    build_from_sha "$flag" "$from_sha_arg"
    return "$?"
  fi

  command="make ${optimizations} ${llvm}ARCH=${platform_ops}${warnings}"

  if [[ -n "$cflags" ]]; then
    command+=" KCFLAGS=\"${cflags}\""
  fi
  command+="${output_kbuild_flag}${output_path}"

  # Let's avoid menu question by default
  cmd_manager "$flag" "make -j ${llvm}ARCH=${platform_ops} --silent olddefconfig${output_kbuild_flag}"

  start=$(date +%s)
  cmd_manager "$flag" "$command"
  ret="$?"
  end=$(date +%s)

  runtime=$((end - start))

  if [[ "$ret" != 0 ]]; then
    statistics_manager 'build' "$start" "$runtime" 'failure' "$flag"
  else
    statistics_manager 'build' "$start" "$runtime" '' "$flag"
  fi

  return "$ret"
}

# This function retrieves and prints information related to the kernel that
# will be compiled.
function build_info() {
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

# This function runs the make command under the hood, which in this
# context is used to build and configure the linux kernel using the
# "menuconfig" interface.
function build_menu_config() {
  local flag="$1"
  local env_path="$2"
  local menu_config="$3"
  local platform_ops="$4"
  local llvm="$5"
  local cmd

  flag=${flag:-'SILENT'}

  cmd="make -j ${llvm}ARCH=${platform_ops} ${menu_config}${env_path}"
  cmd_manager "$flag" "$cmd"
}

# This function builds kernel-doc, by default it will create htmldocs.
function build_doc() {
  local flag="$1"
  local env_path="$2"
  local optimizations="$3"
  local doc_type="$4"
  local output_path="$5"
  local cmd

  flag=${flag:-'SILENT'}

  cmd="make ${optimizations} ${doc_type}${output_path}${env_path}"
  cmd_manager "$flag" "$cmd"
}

# This function runs the 'make clean' command under the hood, with
# the advantage of checking if the user is using an env or not.
# In other words, it integrates env with the clean option.
#
# @flag: Expecting a flag, by default, cmd_manager does not
# expects flags and always show the command. For more details
# see the function `cmd_manager` in `src/lib/kwlib.sh`.
#
# @output_kbuild_flag: Will point to the current env path that
# the user is using.
function build_clean() {
  local flag="$1"
  local env_path="$2"
  local cmd

  flag=${flag:-'SILENT'}

  cmd="make clean${env_path}"
  cmd_manager "$flag" "$cmd"
}

# This function runs the 'make distclean' command under the hood, with
# the advantage of checking if the user is using an env or not.
# In other words, it integrates env with the full-cleanup option.
function full_cleanup() {
  local flag="$1"
  local env_path="$2"
  local cmd

  flag=${flag:-'SILENT'}

  cmd="make distclean${env_path}"
  cmd_manager "$flag" "$cmd"
}

# This functions uses iteractive 'git rebase' with '--exec' flag under the hood
# to apply a 'kw build' over each commit from SHA to branch head.
#
# @flag How to display a command, see `src/lib/kwlib.sh` function `cmd_manager`.
# @sha The SHA from the first commit to be compiled until the branch head.
#
# Return:
# 0 if successfully compiled patchset, 125 (ECANCELED) otherwise.
function build_from_sha() {
  local flag="$1"
  local sha="$2"
  local cmd

  flag=${flag:-'SILENT'}
  cmd="git rebase ${sha} --exec 'kw build'"
  cmd_manager "$flag" "$cmd"

  if [[ "$?" != 0 ]]; then
    complain "kw build failed during the compilation of a patch! Check the rebase in progress for more information."
    return 125 #ECANCELED
  fi
}

function parse_build_options() {
  local long_options='help,info,menu,doc,ccache,cpu-scaling:,warnings::,save-log-to:,llvm,clean,full-cleanup,verbose,cflags:,from-sha:'
  local short_options='h,i,n,d,S:,w::,s:,c,f'
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
  options_values['CLEAN']=''
  options_values['FULL_CLEANUP']=''
  options_values['VERBOSE']=''
  options_values['CFLAGS']="${build_config[cflags]}"
  options_values['FROM_SHA_ARG']=''

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
      --cpu-scaling | -S)
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
      --clean | -c)
        options_values['CLEAN']=1
        shift
        ;;
      --full-cleanup | -f)
        options_values['FULL_CLEANUP']=1
        shift
        ;;
      --cflags)
        options_values['CFLAGS']="$2"
        shift 2
        ;;
      --verbose)
        options_values['VERBOSE']=1
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
      --from-sha)
        options_values['FROM_SHA_ARG']="$2"
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

function build_help() {
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
    '  build (-S | --cpu-scaling) <percentage> - Scale CPU usage by factor' \
    '  build (--ccache) - Enable use of ccache' \
    '  build (-w | --warnings) [warning_levels] - Enable warnings' \
    '  build (-s | --save-log-to) <path> - Save compilation log to path' \
    '  build (--llvm) - Enable use of the LLVM toolchain' \
    '  build (-c | --clean) - Clean option integrated into env' \
    '  build (-f | --full-cleanup) - Reset the kernel tree to its default option integrated into env' \
    '  build (--cflags) - Customize kernel compilation with specific flags' \
    '  build (--verbose) - Show a detailed output' \
    '  build (--from-sha <SHA>) - Build all commits from <SHA> to actual commit'
}

# Every time build.sh is loaded its proper configuration has to be loaded as well
load_build_config
load_notification_config
