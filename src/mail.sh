# This file handles all the interactions with git send-email. Currently it
# provides functions to configure the options used by git send-email.

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
    fi
  done

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
# @scp:        Used to go through all scopes
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
  local scp
  local cmd

  flag=${flag:-'SILENT'}

  if [[ "${options_values['FORCE']}" == 0 ]]; then
    if [[ -n "${set_confs["$set_option"]}" ]]; then
      warning "The configuration $option is already set with the following value(s):"
      for scp in {'global','local'}; do
        if [[ -n "${set_confs["${scp}_$option"]}" ]]; then
          warning -n "  [$scp]: "
          printf '%s\n' "${set_confs["${scp}_$option"]}"
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

    if [[ "${essential_config_options[*]}" =~ "$option".* ]]; then
      set_confs["${scope}_$option"]="$value"
    fi
    if [[ "${optional_config_options[*]}" =~ "$option".* ]]; then
      set_confs["${scope}_$option"]="$value"
    fi
    i="$((i + 2))"
  done
}

function parse_mail_options()
{
  local index
  local option
  local short_options='t,f,'
  local long_options='setup,local,global,force,'

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
  options_values['SCOPE']='local'
  options_values['CMD_SCOPE']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --setup | -t)
        options_values['SETUP']=1
        shift
        ;;
      --email | --name)
        option="$(str_remove_prefix "$1" '--')"
        index="user.$option"
        validate_email "$option" "$2" && options_values["$index"]="$2"
        shift 2
        ;;
      --smtpencryption)
        validate_encryption "$2"
        shift 2
        ;;
      --smtp*)
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
    '  mail (-t | --setup) [--local | --global] [-f | --force] - Configure mailing functionality, choose at least one:' \
    '    --name <name>' \
    '    --email <email>' \
    '    --smtpuser <email>' \
    '    --smtpserver <domain>' \
    '    --smtpserverport <port>' \
    '    --smtpencryption <encryption>'
}
