# The init.sh keep all the operations related to the `kworkflow.config`
# initialization. The initialization feature it is inspired on `git init`.

. "$KW_LIB_DIR/kwio.sh" --source-only

# This function is responsible for creating a local kworkflow.config based in a
# template available in the etc directory.
#
# Returns:
# In case of failure, this function return ENOENT.
function init_kw()
{
  local config_file_template="$KW_ETC_DIR/kworkflow_template.config"
  local name="kworkflow.config"

  if [[ -f "$config_file_template" ]]; then
    cp "$config_file_template" "$PWD/$name"
    sed -i -e "s/USERKW/$USER/g" -e "s,SOUNDPATH,$KW_SHARE_SOUND_DIR,g" -e "/^#?.*/d" \
              "$PWD/$name"
  else
    complain "No such: $config_file_template or $kw_path"
    exit 2 # ENOENT
  fi

  say "Initialized kworkflow config in $PWD based on $USER data"
}
