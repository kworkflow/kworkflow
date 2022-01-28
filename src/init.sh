# The init.sh keep all the operations related to the `kworkflow.config`
# initialization. The initialization feature it is inspired on `git init`.

include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"
include "$KW_LIB_DIR/remote.sh"
include "$KW_LIB_DIR/kw_string.sh"

KW_DIR='.kw'

declare -gA options_values

# This function is responsible for creating a local kworkflow.config based in a
# template available in the etc directory.
#
# Returns:
# In case of failure, this function returns ENOENT.
function init_kw()
{
  local config_file_template="$KW_ETC_DIR/kworkflow_template.config"
  local name='kworkflow.config'

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

  if [[ -n "${options_values['GUIDED-SETUP']}" ]]; then
    guided_init
    exit 0
  fi

  if [[ -f "$PWD/$KW_DIR/$name" ]]; then
    if [[ -n "${options_values['FORCE']}" ||
      $(ask_yN 'It looks like you already have a kw config file. Do you want to overwrite it?') =~ '1' ]]; then
      mv "$PWD/$KW_DIR/$name" "$PWD/$KW_DIR/$name.old"
    else
      say 'Initialization aborted!'
      exit 0
    fi
  fi

  if [[ -f "$config_file_template" ]]; then
    mkdir -p "$PWD/$KW_DIR"
    cp "$config_file_template" "$PWD/$KW_DIR/$name"
    sed -i -e "s/USERKW/$USER/g" -e "s,SOUNDPATH,$KW_SOUND_DIR,g" -e '/^#?.*/d' \
      "$PWD/$KW_DIR/$name"

    if [[ -n "${options_values['ARCH']}" ]]; then
      if [[ -d "$PWD/arch/${options_values['ARCH']}" || -n "${options_values['FORCE']}" ]]; then
        set_config_value 'arch' "${options_values['ARCH']}"
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
        vm | local | remote)
          set_config_value 'default_deploy_target' "${options_values['TARGET']}"
          ;;
        *)
          complain 'Target can only be vm, local or remote.'
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
  local path="$3"

  path=${path:-"$PWD/$KW_DIR/$name"}

  sed -i -r "s/($option=).*/\1$value/" "$path"
}

function parse_init_options()
{
  local long_options='arch:,remote:,target:,force,guided-setup'
  local short_options='a:,r:,t:,f,g'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw init' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['ARCH']=''
  options_values['FORCE']=''
  options_values['GUIDED-SETUP']=''

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
      --guided-setup | -g)
        options_values['GUIDED-SETUP']=1
        shift
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
    '  init --arch <arch> - Set the arch field in the kworkflow.config file.' \
    '  init --remote <user>@<ip>:<port> - Set remote fields in the kworkflow.config file.' \
    '  init --target <target> - Set the default_deploy_target field in the kworkflow.config file' \
    '  init --guided-setup - Perform first time setup in an interactive manner. Recommended for new users.'
}

# This function gets four configuration values from git: name, email,
# editor, and initial branch name and stores them inside an associative array
# for future access. Checks if these values are empty and store this information
# in a boolean variable inside the array.
#
# @_git_config: associative array received as a nameref attribute to store all
#              values acquired in this function.
#
# Returns: _git_config[configured]: 1, if there is any revelant information in
#          git missing, and 0, if git is fully configured.
function get_git_config()
{
  local -n _git_config="$1"

  _git_config['name']=$(git config user.name)
  _git_config['email']=$(git config user.email)
  _git_config['editor']=$(git config core.editor)
  _git_config['branch']=$(git config init.defaultBranch)

  _git_config['configured']=0

  if [[ -z "${_git_config['name']}" ||
    -z "${_git_config['email']}" ||
    -z "${_git_config['editor']}" ||
    -z "${_git_config['branch']}" ]]; then
    _git_config['configured']=1
  fi
}

