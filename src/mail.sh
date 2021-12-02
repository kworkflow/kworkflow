# This file handles all the interactions with git send-email. Currently it
# provides functions to configure the options used by git send-email.
# It's also able to verify if the configurations required to use git send-email
# are set.

include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kw_string.sh"

# Hash containing user options
declare -gA options_values
declare -gA set_confs

declare -ga essential_config_options=('user.name' 'user.email'
  'sendemail.smtpuser' 'sendemail.smtpserver' 'sendemail.smtpserverport')
declare -ga optional_config_options=('sendemail.smtpencryption' 'sendemail.smtppass')

function mail_main()
{
  if [[ "$1" =~ -h|--help ]]; then
    mail_help "$1"
    exit 0
  fi

  parse_mail_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    mail_help
    return 22 # EINVAL
  fi

  get_configs

  if [[ "${options_values['VERIFY']}" == 1 ]]; then
    mail_verify ''
    exit
  fi

  if [[ -n "${options_values['TEMPLATE']}" ]]; then
    template_setup
  fi

  is_inside_work_tree
  if [[ "$?" -gt 0 && "${options_values['SCOPE']}" != 'global' ]]; then
    complain 'Not in a git repository, aborting setup!'
    say 'To apply settings globally rerun with "--global" flag.'
    exit 22 # EINVAL
  fi

  if [[ "${options_values['SETUP']}" == 1 ]]; then
    mail_setup ''
    exit
  fi

  return 0
}

# This function deals with configuring the options used by `git send-email`
# to send patches by email. It adds the loaded configuration options supplied
# by the user. It checks if the given option is already set and if needed
# prompts the user to replace, or ignore the value.
#
# @flag:       Flag to control the behavior of 'cmd_manager'
# @curr_scope: The scope being edited
# @cmd_scope:  The scope being imposed on the commands
# @values:     Array to store relevant values for each option
# @confs:      Signals if no option was set
#
# Return:
# returns 0 if successful, exits with 1 otherwise
function mail_setup()
{
  local flag="$1"
  local curr_scope="${options_values['SCOPE']}"
  local cmd_scope="${options_values['CMD_SCOPE']}"
  local -A values
  local confs=0

  flag=${flag:-'SILENT'}

  for option in "${essential_config_options[@]}" "${optional_config_options[@]}"; do
    config_values 'values' "$option"

    if [[ -n "${values['loaded']}" ]]; then
      if [[ "$option" =~ 'user.email'|'sendemail.smtpuser' ]]; then
        validate_email "${values['loaded']}" || continue
      fi

      if [[ "$option" == 'sendemail.smtpencryption' ]]; then
        validate_encryption "${values['loaded']}" || continue
      fi

      if [[ "${options_values['FORCE']}" == 0 ]]; then
        if [[ -n "${values["$curr_scope"]}" && "${values['loaded']}" != "${values["$curr_scope"]}" ]]; then
          printf '\n'
          warning "'$option' is already set at this scope."
          say "  Proposed change [$curr_scope]:"
          printf '    %s' "${values["$curr_scope"]}"
          say -n ' --> '
          printf '%s\n\n' "${values['loaded']}"

          if [[ "$(ask_yN '  Do you wish to proceed?')" == 0 ]]; then
            options_values["$option"]=''
            complain "  Skipping $option..."
            continue
          fi
        fi
      fi
    fi
  done

  for option in "${essential_config_options[@]}" "${optional_config_options[@]}"; do
    if [[ -n "${options_values["$option"]}" ]]; then
      add_config "$option" "${options_values["$option"]}" "$cmd_scope" "$flag"

      if [[ "$?" == 0 && "$flag" != 'TEST_MODE' ]]; then
        success -n "[$curr_scope] '$option' was set to: "
        printf '%s\n' "${options_values["$option"]}"
      fi
      confs=1
    fi
  done

  if [[ "$confs" == 0 ]]; then
    warning 'No configuration options were set.'
  fi

  return 0
}

