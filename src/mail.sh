# This file handles all the interactions with git send-email. Currently it
# provides functions to configure the options used by git send-email.
# It's also able to verify if the configurations required to use git send-email
# are set.

include "$KW_LIB_DIR/kw_config_loader.sh"
include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/kw_string.sh"

# Hash containing user options
declare -gA options_values
declare -gA set_confs

# flag that indicates if smtpuser was set based on user.email
declare -g smtpuser_autoset=0

declare -ga essential_config_options=('user.name' 'user.email'
  'sendemail.smtpuser' 'sendemail.smtpserver' 'sendemail.smtpserverport')
declare -ga optional_config_options=('sendemail.smtpencryption' 'sendemail.smtppass')

declare -gr email_regex='[A-Za-z0-9_\.-]+@[A-Za-z0-9_-]+(\.[A-Za-z0-9]+)+'

#shellcheck disable=SC2119
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

  if [[ -n "${options_values['SEND']}" ]]; then
    mail_send
    return 0
  fi

  get_configs

  if [[ "${options_values['VERIFY']}" == 1 ]]; then
    mail_verify
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

  if [[ -n "${options_values['INTERACTIVE']}" ]]; then
    interactive_setup
    exit
  fi

  if [[ "${options_values['SETUP']}" == 1 ]]; then
    mail_setup
    exit
  fi

  return 0
}

# This function prepares the appropriate options to send patches using
# `git send-email`.
#
# @flag: Flag to control the behavior of 'cmd_manager'
#
# Return:
# returns 0 if successful, non-zero otherwise
function mail_send()
{
  local flag="$1"
  local opts="${mail_config[send_opts]}"
  local to_recipients="${options_values['TO']}"
  local cc_recipients="${options_values['CC']}"
  local dryrun="${options_values['SIMULATE']}"
  local commit_range="${options_values['COMMIT_RANGE']}"
  local version="${options_values['PATCH_VERSION']}"
  local extra_opts="${options_values['PASS_OPTION_TO_SEND_EMAIL']}"
  local private="${options_values['PRIVATE']}"
  local rfc="${options_values['RFC']}"
  local kernel_root
  local patch_count=0
  local cmd='git send-email'

  flag=${flag:-'SILENT'}

  [[ -n "$dryrun" ]] && cmd+=" $dryrun"

  if [[ -n "$to_recipients" ]]; then
    validate_email_list "$to_recipients" || exit_msg 'Please review your `--to` list.'
    cmd+=" --to=\"$to_recipients\""
  fi

  if [[ -n "$cc_recipients" ]]; then
    validate_email_list "$cc_recipients" || exit_msg 'Please review your `--cc` list.'
    cmd+=" --cc=\"$cc_recipients\""
  fi

  # Don't generate a cover letter when sending only one patch
  patch_count="$(pre_generate_patches "$commit_range" "$version")"
  if [[ "$patch_count" -eq 1 ]]; then
    opts="$(sed 's/--cover-letter//g' <<< "$opts")"
  fi

  kernel_root="$(find_kernel_root "$PWD")"
  # if inside a kernel repo use get_maintainer to populate recipients
  if [[ -z "$private" && -n "$kernel_root" ]]; then
    generate_kernel_recipients "$kernel_root"
    cmd+=" --to-cmd='bash ${KW_PLUGINS_DIR}/kw_mail/to_cc_cmd.sh ${KW_CACHE_DIR} to'"
    cmd+=" --cc-cmd='bash ${KW_PLUGINS_DIR}/kw_mail/to_cc_cmd.sh ${KW_CACHE_DIR} cc'"
  fi

  [[ -n "$opts" ]] && cmd+=" $opts"
  [[ -n "$private" ]] && cmd+=" $private"
  [[ -n "$rfc" ]] && cmd+=" $rfc"
  [[ -n "$extra_opts" ]] && cmd+=" $extra_opts"

  cmd_manager "$flag" "$cmd"
}

# Validates the recipient list given by the user to the options `--to` and
# `--cc` to make sure the all the recipients are valid.
#
# @raw: The list of email recipients to be validated
#
# Return:
# 22 if there are invalid entries; 0 otherwise
function validate_email_list()
{
  local raw="$1"
  local -a list
  local value
  local error=0

  IFS=',' read -ra list <<< "$raw"

  for value in "${list[@]}"; do
    if [[ ! "$value" =~ ${email_regex} ]]; then
      warning -n 'The given recipient: '
      printf '%s' "$value"
      warning ' does not contain a valid e-mail.'
      error=1
    fi
  done

  [[ "$error" == 1 ]] && return 22 # EINVAL
  return 0
}