# This function sets if the scope of the git configuration will be
# local or global.
#
# @config_cmd: command in which will be added the configuration scope.
#
# Returns: the git config command, adjusted if the scope is local or global
function set_git_config_scope()
{
  local command
  local scope

  command='git config'

  if ! is_inside_work_tree; then
    warning 'You are not in a git repository. All modifications will be global' 1>&2
    if [[ $(ask_yN 'Would you like to proceed?' 'y') =~ '1' ]]; then
      command+=' --global'
    else
      command=''
    fi

    printf '%s\n' "$command"
    exit 0
  fi

  printf '\nSelect the scope of this configuration:\n' 1>&2

  select scope in 'Local' 'Global'; do
    case "$scope" in
      'Global')
        command+=' --global'
        break
        ;;
      'Local')
        command+=' --local'
        break
        ;;
    esac
  done

  printf '%s\n' "$command"
}

# Allows the user to set the empty configurations if any.
#
# @_config_git: associative array with data about git configuration.
# @flag: flag sended to the cmd_manager to change its behaviour.
#
# Returns: _config_git: array with the selected information configured on git
function interactive_set_user_git_info()
{
  local -n _config_git="$1"
  local flag="$2"
  local git_editor_suggestion
  local config_cmd
  local scope

  flag=${flag:-'SILENT'}

  if [[ "${_config_git['configured']}" == '0' ]]; then
    exit 0
  fi

  printf '\nNow Git will be configured.\n' 1>&2

  config_cmd=$(set_git_config_scope)
  if [[ -z "$config_cmd" ]]; then
    return
  fi

  if [[ -z "${_config_git['name']}" ]]; then
    _config_git['name']=$(ask_with_default 'What is your name?' "$USER")
    cmd_manager "$flag" "$config_cmd user.name \"${_config_git['name']}\""
  fi

  if [[ -z "${_config_git['email']}" ]]; then
    while :; do
      _config_git['email']=$(ask_with_default 'What is your email?' '')

      if validate_email "${_config_git['email']}"; then
        break
      fi

      printf 'It was not possible to validate your e-mail, please try again.\n' 1>&2
    done
    cmd_manager "$flag" "$config_cmd user.email \"${_config_git['email']}\""
  fi

  if [[ -z "${_config_git['editor']}" ]]; then
    if [[ $(ask_yN $'\nWould you like to configure your default editor on Git?' 'y') == '1' ]]; then

      # This follows git precedence to determine used editor
      git_editor_suggestion='vi'
      [[ -n "$EDITOR" ]] && git_editor_suggestion="$EDITOR"
      [[ -n "$VISUAL" ]] && git_editor_suggestion="$VISUAL"
      _config_git['editor']=$(ask_with_default 'What is your main editor?' "$git_editor_suggestion")

      cmd_manager "$flag" "$config_cmd core.editor \"${_config_git['editor']}\""
    fi
  fi

  if [[ -z "${_config_git['branch']}" ]]; then
    # This is a minor configuration, so default is "no"
    if [[ $(ask_yN $'\nWould you like to configure your initial default branch on Git?' 'n') == '1' ]]; then
      _config_git['branch']=$(ask_with_default 'What is your default branch name?' 'main')
      cmd_manager "$flag" "$config_cmd init.defaultBranch \"${_config_git['branch']}\""
    fi
  fi
}

# This function configures KW in an interactive way
# by explaining the core configurations required and
# asking for user input for some configuration decisions.
# This option is intended for new users.
#
# Exit code:
# ENODATA     : Interaction text could not be loaded.
# ECANCELED   : User interruption.
# EINPROGRESS : User selected not implemented feature
function guided_init()
{
  local -A git_configurations

  load_module_text "$KW_LIB_DIR/strings/init.txt"

  if [[ "$?" -ne 0 ]]; then
    complain '[ERROR]:src/init.sh:interactive_init: Failed to load module text.'
    exit 61 # ENODATA
  fi

  say "${module_text_dictionary['text_interactive_start']}"
  if [[ $(ask_yN '>>> Do you want to continue?' 'y') -ne 1 ]]; then
    exit 125 # ECANCELED
  fi

  # Help to setup git
  get_git_config _config_git
  interactive_set_user_git_info git_configurations

  #TODO: Help to setup kworkflow.config;

  #TODO: Check for required;
}
