include "${KW_LIB_DIR}/kwlib.sh"
include "${KW_LIB_DIR}/kwio.sh"
include "${KW_LIB_DIR}/kw_string.sh"

declare -gA options_values

# List of config files
declare -ga config_file_list=(
  'build'
  'deploy'
  'kworkflow'
  'mail'
  'notification'
  'remote'
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

  if [[ -n "${options_values['CREATE']}" ]]; then
    create_new_env
    return "$?"
  fi

  if [[ -n "${options_values['USE']}" ]]; then
    use_target_env
    return "$?"
  fi

  if [[ -n "${options_values['LIST']}" ]]; then
    list_env_available_envs
    return "$?"
  fi

  if [[ -n "${options_values['DESTROY']}" ]]; then
    destroy_env
    return "$?"
  fi
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

  if [[ ! -d "${local_kw_configs}/${target_env}" ]]; then
    return 22 # EINVAL
  fi

  for config in "${config_file_list[@]}"; do
    # At this point, we should not have a config file under .kw folder. All
    # of them must be under the new env folder. Let's remove any left over
    if [[ ! -L "${local_kw_configs}/${config}.config" ]]; then
      tmp_trash=$(mktemp -d)
      mv "${local_kw_configs}/${config}.config" "$tmp_trash"
    fi

    # Create symbolic link
    ln --symbolic --force "${local_kw_configs}/${target_env}/${config}.config" "${local_kw_configs}/${config}.config"
  done

  touch "${local_kw_configs}/${ENV_CURRENT_FILE}"
  printf '%s\n' "$target_env" > "${local_kw_configs}/${ENV_CURRENT_FILE}"
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

  if [[ ! -d "$local_kw_configs" || ! -f "$local_kw_build_config" || ! -f "$local_kw_deploy_config" ]]; then
    complain 'It looks like that you did not setup kw in this repository.'
    complain 'For the first setup, take a look at: kw init --help'
    exit 22 # EINVAL
  fi

  # Check if the env name was not created
  output=$(find "$local_kw_configs" -type d -name "$env_name")
  if [[ -n "$output" ]]; then
    warning "It looks that you already have '$env_name' environment"
    warning 'Please, choose a new environment name.'
    return 22 # EINVAL
  fi

  # Create env folder
  mkdir -p "${local_kw_configs}/${env_name}"

  # Copy local configs
  for config in "${config_file_list[@]}"; do
    cp "${local_kw_configs}/${config}.config" "${local_kw_configs}/${env_name}"
  done

  # Handle build and config folder
  mkdir -p "${cache_build_path}/${env_name}"
  current_env_name=$(get_current_env_name)
  ret="$?"

  if [[ -f "${PWD}/.config" ]]; then
    mv "${PWD}/.config" "${cache_build_path}/${env_name}"
  elif [[ "$ret" == 0 ]]; then
    cp "${cache_build_path}/${current_env_name}/.config" "${cache_build_path}/${env_name}"
  fi
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
  local output

  if [[ ! -d "$local_kw_configs" ]]; then
    complain 'It looks like that you did not setup kw in this repository.'
    complain 'For the first setup, take a look at: kw init --help'
    exit 22 # EINVAL
  fi

  output=$(find "$local_kw_configs" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort -d)
  if [[ -z "$output" ]]; then
    say 'Kw did not find any environment. You can create a new one with the --create option.'
    say 'See kw env --help'
    return 0
  fi

  if [[ -f "${local_kw_configs}/${ENV_CURRENT_FILE}" ]]; then
    current_env=$(< "${local_kw_configs}/${ENV_CURRENT_FILE}")
    say "Current env:"
    printf ' -> %s\n' "$current_env"
  fi

  say 'All kw environments set for your local folder:'
  printf '%s\n' "$output"
}

# This function destroys any env folder inside the .kw directory that it receives as parameter
#
# Return:
# Return 22 if .kw folder does not exists
function destroy_env()
{
  local local_kw_configs="${PWD}/.kw"
  local output
  local env_name=${options_values['DESTROY']}

  if [[ ! -d "${local_kw_configs}/${env_name}" ]]; then
    complain "We can't find the folder. Please, check the name and try again."
    exit 22 # EINVAL
  fi

  rm -rf "${local_kw_configs}/${env_name}"

}

function parse_env_options()
{
  local long_options='help,list,create:,use:,destroy:'
  local short_options='h,l,c:,u:,d:'
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
  options_values['DESTROY']=''

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
      --destroy | -d)
        options_values['DESTROY']="$2"
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
    '  env (-d | --destroy) - Delete a specific environment'
}
