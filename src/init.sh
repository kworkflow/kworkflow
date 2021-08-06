# The init.sh keep all the operations related to the `kworkflow.config`
# initialization. The initialization feature it is inspired on `git init`.

include "$KW_LIB_DIR/kwio.sh"

KW_DIR='.kw'

# This function is responsible for creating a local kworkflow.config based in a
# template available in the etc directory.
#
# Returns:
# In case of failure, this function return ENOENT.
function init_kw()
{
  local config_file_template="$KW_ETC_DIR/kworkflow_template.config"
  local name="kworkflow.config"

  if [[ "$1" =~ -h|--help ]]; then
    init_help "$1"
    exit 0
  fi

  if [[ -f "$PWD/$KW_DIR/$name" ]]; then
    if [[ "$*" =~ --?f(orce)? || $(ask_yN "$name already exists, do you wish to overwrite it?") =~ '1' ]]; then
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
  else
    complain "No such: $config_file_template"
    exit 2 # ENOENT
  fi

  say "Initialized kworkflow directory in $PWD/$KW_DIR based on $USER data"
}

function init_help()
{
  if [[ "$1" == --help ]]; then
    include "$KW_LIB_DIR/help.sh"
    kworkflow_man 'init'
    return
  fi
  printf '%s\n' 'kw init:' \
    '  init - Creates a kworkflow.config file in the current directory.'
}
