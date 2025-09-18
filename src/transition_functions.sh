# As the kw user base grows, we need to maintain temporary functions that will
# handle some specific transition from the old code to the new one. Usually,
# those functions are temporary, and at some point, they can be removed. This
# file consolidates functions to make sharing code easier and to clean up code
# when we decide to eliminate some of these transaction functions.

include "${KW_LIB_DIR}/lib/kwlib.sh"

function migrate_old_envs_to_base64()
{
  local flag="$1"
  local called_outside_env="$2"
  local local_kw_configs="${PWD}/.kw"
  local cache_build_path="${KW_CACHE_DIR}"
  local encoded_pwd=$(get_encoded_pwd)
  local old_path
  local new_path
  local cmd
  declare -a all_envs

  flag=${flag:-'SILENT'}

  [[ -n "$called_outside_env" ]] && flag='SILENT'

  # We don't need to migrate if:
  # - .kw/envs folder does not exist
  # - ${cache_build_path}/${ENV_DIR} does not exist
  # - migration has already been done
  # - we have no env to migrate
  if [[ ! -d "${local_kw_configs}/${ENV_DIR}" ||
    ! -d "${cache_build_path}/${ENV_DIR}" ||
    -d "${cache_build_path}/${ENV_DIR}/${encoded_pwd}" ]]; then
    return 0
  fi

  readarray -t all_envs < <(find "${local_kw_configs}/${ENV_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%P\n' | sort --dictionary-order)
  if [[ "${#all_envs[@]}" -eq 0 ]]; then
    return 0
  fi

  # Create the new env cache build path for the current tree and migrate the envs
  cmd="mkdir --parents ${cache_build_path}/${ENV_DIR}/${encoded_pwd}"
  cmd_manager "$flag" "$cmd"

  for env_name in "${all_envs[@]}"; do
    old_path="${cache_build_path}/${ENV_DIR}/${env_name}"
    new_path="${cache_build_path}/${ENV_DIR}/${encoded_pwd}/${env_name}"
    cmd="mv ${old_path} ${new_path}"
    cmd_manager "$flag" "$cmd"
  done

  if [[ -z "$called_outside_env" ]]; then
    warning 'It looks like you are already using envs, and recently, kw changed the folder organization for that.'
    warning 'As a result, kw just migrated the old directory scheme to the new one.'
    warning 'This change means that your first build after migration can compile more'
    warning "things than expected. Don't worry, this is a one-time thing."
  fi
}