# This function validates the encryption. If the passed encryption is not valid
# this will warn the user and clear the option.
#
# @value: The value being passed, encryption must be ssl or tls
#
# Return:
# Returns 0 if valid; 22 if invalid
function validate_encryption()
{
  local value="$1"

  if [[ "$value" =~ ^(ssl|tls)$ ]]; then
    return 0
  fi

  warning "Invalid encryption '$value', you must choose between 'ssl' or 'tls'."
  warning 'Skipping this setting. This defaults to plain smtp.'

  return 22 # EINVAL
}

# This function validates the encryption. If the passed encryption is not valid
# this will warn the user and clear the option.
#
# @option: The option to determine if it should be an email
# @value:  The value being passed
#
# Return:
# Returns 0 if valid; 22 if invalid
function validate_email()
{
  local value="$1"

  if [[ ! "$value" =~ ^[A-Za-z0-9_\.-]+@[A-Za-z0-9_-]+(\.[A-Za-z0-9]+)+$ ]]; then
    complain "Invalid email: $value"
    return 22 #EINVAL
  fi

  return 0
}

# Gets the values associated to a certain config option and puts them in the
# given array.
#
# @_values: reference to the associative array to store the values
# @option: the config option to get the values from
#
# Returns: Nothing
function config_values()
{
  local -n _values="$1"
  local option="$2"
  local scope

  for scope in {'global','local'}; do
    _values["$scope"]="${set_confs["${scope}_$option"]}"
  done

  _values['loaded']="${options_values["$option"]}"
}

function add_config()
{
  local option="$1"
  local value="${2:-${options_values["$option"]}}"
  local cmd_scope="${3:-${options_values['CMD_SCOPE']}}"
  local flag="$4"
  local cmd

  flag=${flag:-'SILENT'}

  cmd="git config --$cmd_scope $option '$value'"

  cmd_manager "$flag" "$cmd"
}

# This function gets all the currently set values for the configurations used
# by this script and writes them to the global variable set_confs
#
# @cmd_scope:  The scope being imposed on the command
# @set_values: The values of the option that are already set
# @option:     The option name
# @value:      The value to update the option to
# @scope:      The scope of the given value
#
function get_configs()
{
  local cmd_scope="${options_values['CMD_SCOPE']}"
  local -a set_values
  local option
  local value
  local scope
  local i=0

  IFS=$'\t\n' read -r -a set_values -d '' <<< "$(get_git_config_regex 'user|sendemail\.smtp' "$cmd_scope")"

  while [[ -n "${set_values["$((i + 1))"]}" ]]; do
    scope="${set_values["$i"]}"
    # These separate the option from the value as they come as a single value
    # this removes the suffix of the string
    option="${set_values["$((i + 1))"]%% *}"
    # this removes the prefix of the string
    value="${set_values["$((i + 1))"]#* }"

    # it's possible to set an option to nothing, this takes that into account
    [[ -z "$value" ]] && value='<empty>'

    # hide user password; not particularly safe solution
    [[ "$option" =~ 'smtppass' ]] && value='********'

    if [[ "${essential_config_options[*]}" =~ "$option".* ]]; then
      set_confs["${scope}_$option"]="$value"
    fi
    if [[ "${optional_config_options[*]}" =~ "$option".* ]]; then
      set_confs["${scope}_$option"]="$value"
    fi
    i="$((i + 2))"
  done
}

# Checks which configs from the given list are not set.
#
# @_config_options: reference to array containing the relevant options
#
# Returns:
# Array with the missing configs
function missing_options()
{
  local -n _config_options="$1"
  local -a missing_conf
  local index=0

  for config in "${_config_options[@]}"; do
    # a space is added to the end of the list to mark word boundaries
    if [[ ! "${!set_confs[*]} " =~ (local|global)_"$config"[[:space:]] ]]; then
      missing_conf["$index"]="$config"
      ((index++))
    fi
  done

  printf '%s\n' "${missing_conf[@]}"
}

