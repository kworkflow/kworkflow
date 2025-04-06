include "${KW_LIB_DIR}/lib/kwlib.sh"
include "${KW_LIB_DIR}/lib/kwio.sh"
include "${KW_LIB_DIR}/help.sh"
source "$(dirname "$0")/lib/git_helper.sh"
declare -gA options_values

function self_update_main() {
  local target_branch='master'
  local path_to_tmp_dir
  local ret
  local flag

  flag=${flag:-'SILENT'}

  parse_self_update_options "$@"
  if [[ "$?" != 0 ]]; then
    complain "Invalid option: ${options_values['ERROR']}"
    self_update_help
    return 22 # EINVAL
  fi

  [[ -n "${options_values['VERBOSE']}" ]] && flag='VERBOSE'

  if [[ -n "${options_values['UNSTABLE']}" ]]; then
    target_branch='unstable'
  fi

  printf '%s\n' "Updating kw based on the branch ${target_branch}"
  if [[ $(ask_yN 'Do you want to continue?') =~ '0' ]]; then
    complain 'Update aborted.'
    return 125 # ECANCELED
  fi

  path_to_tmp_dir=$(mktemp --directory)
  update_from_official_repo "${target_branch}" "${path_to_tmp_dir}" "$flag"

  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain "Update from branch ${target_branch} failed"
    return "$ret"
  fi

  success "Update based on the branch ${target_branch} successful!"
}

# Updates kw using the official kw repository.
#
# @target_branch Branch used to update
# @path_to_tmp_dir Path to temp dir used for cloning repo
# @flag Variable for testing
#
# Return:
# In case of success return 0, otherwise, return the error
# code.
function update_from_official_repo() {
  local target_branch="$1"
  local path_to_tmp_dir="$2"
  local flag="$3"
  local original_pwd="$PWD"
  local cmd
  local ret

  flag=${flag:-'SILENT'}

  # Just to be sure temp dir is not root dir
  if [ "${path_to_tmp_dir}" == '/' ]; then
    complain "Aborting update! Invalid path to temporary directory: '${path_to_tmp_dir}'"
    return 1 # EPERM
  fi

  cmd="git -C ${path_to_tmp_dir} clone --quiet 'https://github.com/kworkflow/kworkflow.git'"
  cmd_manager "$flag" "$cmd"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain 'Could not clone kworkflow repository'
    return "$ret"
  fi

  cmd="git -C ${path_to_tmp_dir}/kworkflow checkout --quiet ${target_branch}"
  cmd_manager "$flag" "$cmd"
  if [[ "$?" != 0 ]]; then
    complain "Could not checkout to branch ${target_branch}"
    return 95 # EOPNOTSUPP
  fi

  cmd="git -C ${path_to_tmp_dir}/kworkflow pull --quiet 'origin' ${target_branch}"
  cmd_manager "$flag" "$cmd"
  if [[ "$?" != 0 ]]; then
    complain "Could not pull from branch ${target_branch}"
    return 95 # EOPNOTSUPP
  fi

  cmd="cd ${path_to_tmp_dir}/kworkflow"
  cmd_manager "$flag" "$cmd"
  if [[ "$?" != 0 ]]; then
    complain 'Could not change to kworkflow directory'
    return 2 # ENOENT
  fi

  cmd='bash setup.sh --install'
  cmd_manager "$flag" "$cmd"
  ret="$?"
  if [[ "$ret" != 0 ]]; then
    complain 'Could not update kw'
    cd "${original_dir}" || complain 'Could not change back to original directory'
    return "$ret"
  fi

  cmd="cd ${original_dir}"
  cmd_manager "$flag" "$cmd"
  if [[ "$?" != 0 ]]; then
    complain 'Could not change back to original directory'
    return 2 # ENOENT
  fi

  cmd="rm -rf ${path_to_tmp_dir}"
  cmd_manager "$flag" "$cmd"
  if [[ "$?" != 0 ]]; then
    complain 'Could not remove temporary directory'
    return 1 # EPERM
  fi

  return 0
}

function parse_self_update_options() {
  local long_options='unstable,help,verbose'
  local short_options='u,h'

  options="$(kw_parse "$short_options" "$long_options" "$@")"

  if [[ "$?" != 0 ]]; then
    options_values['ERROR']="$(kw_parse_get_errors 'kw update' "$short_options" \
      "$long_options" "$@")"
    return 22 # EINVAL
  fi

  # Default values
  options_values['VERBOSE']=''

  eval "set -- $options"

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --unstable | -u)
        options_values['UNSTABLE']=1
        shift
        ;;
      --help | -h)
        self_update_help "$1"
        exit
        ;;
      --verbose)
        options_values['VERBOSE']=1
        shift
        ;;
      --)
        shift
        ;;
      *)
        shift
        ;;
    esac
  done
}

function self_update_help() {
  if [[ "$1" == --help ]]; then
    include "${KW_LIB_DIR}/help.sh"
    kworkflow_man 'self-update'
    return
  fi
  printf '%s\n' 'kw self-update:' \
    '  kw self-update - Update kw based on the master branch' \
    '  kw self-update (-u | --unstable) - Update kw based on the unstable branch' \
    '  kw self-update --help - Show the man page for kw self-update'
}
