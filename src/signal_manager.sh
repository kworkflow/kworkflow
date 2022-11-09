include "$KW_LIB_DIR/kwio.sh"

function get_valid_signals()
{
  local -r signal_list="$(trap -l | grep -oE 'SIG\S+')"
  declare -gA SIGNAL_MANAGER_VALID_SIGNALS

  for s in $signal_list; do
    SIGNAL_MANAGER_VALID_SIGNALS["$s"]='1'
  done
}

get_valid_signals

# This functions prints the default message when interrupting kw
function default_interrupt_handler()
{
  say $'\nOh no! An interruption! See ya...'
}

# This function adds a new signal handler to an arbitrary signal
#
# @command The handler to be called when a signal is catched. This
#          must be a single command
# @signals The list of signals to attach to this handler
#
# If command is empty, use the default handler
# If the signal is empty, use the default signals

function signal_manager()
{
  local command="$1"
  shift
  local -a signals=("$@")

  if [[ -z "$command" ]]; then
    command='default_interrupt_handler'
  elif ! type "$command" > /dev/null 2>&1; then
    return 22 # EINVAL
  fi

  if [[ "${#signals}" == 0 ]]; then
    signals=(SIGINT SIGTERM)
  else
    for s in "${signals[@]}"; do
      if [[ ! -v SIGNAL_MANAGER_VALID_SIGNALS["$s"] &&
        ! -v SIGNAL_MANAGER_VALID_SIGNALS[SIG"$s"] ]]; then
        return 22 # EINVAL
      fi
    done
  fi

  # shellcheck disable=2064
  trap "$command" "${signals[@]}" 2> /dev/null
}

# This function resets all signal handlers to their system defaults and
# sets kw's default signal handler for SIGINT and SIGTERM
function signal_manager_reset()
{
  local traps

  traps=$(trap -p | grep -o '[^ ]*$')

  while read -r sig; do
    trap - "$sig"
  done <<< "$traps"

  signal_manager ''
}
