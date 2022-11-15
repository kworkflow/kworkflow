include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kwio.sh"

declare -gA options_values

# List of config files with possible values
declare -gA config_file_list=(
  ['build']='arch kernel_img_name cross_compile menu_config doc_type
             cpu_scaling_factor enable_ccache warning_level use_llvm'
  ['mail']='send_opts blocked_emails'
  ['deploy']='kw_files_remote_path deploy_temporary_files_path
              deploy_default_compression dtb_copy_pattern default_deploy_target
              reboot_after_deploy strip_modules_debug_option
              default_deploy_target reboot_after_deploy'
  ['notification']='alert sound_alert_command visual_alert_command'
  ['kworkflow']='ssh_user ssh_ip ssh_port ssh_configfile hostname
                 disable_statistics_data_track gui_on gui_off send_opts
                 blocked_emails checkpatch_opts get_maintainer_opts'
)

function config_main()
{
  local parameters
  local target_config_file
  local option_and_value
  local config_options
  local base_path="${PWD}/.kw"
  local is_show_configurations=false
  local option
  local value

  if [[ "$1" =~ -h|--help ]]; then
    config_help "$1"
    exit 0
  fi

  parse_config_options "$@"
  if [[ "$?" != 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  parameters="${options_values['PARAMETERS']}"
  is_show_configurations="${options_values['IS_SHOW_CONFIGURATIONS']}"

  if [[ -n "${is_show_configurations}" ]]; then
    show_configurations "$parameters"
    return "$?"
  fi

  # Validate and decompose options
  validate_option_parameter "$parameters"
  if [[ "$?" != 0 ]]; then
    complain "Invalid options: ${parameters}"
    complain "Try: target_config.option value"
    return 22 # EINVAL
  fi

  # option value
  target_config_file=$(printf '%s' "$parameters" | cut -d '.' -f 1)
  option_and_value="${parameters#*.}"
  option=$(printf '%s' "$option_and_value" | cut -d ' ' -f 1)
  value=$(printf '%s' "$option_and_value" | cut -d ' ' -f 2)

  if [[ "${options_values['SCOPE']}" == 'global' ]]; then
    base_path="${KW_ETC_DIR}"
  fi

  # Check if config files are valid
  if ! is_config_file_valid "$target_config_file"; then
    complain "Invalid config option: ${target_config_file}"
    return 22 # EINVAL
  fi

  # Check config option
  if ! is_a_valid_config_option "$target_config_file" "$option"; then
    return 22 # EINVAL
  fi

  # Prepare base path
  target_config_file+='.config'
  base_path=$(join_path "$base_path" "$target_config_file")

  # Check if target file exist
  if ! check_if_target_config_exist "$target_config_file" "$base_path"; then
    warning "It looks like that '$target_config_file' does not exists locally."
    warning "Do you want to set this configuration globally?"
    if [[ $(ask_yN 'Do you want to continue?') =~ '0' ]]; then
      warning 'Consider to run: kw init --template'
      exit 125 # ECANCELED
    fi
    base_path="${KW_ETC_DIR}"
    base_path=$(join_path "$base_path" "$target_config_file")
  fi

  if [[ -z "$value" ]]; then
    complain 'You did not specify a value to be set'
    return 22 # EINVAL
  fi

  set_config_value "$option" "$value" "$base_path"
}

function validate_option_parameter()
{
  local parameters="$*"
  local raw_target
  local dot_separator

  # Validate and decompose options
  raw_target=$(printf '%s' "$parameters" | cut -d ' ' -f1)
  dot_separator=$(str_count_char_repetition "$raw_target" '.')
  [[ "$dot_separator" != 1 ]] && return 22 # EINVAL
  return 0
}

# The associative array config_file_list uses the target config file as a key
# and the options as a value; this function checks if the parameter gets as an
# attribute is part of the config option.
#
# @target_config_file String with the config name
#
# Return:
# In case of success return 0, otherwise, return 22.
function is_config_file_valid()
{
  local target_config_file="$1"

  if [[ ! "${!config_file_list[*]}" =~ ${target_config_file} ]]; then
    return 22 # EINVAL
  fi

  return 0
}

# The associative array config_file_list has the target file as a key followed
# by the valid options. This function check if the target option is valid for
# the specific config file.
#
# @target_config_file String with the config name
# @option Option used in the config file
#
# Return:
# In case of success return 0, otherwise, return 22.
function is_a_valid_config_option()
{
  local target_config_file="$1"
  local option="$2"
  local config_options

  # Check config option
  if [[ -z "$option" ]]; then
    complain 'You did not specify a target option'
    return 22 # EINVAL
  fi

  config_options="${config_file_list[$target_config_file]}"

  if [[ ! "$config_options" == *"${option}"* ]]; then
    complain "The ${target_config_file} config, does not support the ${option} option"
    return 95 # ENOTSUP
  fi
}

function check_if_target_config_exist()
{
  local target_config_file="$1"
  local base_path="$2"
  local path

  path=${base_path:-"${PWD}/${KW_DIR}/${target_config_file}"}
  [[ ! -f "$path" ]] && return 2 # ENOENT
  return 0
}

# This function sets variables in the config file to a specified value.
#
# @option: option name in kw config file
# @value: value to set option to
#
# Return:
# In case of success return 0, otherwise, return 22.
function set_config_value()
{
  local option="$1"
  local value="$2"
  local path="$3"

  path=${path:-"${PWD}/${KW_DIR}/${name}"}

  # The 's' option is usually followed by /, however, this convention will not
  # work well if we deal with paths. Here we had to break the pattern a little
  # bit and use < instead of / after the s option to ensure that we accept
  # paths in the config option.$
  sed -i -r "s<($option=).*<\1$value<" "$path"
  sed -i -r "s<#\s*$option<$option<" "$path"
}

function parse_config_options()
{
  local long_options='help,global,local,show'
  local short_options='h,g,l,s'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw config' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['SCOPE']='local'
  options_values['PARAMETERS']=''
  options_values['IS_SHOW_CONFIGURATIONS']=''

  # 'kw config' should list all configurations
  if [[ "$#" == 0 ]]; then
    options_values['IS_SHOW_CONFIGURATIONS']=1
  fi

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help | -h)
        config_help "$1"
        exit
        ;;
      --global | -g)
        options_values['SCOPE']='global'
        shift
        ;;
      --local | -l)
        options_values['SCOPE']='local'
        shift
        ;;
      --show | -s)
        options_values['IS_SHOW_CONFIGURATIONS']=1
        shift
        ;;
      --)
        shift
        ;;
      *)
        options_values['PARAMETERS']+="$1 "
        shift
        ;;
    esac
  done
}