# This function generates the patches beforehand, these are used to count the
# number of patches and later to generate the appropriate recipients
#
# @commit_range: The list of revisions used to generate the patches
# @version:      The version of the patches
#
# Returns:
# The count of how many patches were created
function pre_generate_patches()
{
  local commit_range="$1"
  local version="$2"
  local patch_cache="${KW_CACHE_DIR}/patches"
  local count=0

  if [[ -d "$patch_cache" && ! "$patch_cache" =~ ^(~|/|"$HOME")$ ]]; then
    rm -rf "$patch_cache"
  fi
  mkdir -p "$patch_cache"

  cmd_manager 'SILENT' "git format-patch --quiet --output-directory $patch_cache $version $commit_range"

  for patch_path in "${patch_cache}/"*; do
    if is_a_patch "$patch_path"; then
      ((count++))
    fi
  done

  printf '%s\n' "$count"
}

# This function generates the appropriate recipients for each patch and saves
# them in files to be read by the script passed to `git send-email`. This makes
# use of the `get_maintainer.pl` script to figure out the who should recieve
# each patch, and generates a union of all adresses to send the cover-letter to
# all relevant parties.
#
# @kernel_root:  The path to the root of the current kernel tree
#
# Returns:
# Nothing
function generate_kernel_recipients()
{
  local kernel_root="$1"
  local to=''
  local cc=''
  local to_list=''
  local cc_list=''
  local blocked="${mail_config[blocked_emails]}"
  local patch_cache="${KW_CACHE_DIR}/patches"
  local cover_letter_to="${patch_cache}/to/cover-letter"
  local cover_letter_cc="${patch_cache}/cc/cover-letter"
  local get_maintainer_cmd="perl ${kernel_root}/scripts/get_maintainer.pl"
  get_maintainer_cmd+=" --nogit --nogit-fallback --no-r --no-n --multiline"
  get_maintainer_cmd+=" --nokeywords --norolestats --remove-duplicates"

  mkdir -p "${patch_cache}/to/" "${patch_cache}/cc/"

  for patch_path in "${patch_cache}/"*; do
    if ! is_a_patch "$patch_path"; then
      continue
    fi
    patch="$(basename "$patch_path")"

    to="$(eval "$get_maintainer_cmd --no-l $patch_path")"
    cc="$(eval "$get_maintainer_cmd --no-m $patch_path")"

    if [[ -n "$blocked" ]]; then
      to="$(remove_blocked_recipients "$to" "$blocked")"
      cc="$(remove_blocked_recipients "$cc" "$blocked")"
    fi

    printf '%s\n' "$to" > "${patch_cache}/to/${patch}"
    printf '%s\n' "$to" >> "$cover_letter_to"
    printf '%s\n' "$cc" > "${patch_cache}/cc/${patch}"
    printf '%s\n' "$cc" >> "$cover_letter_cc"
  done

  to_list="$(sort -u "$cover_letter_to")"
  printf '%s\n' "$to_list" > "$cover_letter_to"

  cc_list="$(sort -u "$cover_letter_cc")"
  printf '%s\n' "$cc_list" > "$cover_letter_cc"
}

# This function filters out any unwanted recipients from the auto generated
# recipient lists
#
# @recipients: The list of recipients separated by new lines
# @blocked:    The list of blocked e-mails separated by commas
#
# Returns:
# The filtered recipients list
function remove_blocked_recipients()
{
  local recipients="$1"
  local blocked="$2"
  local -a blocked_arr=()

  [[ -z "$recipients" ]] && return 0 # Empty list

  IFS=',' read -ra blocked_arr <<< "$blocked"

  for value in "${blocked_arr[@]}"; do
    recipients="$(sed -E -e "/^(.+<)?${value}>?$/d" <<< "$recipients")"
  done

  printf '%s' "$recipients"
}

