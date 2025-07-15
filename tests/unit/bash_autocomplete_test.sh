#!/usr/bin/env bash

include './tests/unit/utils.sh'

# Get and sort Bash autocomplete options
function get_sorted_bash_completions()
{
  local cmd="$1"

  include './src/bash_autocomplete.sh'

  # Populate the array of words from the command string (simulates Bash
  # parsing)
  #
  COMP_WORDS=("$cmd")
  # Specify the index of the word to complete ('kw' is index 0 and next word is
  # 1)
  COMP_CWORD=1
  # An array variable from which Bash reads the possible completions generated
  # by a shell function invoked by the programmable completion facility
  COMPREPLY=()

  _kw_autocomplete

  printf '%s\n' "${COMPREPLY[@]}" | sort --dictionary-order
}

# Validate KW command autocomplete in Bash
function test_kw_completion_for_bash()
{
  local kw_options='init build deploy bd diff ssh self-update maintainers kernel-config-manager config remote explore pomodoro report device backup debug send-patch env patch-hub drm vm clear-cache codestyle version man help'

  local sorted_expected="$(printf "%s\n" ${kw_options} | sort --dictionary-order)"
  local sorted_actual="$(get_sorted_bash_completions 'kw')"

  assert_equals_helper 'Autocomplete is different for bash' \
    "$LINENO" "$sorted_actual" "$sorted_expected"
}

# Exit immediately if Bash is not installed
command -v bash &> /dev/null || exit 0

invoke_shunit
