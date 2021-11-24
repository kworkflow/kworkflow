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

  if [[ "${options_values['VERIFY']}" == 1 ]]; then
    get_configs
    mail_verify ''
    exit
  fi

  if [[ "${options_values['SETUP']}" == 1 ]]; then
    get_configs
    mail_setup ''
    exit
  fi

  return 0
}

# This function deals with configuring the options used by `git send-email`
# to send patches by email
#
# Return:
# returns 0 if successful, exits with 1 otherwise
function mail_setup()
{
  local flag="$1"
  local confs=0

  flag=${flag:-'SILENT'}

  is_inside_work_tree
  if [[ "$?" -gt 0 && "${options_values['SCOPE']}" != 'global' ]]; then
    complain 'Not in a git repository, aborting setup!'
    say 'To apply settings globally rerun with "--global" flag.'
    exit 22 # EINVAL
  fi

  for option in "${!options_values[@]}"; do
    if [[ "$option" =~ smtp|user\.(email|name) ]]; then
      check_add_config "$flag" "$option"
      confs=1
    fi
  done

  if [[ "$confs" == 0 ]]; then
    warning 'No configuration options were given, no options were set.'
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
    options_values['sendemail.smtpencryption']="$value"
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
  local option="$1"
  local value="$2"

  if [[ "$option" =~ ^(email|smtpuser)$ ]]; then
    if [[ ! "$value" =~ ^[A-Za-z0-9_\.-]+@[A-Za-z0-9_-]+(\.[A-Za-z0-9]+)+$ ]]; then
      complain "Invalid $option: $value"
      return 22 #EINVAL
    fi
  fi

  return 0
}

# This function adds the supplied configuration option. It first checks if the
# given option has been set, then prompts the user to replace, add, or ignore
# the configuration
#
# @option:     The option being edited
# @value:      The value to update the option to
# @curr_scope: The scope being edited
# @cmd_scope:  The scope being imposed on the commands
# @set_option: The relevant index to access set_confs
# @scope:      Used to go through local and global scopes
#
# Return:
# Returns 0 if successful; non-zero otherwise
function check_add_config()
{
  local flag="$1"
  local option="$2"
  local value="${options_values["$option"]}"
  local curr_scope="${options_values['SCOPE']}"
  local cmd_scope="${options_values['CMD_SCOPE']}"
  local set_option="${curr_scope}_$option"
  local scope

  flag=${flag:-'SILENT'}

  if [[ "${options_values['FORCE']}" == 0 ]]; then
    if [[ -n "${set_confs["$set_option"]}" && "$value" != "${set_confs["$set_option"]}" ]]; then
      warning "The configuration $option is already set with the following value(s):"
      for scope in {'global','local'}; do
        if [[ -n "${set_confs["${scope}_$option"]}" ]]; then
          warning -n "  [$scope]: "
          printf '%s\n' "${set_confs["${scope}_$option"]}"
        fi
      done

      printf '%s\n' '' "You are currently editing at the [$curr_scope] scope." \
        'If you continue the value at this scope will be overwritten.' \
        "The new value will be '$value'"

      if [[ "$(ask_yN 'Do you wish to proceed?')" == 0 ]]; then
        complain "Skipping $option..."
        return 125 # ECANCELED
      fi
    fi
  fi

  add_config "$option" "$value" "$cmd_scope" "$flag"

  if [[ "$?" == 0 && "$flag" != 'TEST_MODE' ]]; then
    success "$option at the [$curr_scope] scope was successfully set to '$value'"
  fi
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
  local tmp
  local la=0

  for config in "${_configs[@]}"; do
    tmp=$(printf '%s\n' "$config" | cut -d '.' -f2)
    say "  ${tmp^^}"
    if [[ -n "${set_confs[local_"$config"]}" ]]; then
      printf '    [local: %s]' "${set_confs[local_"$config"]}"
      la=1
    fi
    if [[ -n "${set_confs[global_"$config"]}" ]]; then
      if [[ "$la" == 1 ]]; then
        printf ', [global: %s]' "${set_confs[global_"$config"]}"
      else
        printf '    [global: %s]' "${set_confs[global_"$config"]}"
      fi
    fi
    printf '%s\n' ''
    la=0
  done
}

# Complain and exit if user tries to pass configuration options before the
# '--setup' flag
function validate_setup_opt()
{
  local option="$1"

  if [[ "${options_values['SETUP']}" == 0 ]]; then
    complain "The '$option' flag should only be used after the '--setup' flag."
    complain 'Please check your command and try again.'
    return 95 # ENOTSUP
  fi

  return 0
}

function parse_mail_options()
{
  local index
  local option
  local short_options='t,f,v,l,'
  local long_options='setup,local,global,force,verify,list,'

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
      --email | --name)
        validate_setup_opt "$1" || exit 95 # ENOTSUP
        option="$(str_remove_prefix "$1" '--')"
        index="user.$option"
        validate_email "$option" "$2" && options_values["$index"]="$2"
        shift 2
        ;;
      --smtpencryption)
        validate_setup_opt "$1" || exit 95 # ENOTSUP
        validate_encryption "$2"
        shift 2
        ;;
      --smtp*)
        validate_setup_opt "$1" || exit 95 # ENOTSUP
        option="$(str_remove_prefix "$1" '--')"
        index="sendemail.$option"
        validate_email "$option" "$2" && options_values["$index"]="$2"
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
    '  mail (-l | --list) - List the configurable options'
}
