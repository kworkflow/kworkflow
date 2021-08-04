# The init.sh keep all the operations related to the `kworkflow.config`
# initialization. The initialization feature it is inspired on `git init`.

include "$KW_LIB_DIR/kwio.sh"
include "$KW_LIB_DIR/kwlib.sh"

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
  local name="kworkflow.config"

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
    sed -i -e "s/USERKW/$USER/g" -e "s,SOUNDPATH,$KW_SOUND_DIR,g" -e "/^#?.*/d" \
      "$PWD/$KW_DIR/$name"

    if [[ -n "${options_values['ARCH']}" ]]; then
      if [[ -d "$PWD/arch/${options_values['ARCH']}" || -n "${options_values['FORCE']}" ]]; then
        set_config_value 'arch' "${options_values['ARCH']}"
      elif [[ -z "${options_values['FORCE']}" ]]; then
        complain 'This arch was not found in the arch directory'
        complain 'You can use --force next time if you want to proceed anyway'
        say 'Available architectures:'
        find "$PWD/arch" -maxdepth 1 -mindepth 1 -type d -printf '%f\n'
      fi
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
  local long_options='arch:,force'
  local short_options='a:,f'

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
      --force | -f)
        shift
        options_values['FORCE']=1
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
    '  init --arch <arch> - Set the arch field in the kworkflow.config file.'
}
