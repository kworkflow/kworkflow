# This file handles the interactions with the email groups and contacts. Currently it

include "${KW_LIB_DIR}/lib/kw_config_loader.sh"
include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kw_string.sh"
include "${KW_LIB_DIR}/send_patch.sh"

# Hash containing user options
declare -gA options_values

# Mail group database tables
declare -g DATABASE_TABLE_GROUP='email_group'
declare -g DATABASE_TABLE_CONTACT='email_contact'
declare -g DATABASE_TABLE_CONTACT_GROUP='email_contact_group'

declare -Ag condition_array
declare -Ag updates_array

#shellcheck disable=SC2119
function manage_contacts_main()
{
  local flag
  local ret

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

  if [[ "${options_values['GROUP_CREATE']}" ]]; then
    create_email_group "${option_values['GROUP']}"

    if [[ "$?" -eq 0 ]]; then
      success "New group ${group_name} created successfully!"
    fi
  fi

  if [[ "${options_values['GROUP_REMOVE']}" ]]; then
    remove_email_group "${option_values['GROUP']}"

    if [[ "$?" -eq 0 ]]; then
      success "Group ${group_name} removed successfully!"
    fi
  fi

  if [[ -n "${options_values['GROUPS_RENAME']}" ]]; then
    rename_email_group "${options_values['GROUP']}" "${options_values['GROUPS_RENAME']}"

    if [[ "$?" -eq 0 ]]; then
      success "Group ${options_values['GROUP']} successfully renamed to ${options_values['GROUPS_RENAME']}"
    fi
  fi

  if [[ -n "${options_values['GROUPS_ADD']}" ]]; then
    add_email_contacts "${options_values['GROUPS_ADD']}" "${options_values['GROUP']}"

    if [[ "$?" -eq 0 ]]; then
      success 'Contacts added successfully!'
    fi
  fi

  return 0
}

# This function receives the name of a new group and then check for
# incidences in the database and validate the group name before creating
# the group.
#
# @group_name: The name of the group that will be created.
#
# Returns:
# returns 0 if successful, non-zero otherwise
function create_email_group()
{
  local group_name="$1"
  local values

  validate_group_name "$group_name"

  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi

  check_existent_group "$group_name"

  if [[ "$?" -ne 0 ]]; then
    warning 'This group already exists'
    return 22 # EINVAL
  fi

  create_group "$group_name"

  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi

  return 0
}

# This function creates a new kw mail group
#
# @group_name: The name of the group that will be created.
#
# Returns:
# returns 0 if successful, non-zero otherwise
function create_group()
{
  local group_name="$1"
  local sql_operation_result

  values="$(format_values_db 1 "$group_name")"

  sql_operation_result=$(insert_into "$DATABASE_TABLE_GROUP" '(name)' "$values" '' 'VERBOSE')
  ret="$?"

  if [[ "$ret" -eq 2 || "$ret" -eq 61 ]]; then
    complain "$sql_operation_result"
    return 22 # EINVAL
  elif [[ "$ret" -ne 0 ]]; then
    complain "($LINENO):" $'Error while inserting group into the database with command:\n' "${sql_operation_result}"
    return 22 # EINVAL
  fi

  return 0
}

# This function validate a given group name
#
# @group_name: the group name that will be checked
#
# Return:
# returns 0 if successful, 61 if group name is empty,
# 75 if size of the group name is over 50 characters
# and 22 if group name has invalid characters as:
# [!, @, #, $, %, ^, &, (, ), (' ), (" ) and +].
function validate_group_name()
{
  local group_name="$1"
  local name_length
  local has_special_character
  local ret

  if [[ -z "$group_name" ]]; then
    complain 'The group name is empty'
    return 61 # ENODATA
  fi

  name_length="$(str_length "$group_name")"

  if [[ "$name_length" -ge 50 ]]; then
    complain 'The group name must be less than 50 characters'
    return 75 # OVERFLOW
  fi

  str_has_special_characters "$group_name"

  if [[ "$?" -eq 0 ]]; then
    complain 'The group name must not contain special characters'
    return 22 #EINVAL
  fi

  return 0
}

# This function checks the existence of a given group
#
# @group_name: the group name that will be checked
#
# Return:
# returns group id if group exists, 0 if it doesn't
function check_existent_group()
{
  local group_name="$1"
  local group_id

  condition_array=(['name']="${group_name}")
  group_id="$(select_from "$DATABASE_TABLE_GROUP" 'id' '' 'condition_array')"

  if [[ -n "$group_id" ]]; then
    return "$group_id"
  fi

  return 0
}