# This function checks if any of the arguments in @args is a valid commit
# reference
#
# @args: arguments to be processed
#
# Returns:
# 125 if nor inside git work tree;
# 0 if any of the arguments is a valid reference to a commit; 22 otherwise
function find_commit_references()
{
  local args="$*"
  local arg=''
  local parsed=''
  local commit_range=''

  [[ -z "$args" ]] && return 22 # EINVAL

  if ! is_inside_work_tree; then
    return 125 # ECANCELED
  fi

  #shellcheck disable=SC2086
  while read -r arg; do
    parsed="$(git rev-parse "$arg" 2> /dev/null)"
    while read -r rev; do
      # check if the argument is a valid reference to a commit-ish object
      if git rev-parse --verify --quiet --end-of-options "$rev^{commit}" > /dev/null; then
        commit_range+="$arg "
        continue 2
      fi
    done <<< "$parsed"
    parsed=''
  done <<< "$(git rev-parse -- $args 2> /dev/null)"

  if [[ -n "$commit_range" ]]; then
    printf '%s' "$(str_strip "$commit_range")"
    return 0
  fi

  return 22 # EINVAL
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
      if [[ "$option" == 'user.email' ]]; then
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
  warning 'Empty value defaults to plain smtp.'

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

  if [[ ! "$value" =~ ^${email_regex}$ ]]; then
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

# This function gets all the currently set values for the mail_config used
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
    complain -n 'You provided a flag that should only be used with '
    complain '`--setup`, `--template` or `--interactive`.'
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
    [[ -n "${options_values['INTERACTIVE']}" ]] && available_templates+=('skip template')
    available_templates+=('exit kw mail')

    say 'You may choose one of the following templates to start your configuration.'
    printf '(enter the corresponding number to choose)\n'
    select user_choice in "${available_templates[@]^}"; do
      [[ "$user_choice" =~ ^Skip ]] && return
      [[ "$user_choice" =~ ^Exit ]] && exit

      template="${user_choice,,}"
      break
    done
  fi

  load_template "$template"

  if [[ -z "${options_values['NO_INTERACTIVE']}" &&
    -z "${options_values['INTERACTIVE']}" ]]; then
    options_values['INTERACTIVE']='template'
  fi
}

# Loads the values from the template file to the options_values array
#
# @template: name of the template to be loaded
#
# Returns: 22 if template is not found
function load_template()
{
  local template="$1"
  local option
  local value
  local template_path

  template_path=$(join_path "$KW_ETC_DIR/mail_templates" "$template")

  if [[ ! -f "$template_path" ]]; then
    complain "Invalid template: $template"
    exit 22 # EINVAL
  fi

  while IFS='=' read -r option value; do
    # don't overwrite user given options
    if [[ -z "${options_values[$option]}" ]]; then
      options_values["$option"]="$value"
    fi
  done < "$template_path"
}

# This function prompts the user for the config values needed to setup the mail
# capabilities.
#
# @flag:       Flag to control the behavior of 'cmd_manager'
# @curr_scope: The scope being edited
# @cmd_scope:  The scope being imposed on the command
#
# Returns:
# 0 if successful; non-zero otherwise
function interactive_setup()
{
  local flag="$1"
  local curr_scope="${options_values['SCOPE']}"
  local cmd_scope="${options_values['CMD_SCOPE']}"
  local confs=0

  flag=${flag:-'SILENT'}

  if [[ "${options_values['INTERACTIVE']}" == 'parser' ]]; then
    success 'Welcome to the interactive setup of the mail capabilities.'$'\n'

    [[ "$(ask_yN 'Do you wish to list the currently set values?')" == '1' ]] && mail_list
    printf '\n'

    if [[ -z "${options_values['TEMPLATE']}" ]]; then
      template_setup
      printf '\n'
    fi

    say 'We will start with the essential configuration options!'$'\n'
  fi

  interactive_prompt 'essential_config_options'

  if [[ "${options_values['INTERACTIVE']}" != 'template' ]]; then
    say 'These are the optional configuration options.'$'\n'

    interactive_prompt 'optional_config_options' false
  fi

  for option in "${essential_config_options[@]}" "${optional_config_options[@]}"; do
    if [[ -n "${options_values["$option"]}" ]]; then
      add_config "$option" "${options_values["$option"]}" "$cmd_scope" "$flag"

      if [[ "$?" == 0 ]]; then
        success -n "  [$curr_scope] '$option' was set to: "
        printf '%s\n' "${options_values["$option"]}"
        confs=1
      fi
    fi
  done

  if [[ "$confs" == 0 ]]; then
    warning 'No configuration options were set.'
  fi

  return 0
}

