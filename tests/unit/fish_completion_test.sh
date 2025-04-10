#!/usr/bin/env bash

include './tests/unit/utils.sh'

function get_sorted_completions()
{
  local env_path
  local env_fish_complete_path
  local completion
  local cmd
  local fish_cmd

  env_path='.:/bin'
  env_fish_complete_path=''
  completion='./src/kw.fish'
  cmd="$1"
  fish_cmd="set PATH ${env_path};
                  set fish_complete_path ${env_fish_complete_path};
                  source ${completion};
                  complete -C'${1} '"

  fish -c "$fish_cmd" | awk '{print $1}' | sort --dictionary-order
}

function test_kw_completion_for_fish()
{
  local kw_options
  local sorted_kw_options
  local sorted_kw_fish_completions

  kw_options='init build b deploy d bd diff df ssh s self-update u maintainers m kernel-config-manager k config g remote explore e pomodoro p report r device backup debug send-patch env patch-hub drm vm kernel-tag clear-cache codestyle c version v man help h'
  sorted_kw_options="$(printf '%s' "${kw_options}" | awk '{gsub(" ", "\n"); print $0}' | sort --dictionary-order)"
  sorted_kw_fish_completions="$(get_sorted_completions 'kw')"

  assert_equals_helper 'Autocomplete is different for fish' \
    "$LINENO" "${sorted_kw_fish_completions}" \
    "${sorted_kw_options}"
}

invoke_shunit