# This function removes a given mail group and
# all of it's references in the data base. Also
# removes the contacts without group association
#
# @group_name: The name of the removed group
#
# Returns:
# returns 0 if successful, non-zero otherwise
function remove_email_group()
{
  local group_name="$1"

  check_existent_group "$group_name"

  if [[ "$?" -eq 0 ]]; then
    warning 'Error, this group does not exist'
    return 22 #EINVAL
  fi

  remove_group "$group_name"

  if [[ "$?" -ne 0 ]]; then
    return 22 #EINVAL
  fi

  return 0
}

# This function removes a given group from the database
#
# @group_name: Name of the group which the contacts will be removed
#
# Return:
# returns 0 if successful, non-zero otherwise
function remove_group()
{
  local group_name="$1"
  local sql_operation_result

  condition_array=(['name']="${group_name}")

  sql_operation_result=$(remove_from "$DATABASE_TABLE_GROUP" 'condition_array' '' '' 'VERBOSE')
  ret="$?"

  if [[ "$ret" -eq 2 || "$ret" -eq 61 ]]; then
    complain "$sql_operation_result"
    return 22 # EINVAL
  elif [[ "$ret" -ne 0 ]]; then
    complain $'Error while removing group from the database with command:\n'"${sql_operation_result}"
    return 22 # EINVAL
  fi

  return 0
}

# This function renames a given mail group after checking
# the parameters passed.
#
# @old_name: The actual name of the renamed group
# @new_name: The new name wich the group will be renamed
#
# Returns:
# returns 0 if successful, non-zero otherwise
function rename_email_group()
{
  local old_name="$1"
  local new_name="$2"
  local group_id

  if [[ -z "$old_name" ]]; then
    complain 'Error, group name is empty'
    return 61 # ENODATA
  fi

  check_existent_group "$old_name"

  if [[ "$?" -eq 0 ]]; then
    warning 'This group does not exist so it can not be renamed'
    return 22 # EINVAL
  fi

  validate_group_name "$new_name"

  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi

  rename_group "$old_name" "$new_name"

  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi

  return 0
}

# This function renames a given group from the database
#
# @old_name: Name of the group that will be renamed
# @new_name: New namw of the group
#
# Return:
# returns 0 if successful, non-zero otherwise
function rename_group()
{
  local old_name="$1"
  local new_name="$2"
  local sql_operation_result
  local ret

  condition_array=(['name']="${old_name}")
  updates_array=(['name']="${new_name}")

  sql_operation_result=$(update_into "$DATABASE_TABLE_GROUP" 'updates_array' '' 'condition_array' 'VERBOSE')
  ret="$?"

  if [[ "$ret" -eq 2 || "$ret" -eq 61 ]]; then
    complain "$sql_operation_result"
    return 22 # EINVAL
  elif [[ "$ret" -ne 0 ]]; then
    complain "($LINENO):" $'Error while removing group from the database with command:\n'"${sql_operation_result}"
    return 22 # EINVAL
  fi

  return 0
}

# This function add a new contact to a given kw mail group
#
# @contacts_string: The string with all the contacts informations
# @group_name: The name of the group which the contacts will be added.
#
# Returns:
# returns 0 if successful, non-zero otherwise
function add_email_contacts()
{
  local contacts_list="$1"
  local group_name="$2"
  local group_id
  declare -A _contacts_array

  if [[ -z "$contacts_list" ]]; then
    complain 'The contacts list is empty'
    return 61 # ENODATA
  fi

  if [[ -z "$group_name" ]]; then
    complain 'The group name is empty'
    return 61 # ENODATA
  fi

  check_existent_group "$group_name"
  group_id="$?"

  if [[ "$group_id" -eq 0 ]]; then
    complain 'Error, ubable to add contacts to unexistent group'
    return 22 # EINVAL
  fi

  split_contact_infos "$contacts_list" _contacts_array

  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi

  add_contacts _contacts_array

  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi

  add_contact_group _contacts_array "$group_id"

  if [[ "$?" -ne 0 ]]; then
    return 22 # EINVAL
  fi

  return 0
}