# This function lists all the configurations if no argument is passed or lists
# the configurations of one or more specific config files passed as an argument.
#
# @target_config_files: specific configs to be listed
#
# Return:
# In case of success return 0, otherwise, return 22.
function show_configurations()
{
  local -a target_config_files="$1"
  local -a configs
  local -a options
  local options_buffer
  local value

  include "${KW_LIB_DIR}/kw_config_loader.sh"

  # Check which configs we need to show
  if [[ -n "${target_config_files}" ]]; then
    read -ra configs <<< "${target_config_files}"
  else
    read -ra configs <<< "${!config_file_list[@]}"
  fi

  # For each config file
  for config in "${configs[@]}"; do
    # Check if it is a valid config
    if ! is_config_file_valid "$config"; then
      complain "Invalid config target: ${config}"
      return 22 # EINVAL
    fi

    # Load corresponding config file
    eval "load_${config}_config"

    # This part is heavily depedent of the names defined in kw_config_loader
    if [[ "$config" == 'kworkflow' ]]; then
      declare -n config_array='configurations'
    else
      declare -n config_array="${config}_config"
    fi

    # For each possible option in a config file
    options_buffer=$(printf '%s' "${config_file_list[$config]}" | sed --null-data 's/\n/ /g')
    read -ra options <<< "${options_buffer}"
    for option in "${options[@]}"; do
      value="${config_array[$option]}"
      if [[ -z "$value" ]]; then
        warning "${config}.${option}=N/A"
      else
        printf '%s\n' "${config}.${option}=${value}"
      fi
    done
  done

  return 0
}

function config_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'config'
    return
  fi
  printf '%s\n' 'kw config <config.option value>:' \
    '  config - Show config values' \
    '  config (-g | --global) <config.option value> - Change global config' \
    '  config (-l | --local) <config.option value> - Change local config' \
    '  config (-s | --show) [config]... - Show all or specific current configurations'
}
