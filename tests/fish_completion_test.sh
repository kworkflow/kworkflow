#!/bin/bash

. ./tests/utils --source-only

function suite()
{
    suite_addTest "testKwCompletion"
}

function testKwCompletion()
{
    local kw_options="explore e build b bi install i prepare p new n ssh s
                      mount mo umount um vars v up u codestyle c
                      maintainers m help h"

    local sorted_kw_options="$(echo $kw_options | awk '{gsub(" ", "\n"); print $0}' | sort)"
    local sorted_kw_fish_completions="$(fish ./tests/_fish_completion.fish | sort)"

    if [[ "$sorted_kw_fish_completions" != "$sorted_kw_options" ]]; then
	local difference="$(diff <(echo "$sorted_kw_options") <(echo "$sorted_kw_fish_completions"))"
	fail "Fish suggestions and kw commands are not the same:\n$difference"
    fi;

}

invoke_shunit
