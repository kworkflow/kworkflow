include "$KW_LIB_DIR/kwlib.sh"
include "${KW_LIB_DIR}/lib/remote.sh"

declare -gA options_values
declare -g local_remote_config_file="${PWD}/.kw/remote.config"
declare -g global_remote_config_file="${KW_ETC_DIR}/remote.config"

function remote_main()
{
  if [[ "$1" =~ -h|--help ]]; then
    remote_help "$1"
    exit 0
  fi

  parse_remote_options "$@"
  if [[ "$?" != 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  if [[ -n "${options_values['LIST']}" ]]; then
    list_remotes
    return "$?"
  fi

  if [[ -n "${options_values['ADD']}" ]]; then
    add_new_remote
    return "$?"
  fi

  if [[ -n "${options_values['DEFAULT_REMOTE']}" ]]; then
    set_default_remote
    return "$?"
  fi

  if [[ -n "${options_values['REMOVE']}" ]]; then
    remove_remote
    return "$?"
  fi

  if [[ -n "${options_values['RENAME']}" ]]; then
    rename_remote
    return "$?"
  fi
}

# Returns the local or global remote.config location.
# The local has precedence.
#
# Returns:
# The remote config file if found and 22 otherwise.
function choose_correct_remote_config_file()
{
  local has_local_config='false'
  local has_global_config='false'

  if [[ -d "${PWD}/.kw" ]]; then
    has_local_config='true'
  fi

  if [[ -d "${KW_ETC_DIR}" ]]; then
    has_global_config='true'
  fi

  if [[ "${has_local_config}" == 'true' && -z "${options_values['GLOBAL']}" ]]; then
    printf '%s' "${local_remote_config_file}"
  elif [[ "${has_global_config}" == 'true' ]]; then
    printf '%s' "${global_remote_config_file}"
  else
    return 22 # EINVAL
  fi
}

function list_remotes()
{
  local remote_config
  local str_process
  local remote_config_file
  local ret

  remote_config_file="$(choose_correct_remote_config_file)"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain 'No local or global config found. Please reinstall kw or run "kw init" to create a .kw in this dir.'
    return "$ret"
  fi

  if [[ ! -f "$remote_config_file" ]]; then
    # If we don't have a remote.config file yet, let the user know
    if [[ "$remote_config_file" == "$local_remote_config_file" ]]; then
      complain 'Did you run kw init? It looks like that you do not have remote.config.'
      return 22 # EINVAL
    fi
    if [[ "$remote_config_file" == "$global_remote_config_file" ]]; then
      complain 'Did you install kw correctely? It looks like that you do not have a global remote.config.'
      return 22 # EINVAL
    fi
  fi

  remote_config=$(< "${remote_config_file}")

  while read -r line; do
    grep --quiet "^#kw-default=" <<< "$line"
    if [[ "$?" == 0 ]]; then
      str_process=$(cut -d '=' -f2 <<< "$line")
      say "Default Remote: ${str_process}"
      continue
    fi

    grep --quiet '^Host ' <<< "$line"
    if [[ "$?" == 0 ]]; then
      str_process=$(cut -d ' ' -f2 <<< "$line")
      success "$str_process"
      continue
    fi

    printf '%s%s\n' '- ' "$line"
  done <<< "$remote_config"
}

function add_new_remote()
{
  local name
  local remote
  local first_time=''
  local host_ssh_config
  local user_ssh_config
  local port_ssh_config
  local remote_config_file

  remote_config_file="$(choose_correct_remote_config_file)"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain 'No local or global config found. Please reinstall kw or run "kw init" to create a .kw in this dir.'
    return "$ret"
  fi

  read -ra add_parameters <<< "${options_values['PARAMETERS']}"

  # We expect at exact two parameters
  if [[ "${#add_parameters[*]}" != 2 ]]; then
    complain 'Expected: add <name-without-space> <[user@]ip[:port]>'
    exit 22 # EINVAL
  fi

  name=${add_parameters[0]}
  remote=${add_parameters[1]}

  populate_remote_info "$remote"
  if [[ "$?" == 22 ]]; then
    complain 'Expected: <[user@]ip[:port]>'
    exit 22 # EINVAL
  fi

  # If we don't have a remote.config file yet, let's create it
  if [[ ! -f "${remote_config_file}" ]]; then
    if [[ ! -d "${PWD}/.kw" ]]; then
      complain 'Did you run kw init? It looks like that you do not have the .kw folder'
      exit 22 # EINVAL
    fi
    touch "$remote_config_file"
    first_time='yes'
  fi

  remote="${remote_parameters['REMOTE_USER']}@${remote_parameters['REMOTE_IP']}"
  remote+=":${remote_parameters['REMOTE_PORT']}"

  # Check if remote name already exists
  grep --line-regexp --quiet "^Host ${name}$" "$remote_config_file"
  if [[ "$?" == 0 ]]; then
    sed --in-place --regexp-extended "/^Host ${name}$/{n;s/Hostname.*/Hostname ${remote_parameters['REMOTE_IP']}/}" "$remote_config_file"
    sed --in-place --regexp-extended "/^Host ${name}$/{n;n;s/Port.*/Port ${remote_parameters['REMOTE_PORT']}/}" "$remote_config_file"
    sed --in-place --regexp-extended "/^Host ${name}$/{n;n;n;s/User.*/User ${remote_parameters['REMOTE_USER']}/}" "$remote_config_file"
    return
  fi

  # New entry
  {
    [[ -n "$first_time" ]] && printf '#kw-default=%s\n' "$name"
    printf 'Host %s\n' "$name"
    printf '  Hostname %s\n' "${remote_parameters['REMOTE_IP']}"
    printf '  Port %s\n' "${remote_parameters['REMOTE_PORT']}"
    printf '  User %s\n' "${remote_parameters['REMOTE_USER']}"
  } >> "$remote_config_file"

  # Check if user request to set this new entry as default
  if [[ -z "$first_time" && "${options_values['DEFAULT_REMOTE_USED']}" -eq 1 ]]; then
    options_values['DEFAULT_REMOTE']="$name"
    set_default_remote
  fi
}

function set_default_remote()
{
  local default_remote="${options_values['DEFAULT_REMOTE']}"
  local remote_config_file

  remote_config_file="$(choose_correct_remote_config_file)"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain 'No local or global config found. Please reinstall kw or run "kw init" to create a .kw in this dir.'
    return "$ret"
  fi

  grep --line-regexp --quiet "^#kw-default=.*" "$remote_config_file"
  # We don't have the default header yet, let's add it
  if [[ "$?" != 0 ]]; then
    sed --in-place "1s/^/#kw-default=${default_remote}\n/" "$remote_config_file"
    return "$?"
  fi

  grep --line-regexp --quiet "^Host ${default_remote}$" "$remote_config_file"
  # We don't have the default header yet, let's add it
  if [[ "$?" != 0 ]]; then
    complain "We could not find '${default_remote}'. Is this a valid remote?"
    return 22 # EINVAL
  fi

  # We already have the default remote
  sed --in-place --regexp-extended "s/^#kw-default=.*/#kw-default=${default_remote}/" "$remote_config_file"
}

function remove_remote()
{
  local target_remote
  local remote_config_file

  remote_config_file="$(choose_correct_remote_config_file)"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain 'No local or global config found. Please reinstall kw or run "kw init" to create a .kw in this dir.'
    return "$ret"
  fi

  read -ra remove_parameters <<< "${options_values['PARAMETERS']}"

  # We expect at exact two parameters
  if [[ "${#remove_parameters[*]}" != 1 ]]; then
    complain 'Expected: remove <name-without-space>'
    exit 22 # EINVAL
  fi

  target_remote="${remove_parameters[0]}"

  # Check if remote name exists
  grep --line-regexp --quiet "^Host ${target_remote}$" "$remote_config_file"
  if [[ "$?" == 0 ]]; then
    grep --line-regexp --quiet "^#kw-default=${target_remote}" "$remote_config_file"
    # Check if the target remote is the default
    if [[ "$?" == 0 ]]; then
      warning "'${target_remote}' was the default remote, please, set a new default"
      sed --in-place "/^#kw-default=${target_remote}/d" "$remote_config_file"
    fi

    sed --in-place --regexp-extended "/^Host ${target_remote}$/{n;/Hostname.*/d}" "$remote_config_file"
    sed --in-place --regexp-extended "/^Host ${target_remote}$/{n;/Port.*/d}" "$remote_config_file"
    sed --in-place --regexp-extended "/^Host ${target_remote}$/{n;/User.*/d}" "$remote_config_file"
    sed --in-place --regexp-extended "/^Host ${target_remote}$/d" "$remote_config_file"
    sed --in-place --regexp-extended '/^$/d' "$remote_config_file"
  else
    complain "We could not find ${target_remote}"
    return 22 # EINVAL
  fi
}

function rename_remote()
{
  local old_name
  local new_name
  local remote_config_file

  remote_config_file="$(choose_correct_remote_config_file)"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain 'No local or global config found. Please reinstall kw or run "kw init" to create a .kw in this dir.'
    return "$ret"
  fi

  read -ra rename_parameters <<< "${options_values['PARAMETERS']}"

  # We expect at exact two parameters
  if [[ "${#rename_parameters[*]}" != 2 ]]; then
    complain 'Expected: rename <OLD-name-without-space> <NEW-name-without-space>'
    exit 22 # EINVAL
  fi

  old_name=${rename_parameters[0]}
  new_name=${rename_parameters[1]}

  # If we don't have a remote.config file yet, let's create it
  if [[ ! -f "${remote_config_file}" ]]; then
    if [[ ! -d "${PWD}/.kw" ]]; then
      complain 'Did you run kw init? It looks like that you do not have the .kw folder'
      exit 22 # EINVAL
    fi
  fi

  # Check if new name already exists
  grep --line-regexp --quiet "^Host ${new_name}$" "$remote_config_file"
  if [[ "$?" == 0 ]]; then
    complain "It looks like that '${new_name}' already exists"
    complain "Please, choose another name or remove '${old_name}' first"
    return 22 # EINVAL
  fi

  # Check if remote name already exists
  grep --line-regexp --quiet "^Host ${old_name}$" "$remote_config_file"
  if [[ "$?" == 0 ]]; then
    sed --in-place --regexp-extended "s/^Host $old_name/Host $new_name/" "$remote_config_file"

    # Check if the target remote was marked as a default
    grep --line-regexp --quiet "^#kw-default=${old_name}$" "$remote_config_file"
    if [[ "$?" == 0 ]]; then
      options_values['DEFAULT_REMOTE']="$new_name"
      set_default_remote
    fi

    return
  else
    complain "It looks like that ${old_name} does not exists"
    return 22 # EINVAL
  fi
}

function parse_remote_options()
{
  local long_options='add,remove,rename,verbose,list,set-default::,global::'
  local short_options='v,s::'
  local default_option

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw remote' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['ADD']=''
  options_values['REMOVE']=''
  options_values['RENAME']=''
  options_values['VERBOSE']=''
  options_values['PARAMETERS']=''
  options_values['DEFAULT_REMOTE']=''
  options_values['DEFAULT_REMOTE_USED']=''
  options_values['LIST']=''
  options_values['GLOBAL']=''

  remote_parameters['REMOTE_IP']=''
  remote_parameters['REMOTE_PORT']=''
  remote_parameters['REMOTE_USER']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --help | -h)
        remote_help "$1"
        exit
        ;;
      add)
        options_values['ADD']=1
        shift
        ;;
      remove)
        options_values['REMOVE']=1
        shift
        ;;
      rename)
        options_values['RENAME']=1
        shift
        ;;
      --list)
        options_values['LIST']=1
        shift
        ;;
      --global)
        options_values['GLOBAL']=1
        shift
        ;;
      --set-default | -s)
        default_option="$(str_strip "$2")"
        # set-default can be used in combination with add
        [[ -n "$default_option" ]] && options_values['DEFAULT_REMOTE']="$default_option"
        options_values['DEFAULT_REMOTE_USED']=1
        shift 2
        ;;
      --verbose | -v)
        echo "VERBOSE"
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

  if [[ -n "${options_values['ADD']}" && -n "${options_values['DEFAULT_REMOTE']}" ]]; then
    complain 'Please, do not try to set a different default value from the one you are adding now.'
    complain 'With add option, we only accept --set-default'
    return 22 # EINVAL
  elif [[ "${options_values['DEFAULT_REMOTE']}" == 1 ]]; then
    options_values['ERROR']='Expected a string values after --set-default='
    return 22
  elif [[ -z "${options_values['ADD']}" && -z "${options_values['REMOVE']}" &&
    -z "${options_values['RENAME']}" && -z "${options_values['LIST']}" &&
    -z "${options_values['DEFAULT_REMOTE']}" ]]; then
    options_values['ERROR']='"kw remote" should be proceeded by valid option'$'\n'
    options_values['ERROR']+='Usage: kw remote (add | remove | rename | --list | --set-default) <params>[...]'
    return 22 # EINVAL
  fi
}

function remote_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'remote'
    return
  fi
  printf '%s\n' 'kw remote:' \
    '  remote - handle remote options' \
    '  remote add [--global] <name> <USER@IP:PORT> [--set-default] - Add new remote' \
    '  remote remove [--global] <name> - Remove remote' \
    '  remote rename [--global] <old> <new> - Rename remote' \
    '  remote [--global] --set-default=<remonte-name> - Set default remote' \
    '  remote [--global] --list - List remotes' \
    '  remote [--global] (--verbose | -v) - be verbose'
}
