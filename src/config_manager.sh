include "$KW_LIB_DIR/kwio.sh"

declare -gr metadata_dir='metadata'
declare -gr configs_dir='configs'
declare -gA options_values

function config_manager_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'configm'
    return
  fi
  printf '%s\n' 'kw config manager:' \
    '  configm (-s | --save) <name> [(-d | --description) <description>] [-f | --force] - save a config' \
    '  configm (-l | --list) - List config files under kw management' \
    '  configm --get <name> [-f | --force] - Get a config file based named <name>' \
    '  configm (-r | --remove) <name> [-f | --force] - Remove config labeled with <name>'
}

# This function handles the save operation of kernel's '.config' file. It
# checks if the '.config' exists and saves it using git (dir.:
# <kw_install_path>/configs)
#
# @force Force option. If it is set and the current name was already saved,
#        this option will override the '.config' file under the 'name'
#        specified by '-n' without any message.
# @name This option specifies a name for a target .config file. This name
#       represents the access key for .config.
# @description Description for a config file, de descrition from '-d' flag.
function save_config_file()
{
  local -r force="$1"
  local -r name="$2"
  local -r description="$3"
  local -r original_path="$PWD"
  local -r dot_configs_dir="$KW_DATA_DIR/configs"

  if [[ ! -f "$original_path/.config" ]]; then
    complain 'There is no .config file in the current directory'
    exit 2 # ENOENT
  fi

  if [[ ! -d "$dot_configs_dir" || ! -d "$dot_configs_dir/$metadata_dir" ]]; then
    mkdir -p "$dot_configs_dir"
    cd "$dot_configs_dir" || exit_msg 'It was not possible to move to configs dir'
    git init --quiet
    mkdir -p "$metadata_dir" "$configs_dir"
  fi

  cd "$dot_configs_dir" || exit_msg 'It was not possible to move to configs dir'

  # Check if the metadata related to .config file already exists
  if [[ ! -f "$metadata_dir/$name" ]]; then
    touch "$metadata_dir/$name"
  elif [[ "$force" != 1 ]]; then
    if [[ $(ask_yN "$name already exists. Update?") =~ '0' ]]; then
      complain 'Save operation aborted'
      cd "$original_path" || exit_msg 'It was not possible to move back from configs dir'
      exit 0
    fi
  fi

  if [[ -n "$description" ]]; then
    printf '%s\n' "$description" > "$metadata_dir/$name"
  fi

  cp "$original_path/.config" "$dot_configs_dir/$configs_dir/$name"
  git add "$configs_dir/$name" "$metadata_dir/$name"
  git commit -m "New config file added: $USER - $(date)" > /dev/null 2>&1

  if [[ "$?" == 1 ]]; then
    warning "Warning: $name: there's nothing new in this file"
  else
    success "Saved $name"
  fi

  cd "$original_path" || exit_msg 'It was not possible to move back from configs dir'
}

