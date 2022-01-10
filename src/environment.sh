include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kwio.sh"

declare -gr metadata_dir='.metadata'
declare -gr envs_dir='envs'
declare -gr dot_envs_dir="$KW_DATA_DIR/$envs_dir"
declare -gA options_values

function env_manager()
{
  if [[ -z "$*" ]]; then
    if [[ ! -v "$KW_ENV" ||
      ! -d "$dot_envs_dir" && ! -d "$dot_configs_dir/$metadata_dir" ]]; then
      say 'There are no environments in the current folder'
      return 0
    fi

    list_envs
    return "$?"
  fi

  if [[ "$1" =~ -h|--help ]]; then
    env_help "$1"
    exit 0
  fi

  parse_env_options "$@"

  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    exit 22 # EINVAL
  fi

  if [[ ! -v "$KW_ENV" ||
    ! -d "$dot_envs_dir" && ! -d "$dot_configs_dir/$metadata_dir" ]]; then
    complain 'There are no environments in the current folder'
    return 2 # ENOENT
  fi

  if [[ -n "${options_values['SWITCH']}" ]]; then
    switch_env "${options_values['SWITCH']}" "${options_values['DESCRIPTION']}"
    return "$?"
  fi

  if [[ -n "${options_values['LIST']}" ]]; then
    list_envs
    return "$?"
  fi

  if [[ -n "${options_values['CLEAN']}" ]]; then
    clean_env "${options_values['CLEAN']}"
    return "$?"
  fi

  if [[ -n "${options_values['DESTROY']}" ]]; then
    destroy_env "${options_values['DESTROY']}"
    return "$?"
  fi
}

function list_envs()
{
  local -r dot_envs_dir="$KW_DATA_DIR/$envs_dir"
  local name
  local content

  printf '%-30s | %-30s\n' 'Name' $'Description\n'
  for filename in "$dot_configs_dir/$metadata_dir"/*; do
    [[ ! -f "$filename" ]] && continue
    name=$(basename "$filename")
    content=$(< "$filename")
    printf '%-30s | %-30s\n' "$name" "$content"
  done
}

function switch_envs()
{
  local -r name="$1"
  local -r description="$2"
  local -r current_output="$dot_envs_dir/$name"
  local -r original_folder="$PWD"

  # Create folders if missing
  if [[ ! -d "$dot_envs_dir/$metadata_dir" ]]; then
    mkdir -p "$dot_envs_dir/$metadata_dir"
    cmd_manager "" "make mrproper -j"
  fi

  pushd "$dot_envs_dir" || exit_msg 'It was not possible to move to envs dir'

  # Check if the metadata related to .config file already exists and if so
  # check if the user wants to update description
  if [[ -f "$metadata_dir/$name" &&
    -n "$description" &&
    $(ask_yN "$name already exists. Update description?") =~ '0' ]]; then
    complain 'Switch operation aborted'
    popd || exit_msg 'It was not possible to move back from envs dir'
    return 0
  fi

  # Get valid .config location
  get_current_env

  if [[ "$?" != 0 ]]; then
    if [[ -f "$original_folder/.config" ]]; then
      cp "$original_folder/.config" "$dot_envs_dir/$name"
    else
      complain "Switch operation aborted. No valid config to be used in env $name"
      popd || exit_msg 'It was not possible to move back from envs dir'
      return 2 # ENOENT
    fi
  else
    cp "$dot_envs_dir/$KW_ENV/.config" "$dot_envs_dir/$name"
  fi

  cmd_manager "" "make prepare archprepare O=$current_output -j"

  # Save current env
  printf '%s\n' "$name" > "$metadata_dir/current.meta"

  [[ -n "$description" ]] &&
    printf '%s\n' "$description" > "$metadata_dir/$name"

  popd || exit_msg 'It was not possible to move back from envs dir'
}

function get_current_env()
{
  if [[ ! -v "KW_ENV" ]]; then
    [[ ! -f "$metadata_dir/current.meta" ]] && return 2 # ENOENT
    KW_ENV="$(< "$metadata_dir/current.meta")"
  fi
}

function clean_env()
{
  local -r name="$1"
  local -r current_output

  if [[ -z "$name" ]]; then
    if [[ "$(get_current_env)" != 0 ]]; then
      complain "No env set"
      return 2 # ENOENT
    fi
    current_output="$dot_envs_dir/$KW_ENV"
  else
    if [[ ! -d "$dot_envs_dir/$name" ]]; then
      complain "Invalid arg"
      return 22 # EINVAL
    fi
    current_output="$dot_envs_dir/$name"
  fi

  cmd_manager "" "make clean O=$current_output -j"
}

function destroy_env()
{
  local -r name="$1"
  local -r current_output

  get_current_env

  if [[ "$KW_ENV" = "$name" ]]; then
    complain "Cannot delete current env"
    return 22 # EINVAL
  fi

  if [[ ! -d "$dot_envs_dir/$name" ]]; then
    complain "Invalid arg"
    return 22 # EINVAL
  fi
  current_output="$dot_envs_dir/$name"

  rm -rf "$current_output"
}

function parse_env_options()
{
  local short_options
  local long_options
  local options

  long_options='switch:,description:,list,clean::,destroy:'
  short_options='s:,d:,l,c::,D:'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw environment' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['SWITCH']=''
  options_values['DESCRIPTION']=''
  options_values['LIST']=''
  options_values['CLEAN']=''
  options_values['DESTROY']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --switch | -s)
        # Validate string name
        if [[ "$2" =~ ^- || -z "${2// /}" ]]; then
          complain 'Invalid argument'
          return 22 # EINVAL
        fi
        options_values['SWITCH']="$2"
        shift 2
        ;;
      --description | -d)
        # Validate string name
        if [[ "$2" =~ ^- || -z "${2// /}" ]]; then
          complain 'Invalid argument'
          return 22 # EINVAL
        fi
        options_values['DESCRIPTION']="$2"
        shift 2
        ;;
      --list | -l)
        options_values['LIST']=1
        shift
        ;;
      --clean | -c)
        # Handling optional parameter
        if [[ "$2" =~ ^- || -z "${2// /}" ]]; then
          options_values['CLEAN']='1'
          shift
        else
          options_values['CLEAN']="$2"
          shift 2
        fi
        ;;
      --destroy | -D)
        # Validate string name
        if [[ "$2" =~ ^- || -z "${2// /}" ]]; then
          complain 'Invalid argument'
          return 22 # EINVAL
        fi
        options_values['DESTROY']="$2"
        shift 2
        ;;
      --)
        shift
        ;;
      *)
        complain "Invalid option: $1"
        exit 22 # EINVAL
        ;;
    esac
  done

  if [[ -z "${options_values['SWITCH']}" &&
    -n "${options_values['DESCRIPTION']}" ]]; then
    complain '-d|--description can only be used with --switch'
    return 22 # EINVAL
  fi
}

function env_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'environment'
    return
  fi
  printf '%s\n' 'kw environments:' \
    '  env (-s | --switch) <name> [-d | --description <description>] - Switch to another (new) environment' \
    '  env (-l | --list) - List existing kw environments' \
    '  env (-c | --clean) <name> - Clean an environment' \
    '  env (-D | --destroy) <name> - Destroy an environment'
}