# This function prompts the user for the config values needed to setup the mail
# capabilities and adds them to the options_values array
#
# @_config_options: reference to the array with the options to be prompted for
# @essential:       should we insist on setting the option
#
# Returns:
# Nothing
function interactive_prompt()
{
  local -n _config_options="$1"
  local essential="${2:-true}"
  local curr_scope="${options_values['SCOPE']}"
  local -A values
  local value
  local prompt

  for option in "${_config_options[@]}"; do
    config_values 'values' "$option"

    if [[ -z "${values['loaded']}" ||
      (-n "${values["$curr_scope"]}" && "${values['loaded']}" != "${values["$curr_scope"]}") ||
      ("$option" == 'sendemail.smtpuser' && "$smtpuser_autoset" == 1) ]]; then

      warning "[$curr_scope] Setup your ${option#*.}:"

      prompt="Enter new ${option#*.}"
      if [[ -n "${values["$curr_scope"]}" ]]; then
        prompt+=" [default: ${values["$curr_scope"]}]"
      elif [[ -n "${values['global']}" ]]; then
        prompt+=" [default: ${values['global']}]"
      fi

      while true; do
        if [[ "$option" == 'sendemail.smtpuser' && "$smtpuser_autoset" == 1 ]]; then
          warning "  kw will set this option to ${values['loaded']}"
          if [[ "$(ask_yN "  Do you want to change it?")" == 0 ]]; then
            printf '\n'
            break
          fi
          values['loaded']=''
        fi

        if [[ -z "${values['loaded']}" ]]; then
          read -r -p "  $prompt: " value

          if [[ -n "$value" && "$option" == 'user.email' ]]; then
            validate_email "$value" || continue
          fi

          if [[ -n "$value" && "$option" == 'sendemail.smtpencryption' ]]; then
            validate_encryption "$value" || continue
          fi

          values['loaded']="$value"
          [[ "$option" == 'sendemail.smtpuser' ]] && smtpuser_autoset=2 # manual
          printf '\n'
        fi

        if [[ -n "${values['loaded']}" && -n "${values["$curr_scope"]}" &&
          "${values['loaded']}" != "${values["$curr_scope"]}" ]]; then

          warning '  Proposed change:'
          warning -n "    [$curr_scope | $option]: "
          printf '%s' "${values["$curr_scope"]}"
          warning -n ' --> '
          printf '%s\n\n' "${values['loaded']}"

          if [[ "$(ask_yN 'Do you accept this change?')" == 0 ]]; then
            values['loaded']=''
            continue
          fi
        fi

        if [[ "$essential" == true ]]; then
          if [[ -z "${values['loaded']}" &&
            -z "${values['local']}" && -z "${values['global']}" ]]; then

            warning "You are about to skip an essential config ($option)"
            [[ "$(ask_yN '  Do you wish to proceed?')" == 0 ]] && continue

            complain "  Skipping $option..."$'\n'
          fi
        fi

        break
      done

      options_values["$option"]="${values['loaded']}"
      if [[ "$option" == 'user.email' && -n "${values['loaded']}" &&
        -z "${options_values['sendemail.smtpuser']}" ]]; then
        options_values['sendemail.smtpuser']="${values['loaded']}"
        smtpuser_autoset=1
      fi

      say "$SEPARATOR"$'\n'
    fi
  done
}

# This is used to reposition the a commit count argument meant for
# git-format-patch, this is needed to avoid problems with kw_parse
#
# Returns:
# A string with the options correctly positioned
function reposition_commit_count_arg()
{
  local options=''
  local commit_count=''
  local dash_dash=0

  while [[ "$#" -gt 0 ]]; do
    if [[ "$1" =~ ^-[[:digit:]]+$ ]]; then
      commit_count="$1"
      shift
      continue
    fi
    [[ "$1" =~ ^--$ ]] && dash_dash=1
    # The added quotes ensure arguments are correctly separated
    options="$options \"$1\""
    shift
  done

  if [[ -n "$commit_count" ]]; then
    # add `--` if not present
    [[ "$dash_dash" == 0 ]] && options="$options --"
    options="$options $commit_count"
  fi

  printf '%s' "$options"
}

