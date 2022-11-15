# The init.sh keep all the operations related to the `kworkflow.config`
# initialization. The initialization feature it is inspired on `git init`.

include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/remote.sh"

KW_DIR='.kw'

declare -gA options_values

# This function is responsible for creating a local kworkflow.config based in a
# template available in the etc directory.
#
# Returns:
# In case of failure, this function returns ENOENT.
function init_kw()
{
  local config_template_folder="${KW_ETC_DIR}/init_templates"
  local name='kworkflow.config'
  local build_name='build.config'
  local deploy_name='deploy.config'
  local mail_name='mail.config'
  local notification_name='notification.config'
  local remote_name='remote.config'
  local config_file_template
  local deploy_config_file_template
  local remote_file_template
  local ret

  if [[ "$1" =~ -h|--help ]]; then
    init_help "$1"
    exit 0
  fi

  if ! is_kernel_root "$PWD"; then
    warning 'This command should be run in a kernel tree.'
    if [[ $(ask_yN 'Do you want to continue?') =~ '0' ]]; then
      exit 125 # ECANCELED
    fi
  fi

  parse_init_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  config_file_already_exist_question

  if [[ -n "${options_values['TEMPLATE']}" ]]; then
    get_template_name ''
    ret="$?"
    if [[ "$?" != 0 ]]; then
      complain 'Invalid template, try: kw init --template'
      return "$ret"
    fi
  else
    options_values['TEMPLATE']='x86-64'
  fi

  config_file_template="${config_template_folder}/${options_values['TEMPLATE']}/kworkflow_template.config"
  build_config_file_template="${config_template_folder}/${options_values['TEMPLATE']}/build_template.config"
  deploy_config_file_template="${config_template_folder}/${options_values['TEMPLATE']}/deploy.config"
  mail_config_file_template="${KW_ETC_DIR}/mail.config"
  notification_config_file_template="${KW_ETC_DIR}/notification_template.config"
  remote_file_template="${KW_ETC_DIR}/remote.config"

  if [[ -f "$config_file_template" && -f "$build_config_file_template" ]]; then
    mkdir -p "$PWD/$KW_DIR"
    cp "$config_file_template" "$PWD/$KW_DIR/$name"
    cp "$build_config_file_template" "${PWD}/${KW_DIR}/${build_name}"
    cp "$deploy_config_file_template" "${PWD}/${KW_DIR}/${deploy_name}"
    cp "$mail_config_file_template" "${PWD}/${KW_DIR}/${mail_name}"
    cp "$notification_config_file_template" "${PWD}/${KW_DIR}/${notification_name}"
    cp "$remote_file_template" "${PWD}/${KW_DIR}/${remote_name}"

    sed -i -e "s,SOUNDPATH,$KW_SOUND_DIR,g" -e '/^#?.*/d' "$PWD/$KW_DIR/${notification_name}"

    if [[ -n "${options_values['ARCH']}" ]]; then
      if [[ -d "$PWD/arch/${options_values['ARCH']}" || -n "${options_values['FORCE']}" ]]; then
        set_config_value 'arch' "${options_values['ARCH']}" "${PWD}/${KW_DIR}/${build_name}"
      elif [[ -z "${options_values['FORCE']}" ]]; then
        complain 'This arch was not found in the arch directory'
        complain 'You can use --force next time if you want to proceed anyway'
        say 'Available architectures:'
        find "$PWD/arch" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort -d
      fi
    fi

    if [[ -n "${options_values['REMOTE']}" ]]; then
      populate_remote_info "${options_values['REMOTE']}"
      if [[ "$?" == 22 ]]; then
        complain 'Invalid remote:' "${options_values['REMOTE']}"
        exit 22 # EINVAL
      else
        set_config_value 'ssh_user' "${remote_parameters['REMOTE_USER']}"
        set_config_value 'ssh_ip' "${remote_parameters['REMOTE_IP']}"
        set_config_value 'ssh_port' "${remote_parameters['REMOTE_PORT']}"
      fi
    fi

    if [[ -n "${options_values['TARGET']}" ]]; then
      case "${options_values['TARGET']}" in
        local | remote)
          set_config_value 'default_deploy_target' "${options_values['TARGET']}" \
            "${PWD}/${KW_DIR}/${deploy_name}"
          ;;
        *)
          complain 'Target can only be local or remote.'
          ;;
      esac
    fi

  else
    complain "No such: $config_file_template"
    exit 2 # ENOENT
  fi

  say "Initialized kworkflow directory in $PWD/$KW_DIR based on $USER data"
}

