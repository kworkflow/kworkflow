# The git.sh file provides git easy functionalities for kworkflow code.

# Run git bisect
#
# @good: good commit hash
# @bad: bad commit hash
# @command: test performed by git bisect
function run_git_bisect()
{
  local good="$1"
  local bad="$2"
  local command="$3"

  git bisect start
  if [[ $? != 0 ]]; then
    printf '%s\n' 'git bisect start failed'
    exit 22 # EINVAL
  fi
  git bisect good "$good"
  if [[ $? != 0 ]]; then
    printf '%s\n' 'git bisect good failed'
    exit 22 # EINVAL
  fi
  git bisect bad "$bad"
  if [[ $? != 0 ]]; then
    printf '%s\n' 'git bisect bad failed'
    exit 22 # EINVAL
  fi
  git bisect run "$command"
  if [[ $? != 0 ]]; then
    printf '%s\n' 'command run failed'
    exit 22 # EINVAL
  fi
  return 0
}

# Checks if the command is being run inside a git work-tree
#
# @flag: How to display (or not) the command used
#
# Returns:
# 0 if is inside a git work-tree root and 128 otherwise.
function is_inside_work_tree()
{
  local flag="$1"
  local cmd='git rev-parse --is-inside-work-tree &> /dev/null'

  flag=${flag:-'SILENT'}

  cmd_manager "$flag" "$cmd"
}
