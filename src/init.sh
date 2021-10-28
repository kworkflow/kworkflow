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
    complain 'This command should be run in a kernel tree.'
    exit 125 # ECANCELED
  fi

  parse_init_options "$@"
  if [[ "$?" -gt 0 ]]; then
    complain "${options_values['ERROR']}"
    return 22 # EINVAL
  fi

  if [[ "${options_values['INTERACTIVE']}" ]]; then

    local cmd=''
    local distro=''
    local has_ssh
    local installed

    distro=$(detect_distro '/')

    case "$distro" in
      none)
        warning "We do not support your distro (yet). We cannot check if SSH is installed."
        if [[ $(ask_yN "Do you wish to proceed without configuring SSH?" =~ '0') ]]; then
          exit 0
        fi
        ;;
      arch)
        pacman -Qe openssh > /dev/null
        if [[ "$?" != 0 ]]; then
          #not found
          cmd='pacman -S openssh'
        fi
        ;;
      debian)
        installed=$(dpkg-query -W --showformat='${Status}\n' openssh-client 2> /dev/null | grep -c 'ok installed')
        if [[ "$installed" -eq 0 ]]; then
          #not found
          cmd='apt install openssh-client'
        fi
        ;;
    esac

    if [[ -n "$cmd" ]]; then
      if [[ $(ask_yN 'SSH was not found in this system, would you like to install it?') =~ '1' ]]; then
        eval "sudo $cmd"
      fi
    fi

    if [[ $(ask_yN 'Would you like to create a new SSH key for kw?') -eq 1 ]]; then
      warning 'Creating new SSH key...We strongly recommend you do not overwrite any of your keys:'
      eval "ssh-keygen -t rsa"
    fi

    if [[ $(ask_yN 'Would you like to configurate a SSH connection to a remote machine?') -eq 1 ]]; then
      local arg
      say 'Please input your remote user, ip and port.'
      warning 'Follow this format: <user>@<ip>:<port>'
      read -r arg
      options_values['REMOTE']="$arg"
    fi
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
    '  init --target <target> Set the default_deploy_target field in the kworkflow.config file'
}
