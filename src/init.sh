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

  if [[ "${options_values['INTERACTIVE']}" ]]; then
    interactive_init

    #TODO: Help to setup git;

    #TODO: Help to setup kworkflow.config;

    #TODO: Check for required;

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
  local long_options='arch:,remote:,target:,force,interactive'
  local short_options='a:,r:,t:,f,i'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw init' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  options_values['ARCH']=''
  options_values['FORCE']=''
  options_values['INTERACTIVE']=''

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
      --interactive | -i)
        options_values['INTERACTIVE']=1
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
    '  init --interactive - Perform first time setup in an interactive manner. Recommended for new users.'
}

# This function creates a new ssh key.
#
# @ssh_dir  : directory where the key will be stored.
# @key_name : this is the name of the key, usually
#             used to avoid overwriting keys.
#             If not given, defaults to "kw_ssh_key".
#
# Returns:
# ENOTDIR                   : a file named @ssh_dir already exists and
#                             is not a directory.
# EEXISTS                   : key already exists.
# ssh-keygen's return value : returns ssh-keygen's value if @ssh_dir is valid.
function create_ssh_key()
{
  local ssh_dir="$1"
  local key_name="${2:-kw_ssh_key}"
  local path="$ssh_dir/$key_name"

  if [[ -e "$ssh_dir" && ! -d "$ssh_dir" ]]; then
    return 20 # ENOTDIR
  fi

  if [[ -e "$path" ]]; then
    return 17 # EEXISTS
  fi

  mkdir -p "$ssh_dir"
  ssh-keygen -q -t rsa -f "$path"
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
function interactive_init()
{
  local ssh_keys
  local key_name ssh_dir
  local ssh_user ssh_ip

  load_module_text "$KW_LIB_DIR/strings/init.txt"

  if [[ "$?" -ne 0 ]]; then
    complain '[ERROR]:src/init.sh:interactive_init: Failed to load module text.'
    exit 61 # ENODATA
  fi

  say "${module_text_dictionary['text_interactive_start']}"
  if [[ $(ask_yN '>>> Do you want to continue?') -ne 1 ]]; then
    exit 125 # ECANCELED
  fi

  say "${module_text_dictionary['text_ssh_start']}"
  if [[ $(ask_yN '>>> Do you want to continue?') -ne 1 ]]; then
    exit 125 # ECANCELED
  fi

  say "${module_text_dictionary['text_ssh_lookup']}"

  ssh_keys=$(find "$HOME/.ssh" -type f -name "*.pub")

  if [[ -n "$ssh_keys" ]]; then
    say "${module_text_dictionary['text_ssh_keys']}"
  fi

  #TODO: Fix cases and make code more efficient
  select item in 'Create new LOCAL RSA key for KW' 'Create new GLOBAL RSA key for KW' $ssh_keys; do
    if [[ -n "$item" ]]; then
      case "$REPLY" in
        1 | 2)
          #Local or Global
          say 'Creating new SSH key...'
          warning 'If you type in the name of a key that already exists,'
          warning 'you will be prompted to confirm that you wish to overwrite the key.'
          warning 'Proceed with caution. We do not recommend you overwrite your key.'
          say 'Please, type in the name of your new key:'
          read -r -p 'Key: ' key_name
          warning 'SSH will ask you for a password.'
          warning 'Make sure you remember it for later use.'
          ;;&
        1) ssh_dir="$PWD/$KW_DIR/ssh" ;;
        2) ssh_dir="$HOME/.ssh" ;;
        *)
          complain '[ERROR]:src/init:interactive_init: Feature not implemented (yet)'
          exit 115 # EINPROGRESS
          #TODO: Add the path to the chosen key to KW config (Different issue).
          #Picked key
          ;;
      esac

      create_ssh_key "$ssh_dir" "$key_name"

      if [[ "$?" =~ "0" ]]; then
        success "Created new key at $ssh_dir/$key_name.pub"
      else
        complain 'Failed to create new key.'
      fi
      #TODO: Test this

      break
    fi
  done

  if [[ $(ask_yN 'Would you like to configure a SSH connection to a remote machine?') -eq 1 ]]; then
    say "${module_text_dictionary['text_remote_start']}"
    read -r -p 'USER      (root): ' ssh_user
    read -r -p 'IP   (localhost): ' ssh_ip
    options_values['REMOTE']="${ssh_user:-root}@${ssh_ip:-127.0.0.1}:22"
  fi
  #TODO: Help to setup git;

  #TODO: Help to setup kworkflow.config;

  #TODO: Check for required;
}