function list_configs()
{
  local -r dot_configs_dir="$KW_DATA_DIR/configs"
  local name
  local content

  if [[ ! -d "$dot_configs_dir" || ! -d "$dot_configs_dir/$metadata_dir" ]]; then
    say 'There is no tracked .config file'
    exit 0
  fi

  printf '%-30s | %-30s\n' 'Name' $'Description\n'
  for filename in "$dot_configs_dir/$metadata_dir"/*; do
    [[ ! -f "$filename" ]] && continue
    name=$(basename "$filename")
    content=$(cat "$filename")
    printf '%-30s | %-30s\n' "$name" "$content"
  done
}

# Remove and Get operation in the configm has similar criteria for working,
# because of this, basic_config_validations centralize the basic requirement
# validation.
#
# @target File name of the target config file
# @force Force option. If set, it will ignores the warning message.
# @operation You can specify the operation name here
# @message Customized message to be showed to the users
#
# Returns:
# Return 0 if everything ends well, otherwise return an errno code.
function basic_config_validations()
{
  local target="$1"
  local force="$2"
  local operation="$3" && shift 3
  local message="$*"
  local -r dot_configs_dir="$KW_DATA_DIR/configs/configs"

  if [[ ! -f "$dot_configs_dir/$target" ]]; then
    complain "No such file or directory: $target"
    exit 2 # ENOENT
  fi

  if [[ "$force" != 1 ]]; then
    warning "$message"
    if [[ $(ask_yN 'Are you sure that you want to proceed?') =~ '0' ]]; then
      complain "$operation operation aborted"
      exit 0
    fi
  fi
}

# This function retrieves from one of the config files under the control of kw
# and put it in the current directory. This operation can be dangerous since it
# will override the existing .config file; because of this, it has a warning
# message.
#
# @target File name of the target config file
# @force Force option. If it is set and the current name was already saved,
#        this option will override the '.config' file under the 'name'
#        specified by '-n' without any message.
#
# Returns:
# Exit with 0 if everything ends well, otherwise exit an errno code.
function get_config()
{
  local target="$1"
  local force="$2"
  local -r dot_configs_dir="$KW_DATA_DIR/configs/configs"
  local -r msg='This operation will override the current .config file'

  force=${force:-0}

  # If we does not have a local config, there's no reason to warn the user
  [[ ! -f "$PWD/.config" ]] && force=1

  basic_config_validations "$target" "$force" "Get" "$msg"

  cp "$dot_configs_dir/$target" .config
  say "Current config file updated based on $target"
}

# Remove a config file under kw management
#
# @target File name of the target config file
# @force Force option.
#
# Returns:
# Exit 0 if everything ends well, otherwise exit an errno code.
function remove_config()
{
  local target="$1"
  local force="$2"
  local original_path="$PWD"
  local -r dot_configs_dir="$KW_DATA_DIR/configs"
  local -r msg="This operation will remove $target from kw management"

  basic_config_validations "$target" "$force" 'Remove' "$msg"

  cd "$dot_configs_dir" || exit_msg 'It was not possible to move to configs dir'
  git rm "$configs_dir/$target" "$dot_configs_dir/$metadata_dir/$target" > /dev/null 2>&1
  git commit -m "Removed $target config: $USER - $(date)" > /dev/null 2>&1
  cd "$original_path" || exit_msg 'It was not possible to move back from configs dir'

  say "The $target config file was removed from kw management"

  # Without config file, there's no reason to keep config directory
  if [ ! "$(ls "$dot_configs_dir")" ]; then
    rm -rf "/tmp/$configs_dir"
    mv "$dot_configs_dir" /tmp
  fi
}

# This function handles the options available in 'configm'.
#
# @* This parameter expects a list of parameters, such as '-n', '-d', and '-f'.
#
# Returns:
# Return 0 if everything ends well, otherwise return an errno code.
function execute_config_manager()
{
  local name_config
  local description_config
  local force

  if [[ -z "$*" ]]; then
    complain 'Please, provide an argument'
    config_manager_help
    exit 22 # EINVAL
  fi

  parse_configm_options "$@"

  if [[ "$?" -gt 0 ]]; then
    exit 22 # EINVAL
  fi

  name_config="${options_values['SAVE']}"
  description_config="${options_values['DESCRIPTION']}"
  force="${options_values['FORCE']}"

  if [[ -n "${options_values['SAVE']}" ]]; then
    save_config_file "$force" "$name_config" "$description_config"
    return
  fi

  if [[ -n "${options_values['LIST']}" ]]; then
    list_configs
    return
  fi

  if [[ -n "${options_values['GET']}" ]]; then
    get_config "${options_values['GET']}" "$force"
    return
  fi

  if [[ -n "${options_values['REMOVE']}" ]]; then
    remove_config "${options_values['REMOVE']}" "$force"
    return
  fi
}

# This function parses the options from 'kw configm', and populates the global
# variable options_values accordingly.
function parse_configm_options()
{
  local short_options
  local long_options
  local options

  long_options='save:,list,get:,remove:,force,description:'
  short_options='s,l,r:,d:,h,f'

  options="$(getopt \
    --name 'kw configm' \
    --options "$short_options" \
    --longoptions "$long_options" \
    -- "$@")"

  if [[ "$?" != 0 ]]; then
    return 22 # EINVAL
  fi

  options_values['SAVE']=''
  options_values['FORCE']=''
  options_values['DESCRIPTION']=''
  options_values['LIST']=''
  options_values['GET']=''
  options_values['REMOVE']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h)
        config_manager_help "$1"
        exit 0
        ;;
      --force | -f)
        options_values['FORCE']=1
        shift
        ;;
      --save | -s)
        # Validate string name
        if [[ "$2" =~ ^- || -z "${2// /}" ]]; then
          complain 'Invalid argument'
          return 22 # EINVAL
        fi
        options_values['SAVE']+="$2"
        shift 2
        ;;
      --description | -d)
        options_values['DESCRIPTION']+="$*"
        shift 2
        ;;
      --list | -l)
        options_values['LIST']=1
        shift
        ;;
      --get)
        options_values['GET']+="$2"
        shift 2
        ;;
      --remove | -r)
        options_values['REMOVE']+="$2"
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
}
