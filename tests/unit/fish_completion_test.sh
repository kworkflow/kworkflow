#!/bin/bash

. ./tests/unit/utils.sh --source-only

function suite()
{
  suite_addTest "testKwCompletion"
}

function getSortedCompletions()
{
  local env_path=".:/bin"
  local env_fish_complete_path=""
  local completion="./src/kw.fish"
  local cmd=$1
  local fish_cmd="set PATH $env_path;
                    set fish_complete_path $env_fish_complete_path;
                    source $completion;
                    complete -C'$1 '"

  fish -c "$fish_cmd" | awk '{print $1}' | sort
}

function testKwCompletion()
{
  local kw_options="init build b deploy d bd diff df ssh s self-update u
                      maintainers m kernel-config-manager k config g remote
                      explore e pomodoro p report r device backup debug
                      send-patch env patch-hub drm vm clear-cache codestyle
                      c version v man help h"
  local sorted_kw_options="$(echo $kw_options | awk '{gsub(" ", "\n"); print $0}' | sort)"
  local sorted_kw_fish_completions="$(getSortedCompletions 'kw')"

  if [[ "$sorted_kw_fish_completions" != "$sorted_kw_options" ]]; then
    local difference="$(diff <(echo "$sorted_kw_options") <(echo "$sorted_kw_fish_completions"))"
    fail "Fish suggestions and kw commands are not the same:\n$difference"
  fi

}

invoke_shunit