# This function sets variables in the config file to a specified value.
#
# @option: option name in kw config file
# @value: value to set option to
function set_config_value()
{
  local option="$1"
  local value="$2"
  local path="${3:-"$PWD/$KW_DIR/$name"}"

  sed -i -r "s/($option=).*/\1$value/" "$path"
}

function config_file_already_exist_question()
{
  local name='kworkflow.config'

  if [[ -f "$PWD/$KW_DIR/$name" ]]; then
    if [[ -n "${options_values['FORCE']}" ||
      $(ask_yN 'It looks like you already have a kw config file. Do you want to overwrite it?') =~ '1' ]]; then
      mv "$PWD/$KW_DIR/$name" '/tmp'
    else
      say 'Initialization aborted!'
      exit 0
    fi
  fi
}

# This function is responsible for returning the target template name. If the
# user does not provide any template in advance, this function asks which
# template to select.
#
# @_target_template: The variable reference used to save the template name
function get_template_name()
{
  local test_mode="$1"
  local template="${options_values['TEMPLATE']:1}" # removes colon
  local templates_path="$KW_ETC_DIR/init_templates"

  if [[ -z "$template" ]]; then
    mapfile -t available_templates < <(find "$templates_path" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
    available_templates+=('exit kw init templates')
    say 'You may choose one of the following templates to start your configuration.'
    printf '(enter the corresponding number to choose)\n'
    select user_choice in "${available_templates[@]^}"; do
      [[ "$user_choice" =~ ^Skip ]] && return
      [[ "$user_choice" =~ ^Exit ]] && exit

      template="${user_choice,,}"
      break
    done
  fi

  # Check if the template exist
  if [[ ! -d "${templates_path}/${template}" ]]; then
    return 2 # ENOENT
  fi

  options_values['TEMPLATE']="$template"

  # TODO:
  # Every time we use pipe in bash, it creates a subshell; as a result,
  # global variables are not visible outside the pipe command. This situation
  # creates a small problem for testing interactive functions like this one,
  # and we need to workaround this issue by printing the result that we want to
  # check in the terminal. In a few words, this code only exists for enabling
  # us to test this function; I'm not sure if we have a more elegant way to
  # approach this problem, but it would be nice if someone could help with
  # that.
  [[ -n "$test_mode" ]] && printf '\n%s\n' "${options_values['TEMPLATE']}"

  return 0
}

function parse_init_options()
{
  local long_options='arch:,remote:,target:,force,template::'
  local short_options='a:,r:,t:,f'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw init' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['ARCH']=''
  options_values['FORCE']=''
  options_values['TEMPLATE']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --arch | -a)
        options_values['ARCH']+="$2"
        shift 2
        ;;
      --remote | -r)
        options_values['REMOTE']+="$2"
        shift 2
        ;;
      --target | -t)
        shift
        options_values['TARGET']="$1"
        shift
        ;;
      --force | -f)
        shift
        options_values['FORCE']=1
        ;;
      --template)
        option="$(str_strip "${2,,}")"
        options_values['TEMPLATE']=":$option" # colon sets the option
        shift 2
        ;;
      --)
        shift
        ;;
      *)
        options_values['ERROR']="Unrecognized argument: $1"
        return 22 # EINVAL
        shift
        ;;
    esac
  done
}

function init_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'init'
    return
  fi
  printf '%s\n' 'kw init:' \
    '  init - Creates a kworkflow.config file in the current directory.' \
    '  init --template[=name] - Create kw config file from template.' \
    '  init --arch <arch> - Set the arch field in the kworkflow.config file.' \
    '  init --remote <user>@<ip>:<port> - Set remote fields in the kworkflow.config file.' \
    '  init --target <target> Set the default_deploy_target field in the kworkflow.config file'
}

# Every time build.sh is loaded its proper configuration has to be loaded as well
load_kworkflow_config