function parse_mail_options()
{
  local index
  local option
  local setup_token=0
  local patch_version=''
  local commit_count=''
  local short_options='s,t,f,v:,i,l,n,'
  local long_options='send,simulate,to:,cc:,setup,local,global,force,verify,'
  long_options+='template::,interactive,no-interactive,list,private,rfc,'

  long_options+='email:,name:,'
  long_options+='smtpuser:,smtpencryption:,smtpserver:,smtpserverport:,smtppass:,'

  # This is a pre parser to handle commit count arguments
  options="$(reposition_commit_count_arg "$@")"
  eval "set -- $options"

  options="$(kw_parse "$short_options" "$long_options" "$@")"
  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw mail' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  eval "set -- $options"

  # Default values
  options_values['SEND']=''
  options_values['TO']=''
  options_values['CC']=''
  options_values['SIMULATE']=''
  options_values['SETUP']=0
  options_values['FORCE']=0
  options_values['VERIFY']=0
  options_values['TEMPLATE']=''
  options_values['INTERACTIVE']=''
  options_values['NO_INTERACTIVE']=''
  options_values['SCOPE']='local'
  options_values['CMD_SCOPE']=''
  options_values['PATCH_VERSION']=''
  options_values['PASS_OPTION_TO_SEND_EMAIL']=''
  options_values['RFC']=''
  options_values['COMMIT_RANGE']=''
  options_values['PRIVATE']=''

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --list | -l)
        mail_list
        exit
        ;;
      --send | -s)
        options_values['SEND']=1
        shift
        ;;
      --to)
        options_values['TO']="$2"
        shift 2
        ;;
      --cc)
        options_values['CC']="$2"
        shift 2
        ;;
      --simulate)
        options_values['SIMULATE']='--dry-run'
        shift
        ;;
      --setup | -t)
        options_values['SETUP']=1
        shift
        ;;
      --email)
        if [[ -z "${options_values['sendemail.smtpuser']}" ]]; then
          options_values['sendemail.smtpuser']="$2"
          smtpuser_autoset=1
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
        [[ "$option" == 'smtpuser' ]] && smtpuser_autoset=2 # manual
        shift 2
        ;;
      --template)
        option="$(str_strip "${2,,}")"
        options_values['SETUP']=1
        options_values['TEMPLATE']=":$option" # colon sets the option
        shift 2
        ;;
      --interactive | -i)
        options_values['SETUP']=1
        [[ -z "${options_values['NO_INTERACTIVE']}" ]] && options_values['INTERACTIVE']='parser'
        shift
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
      --private)
        options_values['PRIVATE']='--suppress-cc=all'
        shift
        ;;
      --verify)
        options_values['VERIFY']=1
        shift
        ;;
      --force | -f)
        options_values['FORCE']=1
        ;&
      --no-interactive | -n)
        options_values['INTERACTIVE']=''
        options_values['NO_INTERACTIVE']=1
        shift
        ;;
      --rfc)
        options_values['RFC']='--rfc'
        shift
        ;;
      -v)
        options_values['PATCH_VERSION']="$1$2"
        shift 2
        ;;
      --)
        shift
        # if a reference is passed after the -- we need to account for it
        if [[ "$*" =~ -[[:digit:]]+ ]]; then
          commit_count="${BASH_REMATCH[0]}"
          options_values['COMMIT_RANGE']+="$commit_count "
        fi
        options_values['PASS_OPTION_TO_SEND_EMAIL']="$(str_strip "$* ${options_values['PATCH_VERSION']}")"
        options_values['COMMIT_RANGE']+="$(find_commit_references "${options_values['PASS_OPTION_TO_SEND_EMAIL']}")"
        rev_ret="$?"
        shift "$#"
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

  # assume last commit if none given
  if [[ -z "${options_values['COMMIT_RANGE']}" && "$rev_ret" == 22 ]]; then
    options_values['COMMIT_RANGE']='@^'
    options_values['PASS_OPTION_TO_SEND_EMAIL']="$(str_strip "${options_values['PASS_OPTION_TO_SEND_EMAIL']} @^")"
  fi

  return 0
}

function mail_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'mail'
    exit
  fi
  printf '%s\n' 'kw mail:' \
    '  mail (-s | --send) [<options>] - Send patches via e-mail' \
    '  mail (-t | --setup) [--local | --global] [-f | --force] (<config> <value>)...' \
    '  mail (-i | --interactive) - Setup interactively' \
    '  mail (-l | --list) - List the configurable options' \
    '  mail --verify - Check if required configurations are set' \
    '  mail --template[=<template>] [-n] - Set send-email configs based on <template>'
}

load_mail_config
