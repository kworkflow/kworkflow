include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"

declare -gA options_values

# List of config files
declare -ga config_file_list=(
  'build'
  'deploy'
  'kworkflow'
  'mail'
  'notification'
  'remote'
  'vm'
)

declare -gr ENV_CURRENT_FILE='env.current'

function env_main()
{
  parse_env_options "$@"
  if [[ $? -gt 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    env_help
    exit 22 # EINVAL
  fi

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  if [[ -n "${options_values['CREATE']}" ]]; then
    create_new_env
    return "$?"
  fi

  if [[ -n "${options_values['USE']}" ]]; then
    validate_env_before_switch
    if [[ "$?" != 22 ]]; then
      use_target_env
      return "$?"
    fi
    return 22 # EINVAL
  fi

  if [[ -n "${options_values['DESTROY']}" ]]; then
    destroy_env
    return "$?"
  fi

  if [[ -n "${options_values['LIST']}" ]]; then
    list_env_available_envs
    return "$?"
  fi

  if [[ -n "${options_values['EXIT_ENV']}" ]]; then
    exit_env
    return "$?"
  fi
}

# If the env option is requested, it means the O= option from the kernel
# makefile is used, and this option requires a clean kernel tree to work as
# expected. This function checks if the current kernel tree is clean.
#
# Return:
# Return 22 in case of error
function validate_env_before_switch()
{
  local should_fail=0
  local list_of_object_file

  load_module_text "${KW_ETC_DIR}/strings/env.txt"

  # Check if there is a .config file
  [[ -f "${PWD}/.config" ]] && should_fail=1

  # Check if there is any object file
  list_of_object_file=$(find "${PWD}" -name '*.o')
  [[ "$?" != 0 || -n ${list_of_object_file} ]] && should_fail=1

  # Check for ko files
  list_of_object_file=$(find "${PWD}" -name '*.ko')
  [[ "$?" != 0 || -n ${list_of_object_file} ]] && should_fail=1

  if [[ "$should_fail" == 1 ]]; then
    complain "${module_text_dictionary[use_failure_explanation]}"
    return 22 # EINVAL
  fi

  return 0
}

# When we switch between different kw envs we just change the symbolic links
# for pointing to the target env.
#
# Return:
# Return 22 in case of error
function use_target_env()
{
  local target_env="${options_values['USE']}"
  local local_kw_configs="${PWD}/.kw"
  local tmp_trash
  local cmd

  flag=${flag:-'SILENT'}

  if [[ ! -d "${local_kw_configs}/${ENV_DIR}/${target_env}" ]]; then
    return 22 # EINVAL
  fi

  for config in "${config_file_list[@]}"; do
    # At this point, we should not have a config file under .kw folder. All
    # of them must be under the new env folder. Let's remove any left over
    if [[ ! -L "${local_kw_configs}/${config}.config" ]]; then
      tmp_trash=$(mktemp -d)

      # Check if the config file exists before trying to remove it.
      [[ ! -f "${local_kw_configs}/${config}.config" ]] && continue

      cmd="mv ${local_kw_configs}/${config}.config ${tmp_trash}"
      cmd_manager "$flag" "$cmd"
    fi

    # Create symbolic link
    cmd="ln --symbolic --force ${local_kw_configs}/${ENV_DIR}/${target_env}/${config}.config ${local_kw_configs}/${config}.config"
    cmd_manager "$flag" "$cmd"
  done

  cmd="touch ${local_kw_configs}/${ENV_CURRENT_FILE}"
  cmd_manager "$flag" "$cmd"
  printf '%s\n' "$target_env" > "${local_kw_configs}/${ENV_CURRENT_FILE}"
}

# This function allows users to "exit" a specific env if they no longer
# want to use it.
function exit_env()
{
  local current_env
  local local_kw_configs="${PWD}/.kw"
  local cmd

  flag=${flag:-'SILENT'}

  if [[ ! -f "${local_kw_configs}/${ENV_CURRENT_FILE}" ]]; then
    say 'You are not using any env at the moment'
    return
  fi

  current_env=$(< "${local_kw_configs}/${ENV_CURRENT_FILE}")

  warning "You are about to leave the env setup, and ${current_env} config files will be used as a default."
  if [[ $(ask_yN 'Do you really want to proceed?') =~ '1' ]]; then
    for config in "${config_file_list[@]}"; do
      # All symbolic links will be removed, and the current env configuration files
      # will be copied to the .kw folder. We will only need the original files of the
      # current env, the symlinks will be removed as they only point to these original files.
      if [[ -L "${local_kw_configs}/${config}.config" ]]; then
        cmd="rm ${local_kw_configs}/${config}.config"
        cmd_manager "$flag" "$cmd"
      fi

      # Check if the config file exists before trying to copy it.
      [[ ! -f "${local_kw_configs}/${ENV_DIR}/${current_env}/${config}.config" ]] && continue
      cmd="cp ${local_kw_configs}/${ENV_DIR}/${current_env}/${config}.config ${local_kw_configs}"
      cmd_manager "$flag" "$cmd"
    done
    cmd="rm ${local_kw_configs}/${ENV_CURRENT_FILE}"
    cmd_manager "$flag" "$cmd"
    success 'You left the environment feature.'
  fi
}

# When we are working with kw environments, we provide the option for creating
# a new env based on the current set of configurations. This function creates
# the new env folder based on the current configurations. In summary, it will
# copy the config files in use and generate the env folder for that.
#
# Return:
# Return 22 in case of error
function create_new_env()
{
  local local_kw_configs="${PWD}/.kw"
  local local_kw_build_config="${local_kw_configs}/build.config"
  local local_kw_deploy_config="${local_kw_configs}/deploy.config"
  local env_name=${options_values['CREATE']}
  local cache_build_path="$KW_CACHE_DIR"
  local current_env_name
  local output
  local ret
  local cmd

  flag=${flag:-'SILENT'}

  if [[ ! -d "$local_kw_configs" || ! -f "$local_kw_build_config" || ! -f "$local_kw_deploy_config" ]]; then
    complain 'It looks like that you did not setup kw in this repository.'
    complain 'For the first setup, take a look at: kw init --help'
    exit 22 # EINVAL
  fi

  # Create envs folder
  cmd="mkdir -p ${local_kw_configs}/${ENV_DIR}"
  cmd_manager "$flag" "$cmd"

  # Check if the env name was not created
  output=$(find "${local_kw_configs}/${ENV_DIR}" -type d -name "$env_name")
  if [[ -n "$output" ]]; then
    warning "It looks that you already have '$env_name' environment"
    warning 'Please, choose a new environment name.'
    return 22 # EINVAL
  fi

  # Create env folder
  cmd="mkdir -p ${local_kw_configs}/${ENV_DIR}/${env_name}"
  cmd_manager "$flag" "$cmd"

  # Copy local configs
  for config in "${config_file_list[@]}"; do
    if [[ ! -e "${local_kw_configs}/${config}.config" ]]; then
      say "${config}.config does not exist. Creating a default one."
      cmd="cp ${KW_ETC_DIR}/${config}.config ${local_kw_configs}/${ENV_DIR}/${env_name}"
      cmd_manager "$flag" "$cmd"
    else
      cmd="cp ${local_kw_configs}/${config}.config ${local_kw_configs}/${ENV_DIR}/${env_name}"
      cmd_manager "$flag" "$cmd"
    fi
  done

  # Handle build and config folder
  cmd="mkdir -p ${cache_build_path}/${ENV_DIR}/${env_name}"
  cmd_manager "$flag" "$cmd"

  current_env_name=$(get_current_env_name)
  ret="$?"
  # If we already have an env, we should copy the config file from it.
  if [[ "$ret" == 0 ]]; then
    cmd="cp ${cache_build_path}/${ENV_DIR}/${current_env_name}/.config ${cache_build_path}/${ENV_DIR}/${env_name}/.config"
    cmd_manager "$flag" "$cmd"
    return
  elif [[ -f "${PWD}/.config" ]]; then
    cmd="cp ${PWD}/.config ${cache_build_path}/${ENV_DIR}/${env_name}"
    cmd_manager "$flag" "$cmd"
    return
  fi

  warning "You don't have a config file, get it from default paths"
  if [[ -e /proc/config.gz ]]; then
    cmd="zcat /proc/config.gz > ${cache_build_path}/${ENV_DIR}/${env_name}/.config"
    cmd_manager "$flag" "$cmd"
  elif [[ -e "/boot/config-$(uname -r)" ]]; then
    cmd="cp /boot/config-$(uname -r) ${cache_build_path}/${ENV_DIR}/${env_name}/.config"
    cmd_manager "$flag" "$cmd"
  else
    warning 'kw was not able to find any valid config file for the new env'
    return 22 # EINVAL
  fi
}

# This Function gives the user the feature to destroy an environment.
function destroy_env()
{
  local local_kw_configs="${PWD}/.kw"
  local cache_build_path="$KW_CACHE_DIR"
  local current_env
  local env_name=${options_values['DESTROY']}
  local cmd

  flag=${flag:-'SILENT'}

  if [[ ! -d "$local_kw_configs" ]]; then
    complain 'It looks like that you did not setup kw in this repository.'
    complain 'For the first setup, take a look at: kw init --help'
    return 22 # EINVAL
  fi

  if [[ ! -d "${local_kw_configs}/${ENV_DIR}/${env_name}" ]]; then
    complain "The environment '${env_name}' does not exist."
    return 22 # EINVAL
  fi

  if [[ $(ask_yN 'Are you sure you want to delete this environment?') =~ 0 ]]; then
    return 22 # EINVAL
  fi

  if [[ -f "${local_kw_configs}/${ENV_CURRENT_FILE}" ]]; then
    current_env=$(< "${local_kw_configs}/${ENV_CURRENT_FILE}")
    if [[ "$current_env" == "$env_name" ]]; then
      exit_env
    fi
  fi

  cmd="rm -rf ${local_kw_configs:?}/${ENV_DIR}/${env_name} && rm -rf ${cache_build_path:?}/${ENV_DIR}/${env_name}"
  cmd_manager "$flag" "$cmd"
  success "The \"${env_name}\" environment has been destroyed."
}

function no_env_message()
{
  say 'Kw did not find any environment. You can create a new one with the --create option.'
  say 'See kw env --help'
}

# This function searches for any folder inside the .kw directory and considers
# it an env.
#
# Return:
# Return 22 if .kw folder does not exists
function list_env_available_envs()
{
  local local_kw_configs="${PWD}/.kw"
  local current_env
  declare -a all_envs

  if [[ ! -d "$local_kw_configs" ]]; then
    complain 'It looks like that you did not setup kw in this repository.'
    complain 'For the first setup, take a look at: kw init --help'
    exit 22 # EINVAL
  fi

  if [[ ! -d "${local_kw_configs}/${ENV_DIR}" ]]; then
    no_env_message
    return 0
  fi

  readarray -t all_envs < <(find "${local_kw_configs}/${ENV_DIR}" -maxdepth 1 -type d -printf '%P\n' | sort --dictionary-order)
  if [[ "${#all_envs[@]}" -eq 0 ]]; then
    no_env_message
    return 0
  fi

  if [[ -f "${local_kw_configs}/${ENV_CURRENT_FILE}" ]]; then
    current_env=$(< "${local_kw_configs}/${ENV_CURRENT_FILE}")
    say 'Current env:'
    printf ' -> %s: %s\n\n' "$current_env" "${KW_CACHE_DIR}/${ENV_DIR}/${current_env}"
  fi

  warning 'Other kw environments:'
  # For the below loop, we want to split the array
  # shellcheck disable=SC2068
  for env in ${all_envs[@]}; do
    printf ' * %s: %s\n' "$env" "${KW_CACHE_DIR}/${ENV_DIR}/${env}"
  done
}

function parse_env_options()
{
  local long_options='help,list,create:,use:,exit-env,destroy:,verbose'
  local short_options='h,l,c:,u:,e,d:'
  local count

  kw_parse "$short_options" "$long_options" "$@" > /dev/null

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw env' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['LIST']=''
  options_values['CREATE']=''
  options_values['USE']=''
  options_values['EXIT_ENV']=''
  options_values['DESTROY']=''
  options_values['VERBOSE']=''

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help | -h)
        env_help "$1"
        exit
        ;;
      --list | -l)
        options_values['LIST']=1
        shift
        ;;
      --create | -c)
        count=$(str_count_char_repetition "$2" ' ')
        if [[ "$count" -ge 1 ]]; then
          complain "Please, do not use spaces in the env name"
          return 22 # EINVAL
        fi

        str_has_special_characters "$2"
        if [[ "$?" == 0 ]]; then
          complain "Please, do not use special characters (!,@,#,$,%,^,&,(,), and +) in the env name"
          return 22 # EINVAL
        fi
        options_values['CREATE']="$2"
        shift 2
        ;;
      --use | -u)
        options_values['USE']="$2"
        shift 2
        ;;
      --exit-env | -e)
        options_values['EXIT_ENV']=1
        shift
        ;;
      --destroy | -d)
        options_values['DESTROY']="$2"
        shift 2
        ;;
      --verbose)
        options_values['VERBOSE']=1
        shift
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

function env_help()
{
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'env'
    return
  fi
  printf '%s\n' 'kw env:' \
    '  env [-l | --list] - List all environments available' \
    '  env [-u | --use] <NAME> - Use some specific env' \
    '  env (-c | --create) - Create a new environment' \
    '  env (-e | --exit-env) - Exit environment mode' \
    '  env (-d | --destroy) - Destroy an environment' \
    '  env (--verbose) - Show a detailed output'
}