# This function checks that the required and recommended options to use
# git send-email have been set. It does not validate the options values, only
# that a value has been set.
#
# @missing_conf:     The options that have not been set
# @missing_rec_conf: The recommended options that have not been set
# @cmd_scope:            Limit the search scope
# @set_confs:        The relevant options that have already been set
#
# Returns:
# Returns 22 if missing any required configuration; 0 otherwise
function mail_verify()
{
  local -a missing_conf
  local -a missing_opt_conf
  local cmd_scope=${options_values['CMD_SCOPE']}

  for config in {'local','global'}'_sendemail.smtpserver'; do
    if [[ -d "${set_confs["$config"]}" ]]; then
      warning 'It appears you are using a local smtpserver with custom configurations.'
      warning "Unfortunately we can't verify these configurations yet."
      warning "  Current value is: ${set_confs["$config"]}"

      return 0
    fi
  done

  mapfile -t missing_opt_conf < <(missing_options 'optional_config_options')

  mapfile -t missing_conf < <(missing_options 'essential_config_options')

  if [[ "${#missing_conf}" -gt 0 ]]; then
    complain 'Missing configurations required for send-email:'
    printf '  %s\n' "${missing_conf[@]}"
    return 22
  fi

  success 'It looks like you are ready to send patches as:'
  if [[ -n "${set_confs['local_user.name']}" ]]; then
    success -n "  ${set_confs['local_user.name']}"
  elif [[ -n "${set_confs['global_user.name']}" ]]; then
    success -n "  ${set_confs['global_user.name']}"
  fi

  if [[ -n "${set_confs['local_user.email']}" ]]; then
    success " <${set_confs['local_user.email']}>"
  elif [[ -n "${set_confs['global_user.email']}" ]]; then
    success " <${set_confs['global_user.email']}>"
  fi

  if [[ "${#missing_opt_conf}" -gt 0 ]]; then
    printf '%s\n' ''
    say 'If you encounter problems you might need to configure these options:'
    printf '  %s\n' "${missing_opt_conf[@]}"
  fi

  return 0
}

# This function lists the required and optional options to use
# git send-email. Also lists any values that are already set.
function mail_list()
{
  get_configs

  success 'These are the essential configurations for git send-email:'
  print_configs 'essential_config_options'

  warning 'These are the optional configurations for git send-email:'
  print_configs 'optional_config_options'
}

function print_configs()
{
  local -n _configs="$1"
  local config
  local option
  local -A values
  local la=0

  for config in "${_configs[@]}"; do
    config_values 'values' "$config"
    option=$(printf '%s\n' "$config" | cut -d '.' -f2)
    say "  ${option^^}"
    if [[ -n "${values['local']}" ]]; then
      printf '    [local: %s]' "${values['local']}"
      la=1
    fi
    if [[ -n "${values['global']}" ]]; then
      if [[ "$la" -gt 0 ]]; then
        printf ', [global: %s]' "${values['global']}"
      else
        printf '    [global: %s]' "${values['global']}"
        la=1
      fi
    fi
    if [[ -n "${values['loaded']}" ]]; then
      if [[ "$la" -gt 0 ]]; then
        printf ', [loaded: %s]' "${values['loaded']}"
      else
        printf '    [loaded: %s]' "${values['loaded']}"
      fi
    fi
    printf '\n'
    la=0
  done
}

# Complain and exit if user tries to pass configuration options before the
# '--setup' flag
function validate_setup_opt()
{
  if [[ "${options_values['SETUP']}" == 0 ]]; then
    complain 'You provided a flag that should only be used with `--setup` or `--template`.'
    complain 'Please check your command and try again.'
    mail_help
    exit 95 # ENOTSUP
  fi

  return 0
}

