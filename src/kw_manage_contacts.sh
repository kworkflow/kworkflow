# This file handles the interactions with the email groups and contacts. Currently it

include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"

# Hash containing user options
declare -gA options_values

# Mail group database tables
declare -g DATABASE_TABLE_GROUP='email_group'
declare -g DATABASE_TABLE_CONTACT='email_contact'
declare -g DATABASE_TABLE_CONTACT_GROUP='email_contact_group'

declare -Ag condition_array

#shellcheck disable=SC2119
function manage_contacts_main()
{
  local flag

  flag=${flag:-'SILENT'}

  if [[ "$1" =~ -h|--help ]]; then
    manage_contacts_help "$1"
    exit 0
  fi

  parse_manage_contacts_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    manage_contacts_help
    return 22 # EINVAL
  fi

  return 0
}

function parse_manage_contacts_options()
{
  local index
  local option
  local setup_token=0
  local patch_version=''
  local commit_count=''
  local short_options=''
  local long_options=''
  local pass_option_to_send_email

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw manage-contacts' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
    esac
  done

  return 0
}

function manage_contacts_help()
{
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'manage-contacts'
    exit
  fi
  printf '%s\n' 'kw manage-contacts:'
}