# This function split the columns in the given contact string passed
# as parameter and create an associative array with the infos.
#
# @contacts_list: An string formed as "CONTACT_NAME <CONTACT_EMAIL>, CONTACT_NAME <CONTACT_EMAIL>, ..."
# @contacts_array: An associative array formed as "<CONTACT_EMAIL>:<CONTACT_NAME>"
#
# Returns:
# returns 0 if successful, non-zero otherwise
function split_contact_infos()
{
  local contacts_list="$1"
  local -n contacts_array="$2"
  local contacts_infos_array
  local contact_info
  local ret
  local name
  local email
  local added_contacts=0

  readarray -t contacts_infos_array < <(awk -v RS=", " '{print}' <<< "$contacts_list")

  for contact_info in "${contacts_infos_array[@]}"; do
    if [[ -z "$contact_info" ]]; then
      continue
    fi

    check_infos_sintaxe "$contact_info"

    if [[ "$?" -ne 0 ]]; then
      return 22 #EINVAL
    fi

    email="$(cut --delimiter='<' --fields=2 <<< "$contact_info" | cut --delimiter='>' --fields=1)"
    name="$(cut --delimiter='<' --fields=1 <<< "$contact_info")"

    validate_contact_infos "$email" "$name"

    if [[ "$?" -ne 0 ]]; then
      return 22 #EINVAL
    fi

    contacts_array["$email"]="$name"
    ((added_contacts++))
  done

  if [[ "$added_contacts" -ne "${#contacts_array[@]}" ]]; then
    complain 'Error, Some of the contacts must have a repeated email'
    return 22 #EINVAL
  fi

  return 0
}

# This function validate if the string with the contact infos is valid
#
# @contact_info: The string with the contact info,
# formed as: "CONTACT_NAME <CONTACT_EMAIL>"
#
# Returns:
# returns 0 if successful, non-zero otherwise
function check_infos_sintaxe()
{
  local contact_info="$1"
  local lt_pos
  local lt_count
  local gt_pos
  local gt_count

  gt_count=$(str_count_char_repetition "$contact_info" '>')
  lt_count=$(str_count_char_repetition "$contact_info" '<')

  gt_pos=$(str_get_char_position "$contact_info" '>')
  lt_pos=$(str_get_char_position "$contact_info" '<')

  if [[ "$lt_count" -eq 0 ]]; then
    complain 'Syntax error in the contacts list, there is a missing "<" in some of the contacts <email>'
    return 22 #EINVAL
  elif [[ "$gt_count" -eq 0 ]]; then
    complain 'Syntax error in the contacts list, there is a missing ">" in some of the contacts <email>'
    return 22 #EINVAL
  elif [[ "$lt_pos" -gt "$gt_pos" ]]; then
    complain 'Syntax error in the contacts list, the contact info should be like: name <email>'
    return 22 #EINVAL
  elif [[ "$lt_count" -ne 1 ]]; then
    complain 'Syntax error in the contacts list, there is a remaining "<" in some of the contacts <email>'
    return 22 #EINVAL
  elif [[ "$gt_count" -ne 1 ]]; then
    complain 'Syntax error in the contacts list, there is a remaining ">" in some of the contacts <email>'
    return 22 #EINVAL
  fi

  return 0
}

# This function check if the contacts infos email and name are valid
#
# @email: The contact email
# @name: The contact name
#
# Returns:
# returns 0 if successful, non-zero otherwise
function validate_contact_infos()
{
  local email="$1"
  local name="$2"

  if [[ -z "$email" || -z "$name" ]]; then
    complain 'Error, Some of the contact names or emails must be empty'
    return 61 #EINVAL
  fi

  validate_email "$email"

  if [[ "$?" -ne 0 ]]; then
    return 22 #EINVAL
  fi

  return 0
}

