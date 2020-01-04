# The init.sh keep all the operations related to the `kworkflow.config`
# initialization. The initialization feature it is inspired on `git init`.

. $src_script_path/kwio.sh --source-only

# This function is responsible for creating a local kworkflow.config based in a
# template available in the etc directory.
#
# Returns:
# In case of failure, this function return ENOENT.
function init_kw()
{
  local config_file_template="$etc_files_path/kworkflow_template.config"
  local kw_path="$HOME/.config/$EASY_KERNEL_WORKFLOW/"
  local name="kworkflow.config"

  if [[ -f "$config_file_template" && -d "$kw_path" ]]; then
    cp "$config_file_template" "$PWD/$name"
    sed -i -e "s/USERKW/$USER/g" -e "s,INSTALLPATH,$kw_path,g" -e "/^#?.*/d" \
              "$PWD/$name"
  else
    complain "No such: $config_file_template or $kw_path"
    exit 2 # ENOENT
  fi

  say "Initialized kworkflow config in $PWD based on $USER data"
}
