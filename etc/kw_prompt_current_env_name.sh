kw_get_current_env_name()
{
  kw_env_file="${PWD}/.kw/env.current"
  if [[ -f "$kw_env_file" ]]; then
    printf '[%s]' "$(< "$kw_env_file")"
  fi
}