# This function add a contact in the database
#
# @contacts_array: The contact name
#
# Returns:
# returns 0 if successful, non-zero otherwise
function add_contacts()
{
  local -n contacts_array="$1"
  local values
  local result
  local email
  local contact_id
  local contact_name
  local message
  local entries
  local existent_contact
  local sql_operation_result
  local ret

  for email in "${!contacts_array[@]}"; do
    condition_array=(["email"]="${email}")
    entries=$(concatenate_with_commas '"id"' '"name"')
    existent_contact=$(select_from "$DATABASE_TABLE_CONTACT" "$entries" "" "condition_array" '')

    IFS='|' read -r contact_id contact_name <<< "$existent_contact"

    if [[ -n "$contact_name" ]]; then
      if [[ "${contact_name}" != "${contacts_array["$email"]}" ]]; then
        message="The email '${email}' you provided is already associated with contact '${contact_name}'."
        message+=$'\n'
        message+="Use the existing contact name '${contact_name}' instead of renaming it to '${contacts_array["$email"]}'?"

        if [[ "$(ask_yN "$message")" =~ '0' ]]; then
          updates_array=(["name"]="${contacts_array["$email"]}")
          condition_array=(["id"]="${contact_id}")
          update_into "$DATABASE_TABLE_CONTACT" "updates_array" '' "condition_array"
          continue
        fi
        contacts_array["$email"]="$contact_name"
      fi
      continue
    fi

    values=$(format_values_db 2 "${contacts_array["$email"]}" "${email}")

    sql_operation_result=$(insert_into "$DATABASE_TABLE_CONTACT" '(name, email)' "$values" '' 'VERBOSE')
    ret="$?"

    if [[ "$ret" -eq 61 || "$ret" -eq 2 ]]; then
      complain "$sql_operation_result"
      return 22 # EINVAL
    elif [[ "$ret" -ne 0 ]]; then
      complain "($LINENO):" 'Error while trying to insert contact into the database with the command:\n'"${sql_operation_result}"
      return 22 # EINVAL
    fi

  done

  return 0
}

# This function add the association between the contacts
# and its group in the database
#
# @contacts_array: The contact name
# @group_id: The id of group which the contacts will be associated
#
# Returns:
# returns 0 if successful, non-zero otherwise
function add_contact_group()
{
  local -n contacts_array="$1"
  local group_id="$2"
  local values
  local email
  local contact_id
  local ctt_group_association
  local sql_operation_result
  local ret

  for email in "${!contacts_array[@]}"; do
    condition_array=(['email']="${email}")
    contact_id="$(select_from "$DATABASE_TABLE_CONTACT" 'id' '' 'condition_array')"
    values="$(format_values_db 2 "$contact_id" "$group_id")"

    condition_array=(['contact_id']="${contact_id}" ['group_id']="${group_id}")
    ctt_group_association="$(select_from "$DATABASE_TABLE_CONTACT_GROUP" 'contact_id, group_id' '' 'condition_array')"
    if [[ -n "$ctt_group_association" ]]; then
      continue
    fi

    sql_operation_result=$(insert_into "$DATABASE_TABLE_CONTACT_GROUP" '(contact_id, group_id)' "$values" '' 'VERBOSE')
    ret="$?"

    if [[ "$ret" -eq 2 || "$ret" -eq 61 ]]; then
      complain "$sql_operation_result"
      return 22 # EINVAL
    elif [[ "$ret" -ne 0 ]]; then
      complain "($LINENO):" $'Error while trying to insert contact group into the database with the command:\n'"${sql_operation_result}"
      return 22 # EINVAL
    fi

  done

  return 0
}

function parse_manage_contacts_options()
{
  local index
  local option
  local setup_token=0
  local patch_version=''
  local commit_count=''
  local short_options='c:,r:,a:,'
  local long_options='group-create:,group-remove:,group-rename:,group-add:,'
  local pass_option_to_send_email

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw manage-contacts' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  eval "set -- $options"

  options_values['GROUPS']=''
  options_values['GROUP']=''
  options_values['GROUP_CREATE']=''
  options_values['GROUP_REMOVE']=''
  options_values['GROUP_RENAME']=''
  options_values['GROUP_ADD']=''

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --group-create | -c)
        options_values['GROUP_CREATE']=1
        options_values['GROUP']="$2"
        shift 2
        ;;
      --group-remove | -r)
        options_values['GROUP_REMOVE']="$2"
        shift 2
        ;;
      --group-rename)
        options_values['GROUP_RENAME']="$2"
        shift 2
        ;;
      --group-add | -a)
        options_values['GROUP_ADD']="$2"
        shift 2
        ;;
      --)
        shift
        ;;
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

  printf '%s\n' 'kw manager:' \
    '  manage-contacts (-c | --group-create) [<name>] - create new group' \
    '  manage-contacts (-r | --group-remove) [<name>] - remove existing group' \
    '  manage-contacts --group-rename [<old_name>:<new_name>] - rename existent group' \
    '  manage-contacts --group-add "[<group_name>]:[<contact1_name>] <[<contact1_email>]>, [<contact2_name>] <[<contact2_email>]>, ..." - add contact to existent group'
}