# This function loads and applies default config values based on the given
# template
#
# @template: name of the chosen template
#
# Returns:
# Returns non-zero if missing any required configuration; 0 otherwise
function template_setup()
{
  local template="${options_values['TEMPLATE']:1}" # removes colon
  local -a available_templates

  if [[ -z "$template" ]]; then
    mapfile -t available_templates < <(find "$KW_ETC_DIR/mail_templates" -type f -printf '%f\n' | sort -d)
    available_templates+=('exit')

    say 'You may choose one of the following templates to start your configuration.'
    printf '(enter the corresponding number to choose)\n'
    select user_choice in "${available_templates[@]^}"; do
      [[ "$user_choice" == 'Exit' ]] && exit

      template="${user_choice,,}"
      break
    done
  fi

  load_template "$template"
}

# Loads the values from the template file to the options_values array
#
# @template: name of the template to be loaded
#
# Returns: 22 if template is not found
function load_template()
{
  local template="$1"
  local index
  local option
  local value
  local template_path

  template_path=$(join_path "$KW_ETC_DIR/mail_templates" "$template")

  if [[ ! -f "$template_path" ]]; then
    complain "Invalid template: $template"
    exit 22 # EINVAL
  fi

  while IFS='=' read -r option value; do
    index="$option"
    options_values["$index"]="$value"
  done < "$template_path"
}

function parse_mail_options()
{
  local index
  local option
  local setup_token=0
  local short_options='t,f,v,l,'
  local long_options='setup,local,global,force,verify,template::,list,'

  long_options+='email:,name:,'
  long_options+='smtpuser:,smtpencryption:,smtpserver:,smtpserverport:,smtppass:,'

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw mail' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['SETUP']=0
  options_values['FORCE']=0
  options_values['VERIFY']=0
  options_values['TEMPLATE']=''
  options_values['SCOPE']='local'
  options_values['CMD_SCOPE']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --list | -l)
        mail_list
        exit
        ;;
      --setup | -t)
        options_values['SETUP']=1
        shift
        ;;
      --email)
        if [[ -z "${options_values['sendemail.smtpuser']}" ]]; then
          options_values['sendemail.smtpuser']="$2"
        fi
        ;& # this continues executing the code for --name
      --name)
        setup_token=1
        option="$(str_remove_prefix "$1" '--')"
        index="user.$option"
        options_values["$index"]="$2"
        shift 2
        ;;
      --smtpencryption)
        setup_token=1
        option="$(str_remove_prefix "$1" '--')"
        index="sendemail.$option"
        options_values["$index"]="$2"
        shift 2
        ;;
      --smtp*)
        setup_token=1
        option="$(str_remove_prefix "$1" '--')"
        index="sendemail.$option"
        options_values["$index"]="$2"
        shift 2
        ;;
      --template)
        option="$(str_strip "${2,,}")"
        options_values['SETUP']=1
        options_values['TEMPLATE']=":$option" # colon sets the option
        shift 2
        ;;
      --local)
        options_values['SCOPE']='local'
        options_values['CMD_SCOPE']='local'
        shift
        ;;
      --global)
        options_values['SCOPE']='global'
        options_values['CMD_SCOPE']='global'
        shift
        ;;
      --verify | -v)
        options_values['VERIFY']=1
        shift
        ;;
      --force | -f)
        options_values['FORCE']=1
        shift
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

  if [[ "$setup_token" == 1 ]]; then
    validate_setup_opt
  fi
}

function mail_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'mail'
    exit
  fi
  printf '%s\n' 'kw mail:' \
    '  mail (-t | --setup) [--local | --global] [-f | --force] (<config> <value>)...' \
    '  mail (-v | --verify) - Check if required configurations are set' \
    '  mail (-l | --list) - List the configurable options' \
    '  mail --template[=<template>] - Set send-email configs based on <template>'
}
